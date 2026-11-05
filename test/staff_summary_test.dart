import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/features/inventory/domain/models.dart';
import 'package:tarazu/features/inventory/domain/sale_models.dart';
import 'package:tarazu/features/staff/domain/staff_summary.dart';

Purchase _p(String by, int amount, int grams) => Purchase(
      id: 'p$by$amount',
      items: const [],
      totalAmount: amount,
      totalWeightGrams: grams,
      sellerName: '',
      dayKey: '2026-11-05',
      createdAt: DateTime(2026, 11, 5),
      pendingSync: false,
      createdBy: by,
    );

Sale _s(String by, int amount, int grams) => Sale(
      id: 's$by$amount',
      items: const [],
      totalAmount: amount,
      totalWeightGrams: grams,
      buyerName: '',
      dayKey: '2026-11-05',
      createdAt: DateTime(2026, 11, 5),
      pendingSync: false,
      createdBy: by,
    );

void main() {
  final names = {'m1': 'Bilal', 'm2': 'Ahmed'};

  test('groups purchases and sales per munshi, owner last', () {
    final rows = summarizeByStaff(
      purchases: [_p('m1', 100, 1000), _p('m1', 50, 500), _p('m2', 70, 700), _p('owner', 10, 100)],
      sales: [_s('m1', 300, 2000), _s('owner', 40, 400)],
      staffNames: names,
    );

    expect(rows.map((r) => r.name), ['Ahmed', 'Bilal', 'Owner']);

    final bilal = rows[1];
    expect(bilal.boughtSlips, 2);
    expect(bilal.boughtAmount, 150);
    expect(bilal.boughtGrams, 1500);
    expect(bilal.soldSlips, 1);
    expect(bilal.soldAmount, 300);

    final ahmed = rows[0];
    expect(ahmed.boughtAmount, 70);
    expect(ahmed.soldSlips, 0);

    final owner = rows[2];
    expect(owner.isOwner, isTrue);
    expect(owner.boughtAmount, 10);
    expect(owner.soldAmount, 40);
  });

  test('a munshi with no entries still gets an empty row', () {
    final rows = summarizeByStaff(purchases: [], sales: [], staffNames: names);
    expect(rows.length, 3);
    expect(rows.every((r) => r.isEmpty), isTrue);
  });

  test('old entries without createdBy count as owner', () {
    final rows = summarizeByStaff(purchases: [_p('', 25, 250)], sales: [], staffNames: names);
    expect(rows.last.isOwner, isTrue);
    expect(rows.last.boughtAmount, 25);
  });
}
