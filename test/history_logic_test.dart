import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/features/inventory/domain/history.dart';
import 'package:tarazu/features/inventory/domain/models.dart';

PurchaseItem _item(String id, String name, int grams, int amount) => PurchaseItem(
      materialId: id,
      materialName: name,
      weightGrams: grams,
      unit: PriceUnit.kg,
      rate: 0,
      amount: amount,
    );

Purchase _slip(String day, int hour, List<PurchaseItem> items) => Purchase(
      id: '$day-$hour',
      items: items,
      totalAmount: items.fold(0, (s, i) => s + i.amount),
      totalWeightGrams: items.fold(0, (s, i) => s + i.weightGrams),
      sellerName: '',
      dayKey: day,
      createdAt: DateTime(2026, 11, int.parse(day.substring(8)), hour),
      pendingSync: false,
    );

void main() {
  group('periods', () {
    test('week starts on Monday and ends on Sunday', () {
      // Wed 4 Nov 2026
      final start = periodStart(HistoryPeriod.week, DateTime(2026, 11, 4));
      expect(start, DateTime(2026, 11, 2));
      expect(start.weekday, DateTime.monday);
      expect(periodEnd(HistoryPeriod.week, start), DateTime(2026, 11, 8));
      // Sunday belongs to the week that started the Monday before.
      expect(periodStart(HistoryPeriod.week, DateTime(2026, 11, 8)), DateTime(2026, 11, 2));
      // Monday is its own week start.
      expect(periodStart(HistoryPeriod.week, DateTime(2026, 11, 9)), DateTime(2026, 11, 9));
    });

    test('week can start in the previous month', () {
      final start = periodStart(HistoryPeriod.week, DateTime(2026, 12, 2));
      expect(start, DateTime(2026, 11, 30));
      expect(dayKey(start), '2026-11-30');
    });

    test('month start / end', () {
      final start = periodStart(HistoryPeriod.month, DateTime(2026, 2, 17));
      expect(start, DateTime(2026, 2, 1));
      expect(periodEnd(HistoryPeriod.month, start), DateTime(2026, 2, 28));
    });

    test('shift across year boundaries', () {
      expect(shiftPeriod(HistoryPeriod.month, DateTime(2026, 1, 1), -1), DateTime(2025, 12, 1));
      expect(shiftPeriod(HistoryPeriod.month, DateTime(2026, 12, 1), 1), DateTime(2027, 1, 1));
      expect(shiftPeriod(HistoryPeriod.week, DateTime(2026, 11, 2), -1), DateTime(2026, 10, 26));
      expect(shiftPeriod(HistoryPeriod.day, DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });
  });

  group('summarizeHistory', () {
    final slips = [
      _slip('2026-11-03', 10, [_item('iron', 'Iron', 10000, 400), _item('pl', 'Plastic', 5000, 150)]),
      _slip('2026-11-03', 15, [_item('iron', 'Iron', 2000, 80)]),
      _slip('2026-11-04', 9, [_item('pl', 'Plastic', 3000, 90)]),
    ];

    test('all materials', () {
      final s = summarizeHistory(slips);
      expect(s.totalAmount, 720);
      expect(s.totalGrams, 20000);
      expect(s.slipCount, 3);
      expect(s.days.map((d) => d.dayKey), ['2026-11-04', '2026-11-03']); // newest first
      expect(s.days.last.slips, 2);
      expect(s.days.last.amount, 630);
      expect(s.materials.first.name, 'Iron'); // 480 > 240
      expect(s.materials.first.grams, 12000);
      expect(s.slips.first.dayKey, '2026-11-04'); // newest first
    });

    test('material filter counts only that material', () {
      final s = summarizeHistory(slips, materialId: 'pl');
      expect(s.totalAmount, 240);
      expect(s.totalGrams, 8000);
      expect(s.slipCount, 2); // the Iron-only slip is left out
      expect(s.materials.length, 1);
      expect(s.days.last.amount, 150); // 3 Nov: only the plastic line
    });

    test('empty list', () {
      final s = summarizeHistory(const []);
      expect(s.totalAmount, 0);
      expect(s.slipCount, 0);
      expect(s.days, isEmpty);
    });
  });
}
