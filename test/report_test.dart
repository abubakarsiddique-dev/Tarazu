import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/features/inventory/domain/history.dart';
import 'package:tarazu/features/inventory/domain/models.dart';
import 'package:tarazu/features/inventory/domain/report.dart';
import 'package:tarazu/features/inventory/domain/sale_models.dart';

SaleItem _si(String id, String name, int grams, int amount) => SaleItem(
      materialId: id, materialName: name, weightGrams: grams, ratePerKg: 0, amount: amount,
    );

Sale _sale(String day, List<SaleItem> items) => Sale(
      id: day,
      items: items,
      totalAmount: items.fold(0, (s, i) => s + i.amount),
      totalWeightGrams: items.fold(0, (s, i) => s + i.weightGrams),
      buyerName: '',
      dayKey: day,
      createdAt: DateTime(2026, 11, 4),
      pendingSync: false,
    );

PurchaseItem _pi(String id, String name, int grams, int amount) => PurchaseItem(
      materialId: id, materialName: name, weightGrams: grams,
      unit: PriceUnit.kg, rate: 0, amount: amount,
    );

Purchase _purchase(String day, List<PurchaseItem> items) => Purchase(
      id: day,
      items: items,
      totalAmount: items.fold(0, (s, i) => s + i.amount),
      totalWeightGrams: items.fold(0, (s, i) => s + i.weightGrams),
      sellerName: '',
      dayKey: day,
      createdAt: DateTime(2026, 11, 4),
      pendingSync: false,
    );

void main() {
  final sales = [
    _sale('2026-11-03', [_si('iron', 'Iron', 10000, 550)]),
    _sale('2026-11-04', [_si('iron', 'Iron', 5000, 275), _si('pl', 'Plastic', 2000, 100)]),
  ];

  test('summarizeSales totals and per-material sums', () {
    final s = summarizeSales(sales);
    expect(s.totalAmount, 925);
    expect(s.totalGrams, 17000);
    expect(s.saleCount, 2);
    expect(s.materials.first.name, 'Iron');
    expect(s.materials.first.amount, 825);
    expect(s.materials.first.grams, 15000);
  });

  test('empty sales', () {
    final s = summarizeSales(const []);
    expect(s.totalAmount, 0);
    expect(s.materials, isEmpty);
  });

  test('combineMaterials joins bought and sold by material id', () {
    final p = summarizeHistory([
      _purchase('2026-11-03', [_pi('iron', 'Iron', 20000, 800), _pi('cu', 'Copper', 1000, 900)]),
    ]);
    final rows = combineMaterials(p, summarizeSales(sales));
    final byName = {for (final r in rows) r.name: r};

    expect(byName['Iron']!.boughtGrams, 20000);
    expect(byName['Iron']!.soldGrams, 15000);
    expect(byName['Copper']!.soldGrams, 0); // bought, never sold
    expect(byName['Plastic']!.boughtGrams, 0); // sold, never bought
  });

  test('report text has totals, difference and the not-profit note', () {
    final p = summarizeHistory([_purchase('2026-11-03', [_pi('iron', 'Iron', 20000, 800)])]);
    final text = buildReportText(
      shopName: 'Ali Kabari',
      periodLabel: '2026-11-01  to  2026-11-30',
      purchases: p,
      sales: summarizeSales(sales),
    );
    expect(text, contains('Ali Kabari'));
    expect(text, contains('Purchases: Rs 800'));
    expect(text, contains('Sales: Rs 925'));
    expect(text, contains('Sales minus purchases: Rs 125'));
    expect(text, contains('not profit'));
  });

  test('negative difference is shown with a minus sign', () {
    final p = summarizeHistory([_purchase('2026-11-03', [_pi('iron', 'Iron', 20000, 2000)])]);
    final text = buildReportText(
      shopName: '', periodLabel: 'x', purchases: p, sales: summarizeSales(sales),
    );
    expect(text, contains('Sales minus purchases: -Rs 1,075'));
  });
}
