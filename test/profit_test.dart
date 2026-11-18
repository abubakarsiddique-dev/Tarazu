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
  double costPerKg = 0,
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
      costPerKg: costPerKg,
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

  // ---- opening stock tests ----

  test('opening stock followed by sale gives correct profit (no free profit)', () {
    // No purchase. Opening stock: 10 kg @ Rs 40/kg.
    // Sell 5 kg for Rs 250. Cost = 5 * 40 = Rs 200. Profit = 50.
    final r = computeProfit([
      LedgerEvent(
        kind: LedgerKind.adjustment,
        at: DateTime(2026, 11, 1),
        dayKey: '2026-11-01',
        materialId: 'iron',
        materialName: 'Iron',
        grams: 10000,
        reason: AdjustmentReason.openingStock,
        costPerKg: 40,
      ),
      _e(LedgerKind.sale, 2, '2026-11-01', 'iron', 5000, 250),
    ], from: '2026-11-01', to: '2026-11-01');

    final iron = r.materials.single;
    expect(iron.soldGrams, 5000);
    expect(iron.salesAmount, 250);
    expect(iron.cost, 200); // 5 kg × Rs 40
    expect(iron.profit, 50);
    expect(iron.noCostGrams, 0); // no "no cost" warning
    expect(r.grossProfit, 50);
  });

  test('opening stock does not create free profit when sold at cost', () {
    // Opening stock 10 kg @ Rs 50/kg. Sell all 10 kg for Rs 500.
    // Profit should be 0, not 500 (which would happen if cost = 0).
    final r = computeProfit([
      LedgerEvent(
        kind: LedgerKind.adjustment,
        at: DateTime(2026, 11, 1),
        dayKey: '2026-11-01',
        materialId: 'copper',
        materialName: 'Copper',
        grams: 10000,
        reason: AdjustmentReason.openingStock,
        costPerKg: 50,
      ),
      _e(LedgerKind.sale, 2, '2026-11-01', 'copper', 10000, 500),
    ], from: '2026-11-01', to: '2026-11-01');

    final copper = r.materials.single;
    expect(copper.cost, 500);
    expect(copper.profit, 0);
    expect(copper.noCostGrams, 0);
  });

  test('purchase totals unchanged by opening stock — opening stock does not add to salesAmount or acc.cost as a purchase', () {
    // Opening stock 5 kg @ 30/kg, then purchase 10 kg for Rs 400,
    // then sell 15 kg for Rs 750.
    // salesAmount (revenue) = 750; cost = 5*30 + 10*40 = 150 + 400 = 550 (blended avg).
    // Note: avg after opening stock = 30/kg, after purchase 10kg @ 40 = (150+400)/15000 = 36.67/kg
    // Sell 15 kg: cost = 15 * 36.67 = 550. Profit = 750 - 550 = 200.
    final r = computeProfit([
      LedgerEvent(
        kind: LedgerKind.adjustment,
        at: DateTime(2026, 11, 1, 0, 1),
        dayKey: '2026-11-01',
        materialId: 'iron',
        materialName: 'Iron',
        grams: 5000,
        reason: AdjustmentReason.openingStock,
        costPerKg: 30,
      ),
      LedgerEvent(
        kind: LedgerKind.purchase,
        at: DateTime(2026, 11, 1, 0, 2),
        dayKey: '2026-11-01',
        materialId: 'iron',
        materialName: 'Iron',
        grams: 10000,
        amount: 400,
      ),
      _e(LedgerKind.sale, 3, '2026-11-01', 'iron', 15000, 750),
    ], from: '2026-11-01', to: '2026-11-01');

    final iron = r.materials.single;
    expect(iron.salesAmount, 750); // revenue only from actual sales
    expect(iron.cost, 550); // blended avg cost
    expect(iron.profit, 200);
    expect(iron.noCostGrams, 0);
  });

  test('opening stock sets lastRate so a later no-purchase sale is costed correctly', () {
    // Opening stock 8 kg @ Rs 25/kg. Sell 8 kg for Rs 240.
    // avg = 25; cost = 8 * 25 = 200. profit = 40. noCostGrams = 0.
    final r = computeProfit([
      LedgerEvent(
        kind: LedgerKind.adjustment,
        at: DateTime(2026, 11, 1),
        dayKey: '2026-11-01',
        materialId: 'brass',
        materialName: 'Brass',
        grams: 8000,
        reason: AdjustmentReason.openingStock,
        costPerKg: 25,
      ),
      _e(LedgerKind.sale, 2, '2026-11-01', 'brass', 8000, 240),
    ], from: '2026-11-01', to: '2026-11-01');

    final brass = r.materials.single;
    expect(brass.cost, 200);
    expect(brass.profit, 40);
    expect(brass.noCostGrams, 0);
  });
}
