import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/features/finance/domain/profit.dart';
import 'package:tarazu/features/inventory/domain/sale_models.dart' show AdjustmentReason;

LedgerEvent _e(
  LedgerKind kind,
  int minute,
  String day,
  String id,
  int grams, [
  int amount = 0,
  AdjustmentReason? reason,
]) =>
    LedgerEvent(
      kind: kind,
      at: DateTime(2026, 11, 1).add(Duration(minutes: minute)),
      dayKey: day,
      materialId: id,
      materialName: id[0].toUpperCase() + id.substring(1),
      grams: grams,
      amount: amount,
      reason: reason,
    );

void main() {
  // iron: buy 20 kg for 800 (Rs 40/kg), sell 15 kg for 825      -> cost 600, profit 225
  //       buy 10 kg for 500, now 15 kg in stock costing 700
  //       sell 6 kg for 360 (average 46.67/kg)                  -> cost 280, profit 80
  //       lose 1 kg                                              -> loss 46.67
  // copper: sold 2 kg for 100 with no purchase at all            -> cost unknown
  final events = [
    _e(LedgerKind.purchase, 1, '2026-11-01', 'iron', 20000, 800),
    _e(LedgerKind.sale, 2, '2026-11-02', 'iron', 15000, 825),
    _e(LedgerKind.purchase, 3, '2026-11-03', 'iron', 10000, 500),
    _e(LedgerKind.sale, 4, '2026-11-04', 'iron', 6000, 360),
    _e(LedgerKind.adjustment, 5, '2026-11-04', 'iron', -1000),
    _e(LedgerKind.sale, 6, '2026-11-04', 'copper', 2000, 100),
  ];

  test('whole month: totals and per material', () {
    final r = computeProfit(events, from: '2026-11-01', to: '2026-11-30');

    final iron = r.materials.firstWhere((m) => m.materialId == 'iron');
    expect(iron.soldGrams, 21000);
    expect(iron.salesAmount, 1185);
    expect(iron.cost, 880); // 600 + 280
    expect(iron.profit, 305);
    expect(iron.lossCost, 47);

    final copper = r.materials.firstWhere((m) => m.materialId == 'copper');
    expect(copper.cost, 0);
    expect(copper.profit, 100);
    expect(copper.noCostGrams, 2000);

    expect(r.salesAmount, 1285);
    expect(r.cost, 880);
    expect(r.grossProfit, 405);
    expect(r.lossCost, 47);
    expect(r.netProfit(100), 405 - 47 - 100);
    expect(r.noCostGrams, 2000);
  });

  test('a single day only counts that day, but cost still uses earlier purchases', () {
    final r = computeProfit(events, from: '2026-11-04', to: '2026-11-04');
    final iron = r.materials.firstWhere((m) => m.materialId == 'iron');
    expect(iron.soldGrams, 6000);
    expect(iron.salesAmount, 360);
    expect(iron.cost, 280);
    expect(iron.profit, 80);
  });

  test('best profit comes first', () {
    final r = computeProfit(events, from: '2026-11-01', to: '2026-11-30');
    expect(r.materials.first.materialId, 'iron');
  });

  test('stock cost now = what is still in the shop, at cost', () {
    final r = computeProfit(events, from: '2026-11-01', to: '2026-11-30');
    // iron: 15000 - 6000 - 1000 = 8000 g left, 700 - 280 - 46.67 = 373.33
    expect(r.stockCostNow, 373);
  });

  test('selling at a loss shows a negative profit', () {
    final r = computeProfit([
      _e(LedgerKind.purchase, 1, '2026-11-01', 'iron', 10000, 600),
      _e(LedgerKind.sale, 2, '2026-11-01', 'iron', 10000, 500),
    ], from: '2026-11-01', to: '2026-11-01');
    expect(r.grossProfit, -100);
    expect(r.materials.single.marginPercent! < 0, isTrue);
  });

  test('a plus adjustment is added at average cost, so it creates no free profit', () {
    final r = computeProfit([
      _e(LedgerKind.purchase, 1, '2026-11-01', 'iron', 10000, 400),
      _e(LedgerKind.adjustment, 2, '2026-11-01', 'iron', 2000),
      _e(LedgerKind.sale, 3, '2026-11-01', 'iron', 12000, 600),
    ], from: '2026-11-01', to: '2026-11-01');
    expect(r.cost, 480); // 400 paid + 2 kg added at Rs 40/kg
    expect(r.grossProfit, 120);
  });

  test('empty history gives an empty report', () {
    final r = computeProfit(const [], from: '2026-11-01', to: '2026-11-30');
    expect(r.materials, isEmpty);
    expect(r.netProfit(0), 0);
    expect(r.stockCostNow, 0);
  });

  test('garbage removal counts as stock loss at current average cost and tracks garbage weight and cost', () {
    final r = computeProfit([
      _e(LedgerKind.purchase, 1, '2026-11-01', 'iron', 20000, 800), // Rs 40/kg
      _e(LedgerKind.adjustment, 2, '2026-11-01', 'iron', -2000, 0, AdjustmentReason.garbage), // 2 kg garbage -> Rs 80 loss
      _e(LedgerKind.sale, 3, '2026-11-01', 'iron', 10000, 500), // 10 kg sold -> cost 400, sales 500
    ], from: '2026-11-01', to: '2026-11-01');

    final iron = r.materials.single;
    expect(iron.soldGrams, 10000);
    expect(iron.salesAmount, 500);
    expect(iron.cost, 400);
    expect(iron.profit, 100);
    expect(iron.lossCost, 80);
    expect(iron.garbageGrams, 2000);
    expect(iron.garbageCost, 80);

    expect(r.salesAmount, 500);
    expect(r.cost, 400);
    expect(r.grossProfit, 100);
    expect(r.lossCost, 80);
    expect(r.garbageGrams, 2000);
    expect(r.garbageCost, 80);
    expect(r.netProfit(0), 20); // 100 - 80
    expect(r.stockCostNow, 320); // 8 kg left @ Rs 40/kg
  });

  test('garbage removal with no sales still appears in report as loss', () {
    final r = computeProfit([
      _e(LedgerKind.purchase, 1, '2026-11-01', 'brass', 10000, 1000), // Rs 100/kg
      _e(LedgerKind.adjustment, 2, '2026-11-01', 'brass', -1000, 0, AdjustmentReason.garbage), // 1 kg garbage -> Rs 100 loss
    ], from: '2026-11-01', to: '2026-11-01');

    expect(r.materials.length, 1);
    final brass = r.materials.single;
    expect(brass.soldGrams, 0);
    expect(brass.salesAmount, 0);
    expect(brass.cost, 0);
    expect(brass.profit, 0);
    expect(brass.lossCost, 100);
    expect(brass.garbageGrams, 1000);
    expect(brass.garbageCost, 100);

    expect(r.grossProfit, 0);
    expect(r.lossCost, 100);
    expect(r.netProfit(0), -100);
    expect(r.stockCostNow, 900);
  });

  test('garbage removal outside period affects stock cost but is excluded from period garbage and loss', () {
    final r = computeProfit([
      _e(LedgerKind.purchase, 1, '2026-11-01', 'iron', 10000, 400),
      _e(LedgerKind.adjustment, 2, '2026-11-02', 'iron', -2000, 0, AdjustmentReason.garbage),
      _e(LedgerKind.sale, 3, '2026-11-03', 'iron', 5000, 300),
    ], from: '2026-11-03', to: '2026-11-03');

    final iron = r.materials.single;
    expect(iron.soldGrams, 5000);
    expect(iron.salesAmount, 300);
    expect(iron.cost, 200);
    expect(iron.profit, 100);
    expect(iron.lossCost, 0);
    expect(iron.garbageGrams, 0);
    expect(iron.garbageCost, 0);

    expect(r.lossCost, 0);
    expect(r.garbageGrams, 0);
    expect(r.garbageCost, 0);
    expect(r.stockCostNow, 120); // 3 kg left @ Rs 40/kg
  });
}
