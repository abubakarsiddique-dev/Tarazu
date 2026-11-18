import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/features/finance/domain/profit.dart';
import 'package:tarazu/features/inventory/domain/garbage_history.dart';
import 'package:tarazu/features/inventory/domain/sale_models.dart'
    show AdjustmentReason;

LedgerEvent _e(
  LedgerKind kind,
  DateTime at,
  String day,
  String id,
  int grams, [
  int amount = 0,
  AdjustmentReason? reason,
  double costPerKg = 0,
]) => LedgerEvent(
  kind: kind,
  at: at,
  dayKey: day,
  materialId: id,
  materialName: id[0].toUpperCase() + id.substring(1),
  grams: grams,
  amount: amount,
  reason: reason,
  costPerKg: costPerKg,
);

void main() {
  test(
    'across multiple date ranges, totalGrams and totalCost match computeProfit garbageGrams and garbageCost',
    () {
      final events = [
        // Oct purchases
        _e(
          LedgerKind.purchase,
          DateTime(2026, 10, 10, 9),
          '2026-10-10',
          'iron',
          20000,
          800,
        ), // Rs 40/kg
        _e(
          LedgerKind.purchase,
          DateTime(2026, 10, 20, 10),
          '2026-10-20',
          'copper',
          10000,
          1000,
        ), // Rs 100/kg
        // Nov 1: garbage on iron (2 kg @ 40 = 80)
        _e(
          LedgerKind.adjustment,
          DateTime(2026, 11, 1, 11),
          '2026-11-01',
          'iron',
          -2000,
          0,
          AdjustmentReason.garbage,
        ),
        // Nov 3: buy more iron at higher rate (9 kg for Rs 450 -> 50/kg; blended with 18 kg @ 40 = 720 + 450 = 1170 / 27 kg = 43.333.../kg)
        _e(
          LedgerKind.purchase,
          DateTime(2026, 11, 3, 12),
          '2026-11-03',
          'iron',
          9000,
          450,
        ),
        // Nov 5: garbage on iron (1 kg @ 43.333... = 43.333...) and copper (1.5 kg @ 100 = 150)
        _e(
          LedgerKind.adjustment,
          DateTime(2026, 11, 5, 14),
          '2026-11-05',
          'iron',
          -1000,
          0,
          AdjustmentReason.garbage,
        ),
        _e(
          LedgerKind.adjustment,
          DateTime(2026, 11, 5, 15),
          '2026-11-05',
          'copper',
          -1500,
          0,
          AdjustmentReason.garbage,
        ),
        // Nov 6: non-garbage loss on iron (should NOT count in garbageGrams, but affects stock)
        _e(
          LedgerKind.adjustment,
          DateTime(2026, 11, 6, 10),
          '2026-11-06',
          'iron',
          -1000,
          0,
          AdjustmentReason.loss,
        ),
        // Nov 10: another garbage on iron (1 kg @ 43.333... = 43.333...)
        _e(
          LedgerKind.adjustment,
          DateTime(2026, 11, 10, 16),
          '2026-11-10',
          'iron',
          -1000,
          0,
          AdjustmentReason.garbage,
        ),
      ];

      const ranges = [
        (from: '2026-11-01', to: '2026-11-01'),
        (from: '2026-11-02', to: '2026-11-06'),
        (from: '2026-11-05', to: '2026-11-10'),
        (from: '2026-11-01', to: '2026-11-30'),
        (from: '2026-10-01', to: '2026-10-31'),
      ];

      for (final r in ranges) {
        final profit = computeProfit(events, from: r.from, to: r.to);
        final gh = computeGarbageHistory(events, from: r.from, to: r.to);

        expect(
          gh.totalGrams,
          profit.garbageGrams,
          reason: 'totalGrams mismatch for ${r.from}..${r.to}',
        );
        expect(
          gh.totalCost,
          profit.garbageCost,
          reason: 'totalCost mismatch for ${r.from}..${r.to}',
        );

        for (final gm in gh.materials) {
          final pm = profit.materials.firstWhere(
            (m) => m.materialId == gm.materialId,
          );
          expect(gm.grams, pm.garbageGrams);
          expect(gm.cost, pm.garbageCost);
        }
      }
    },
  );

  test(
    'mid-month garbage entry uses moving-average cost from purchases in the previous month',
    () {
      // Oct 10: buy 10 kg @ Rs 40/kg (400)
      // Oct 25: buy 10 kg @ Rs 60/kg (600) -> blended 20 kg costing Rs 1000 (Rs 50/kg)
      // Oct 28: sell 5 kg -> 15 kg left costing Rs 750 (Rs 50/kg)
      // Nov 15 (mid-month, no Nov purchases): 3 kg garbage -> cost = 3 * 50 = Rs 150
      final events = [
        _e(
          LedgerKind.purchase,
          DateTime(2026, 10, 10, 10),
          '2026-10-10',
          'brass',
          10000,
          400,
        ),
        _e(
          LedgerKind.purchase,
          DateTime(2026, 10, 25, 10),
          '2026-10-25',
          'brass',
          10000,
          600,
        ),
        _e(
          LedgerKind.sale,
          DateTime(2026, 10, 28, 12),
          '2026-10-28',
          'brass',
          5000,
          350,
        ),
        _e(
          LedgerKind.adjustment,
          DateTime(2026, 11, 15, 14),
          '2026-11-15',
          'brass',
          -3000,
          0,
          AdjustmentReason.garbage,
        ),
      ];

      final gh = computeGarbageHistory(
        events,
        from: '2026-11-01',
        to: '2026-11-30',
      );
      final profit = computeProfit(
        events,
        from: '2026-11-01',
        to: '2026-11-30',
      );

      expect(gh.entries.length, 1);
      expect(gh.entries.single.grams, 3000);
      expect(gh.entries.single.cost, 150);
      expect(gh.totalGrams, 3000);
      expect(gh.totalCost, 150);
      expect(gh.totalGrams, profit.garbageGrams);
      expect(gh.totalCost, profit.garbageCost);
    },
  );

  test(
    'openingStock seeds moving-average cost for subsequent garbage removal',
    () {
      // Opening stock: 10 kg @ Rs 80/kg.
      // Garbage removal: 2.5 kg -> cost = 2.5 * 80 = Rs 200.
      final events = [
        _e(
          LedgerKind.adjustment,
          DateTime(2026, 11, 1, 8),
          '2026-11-01',
          'aluminium',
          10000,
          0,
          AdjustmentReason.openingStock,
          80,
        ),
        _e(
          LedgerKind.adjustment,
          DateTime(2026, 11, 2, 11),
          '2026-11-02',
          'aluminium',
          -2500,
          0,
          AdjustmentReason.garbage,
        ),
      ];

      final gh = computeGarbageHistory(
        events,
        from: '2026-11-01',
        to: '2026-11-30',
      );
      final profit = computeProfit(
        events,
        from: '2026-11-01',
        to: '2026-11-30',
      );

      expect(gh.entries.length, 1);
      expect(gh.entries.single.grams, 2500);
      expect(gh.entries.single.cost, 200);
      expect(gh.totalGrams, profit.garbageGrams);
      expect(gh.totalCost, profit.garbageCost);
    },
  );

  test(
    'attaches metadata (note, createdBy, id) from GarbageAdjustmentDoc and sorts newest first',
    () {
      final t1 = DateTime(2026, 11, 5, 9, 30);
      final t2 = DateTime(2026, 11, 5, 16, 45);
      final events = [
        _e(
          LedgerKind.purchase,
          DateTime(2026, 11, 1, 8),
          '2026-11-01',
          'plastic',
          10000,
          300,
        ), // Rs 30/kg
        _e(
          LedgerKind.adjustment,
          t1,
          '2026-11-05',
          'plastic',
          -1000,
          0,
          AdjustmentReason.garbage,
        ),
        _e(
          LedgerKind.adjustment,
          t2,
          '2026-11-05',
          'plastic',
          -2000,
          0,
          AdjustmentReason.garbage,
        ),
      ];

      final docs = [
        GarbageAdjustmentDoc(
          id: 'doc_1',
          materialId: 'plastic',
          materialName: 'Plastic',
          deltaGrams: -1000,
          dayKey: '2026-11-05',
          createdAt: t1,
          note: 'Wet dirt mixed',
          createdBy: 'owner_uid',
        ),
        GarbageAdjustmentDoc(
          id: 'doc_2',
          materialId: 'plastic',
          materialName: 'Plastic',
          deltaGrams: -2000,
          dayKey: '2026-11-05',
          createdAt: t2,
          note: 'Broken non-recyclable',
          createdBy: 'owner_uid',
          pendingSync: true,
        ),
      ];

      final gh = computeGarbageHistory(
        events,
        from: '2026-11-05',
        to: '2026-11-05',
        docs: docs,
      );

      expect(gh.entries.length, 2);
      // Newest first (t2 then t1)
      expect(gh.entries[0].id, 'doc_2');
      expect(gh.entries[0].grams, 2000);
      expect(gh.entries[0].cost, 60);
      expect(gh.entries[0].note, 'Broken non-recyclable');
      expect(gh.entries[0].pendingSync, isTrue);

      expect(gh.entries[1].id, 'doc_1');
      expect(gh.entries[1].grams, 1000);
      expect(gh.entries[1].cost, 30);
      expect(gh.entries[1].note, 'Wet dirt mixed');
      expect(gh.entries[1].createdBy, 'owner_uid');

      expect(gh.materials.single.grams, 3000);
      expect(gh.materials.single.cost, 90);
      expect(gh.materials.single.entryCount, 2);
    },
  );
}
