/// Pure Dart (no Firebase) so it can be unit tested.
///
/// Reuses the exact moving-average cost semantics of [computeProfit] in
/// `features/finance/domain/profit.dart`:
///   * Every purchase, sale, and stock adjustment in the shop's history is
///     replayed in chronological order (`at`, then `kind.index`).
///   * When a negative adjustment has `reason == AdjustmentReason.garbage`,
///     its removed weight `n = -e.grams` is valued at `c = st.avg * n` (the
///     material's moving-average buying cost per gram at that exact moment).
///   * Rounding rule (matching `computeProfit`):
///       - Per-entry display cost: `c.round()` (`(st.avg * n).round()`).
///       - Per-material subtotal cost (`GarbageMaterialTotal.cost`): unrounded
///         `double` values `c` are summed per material across the `[from, to]`
///         period and rounded once at the end (`a.garbageCost.round()`),
///         identical to `MaterialProfit.garbageCost`.
///       - Period total cost (`GarbageHistorySummary.totalCost`): sum of the
///         per-material rounded costs (`materials.fold(0, (s, m) => s + m.cost)`),
///         identical to `ProfitReport.garbageCost`.
library;

import '../../finance/domain/profit.dart' show LedgerEvent, LedgerKind;
import 'sale_models.dart' show AdjustmentReason;

/// Metadata read from `shops/{shopId}/adjustments/{id}` for garbage entries in
/// the selected date range (`note`, `createdBy`, `pendingSync`).
class GarbageAdjustmentDoc {
  const GarbageAdjustmentDoc({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.deltaGrams,
    required this.dayKey,
    required this.createdAt,
    this.note = '',
    this.createdBy = '',
    this.pendingSync = false,
  });

  final String id;
  final String materialId;
  final String materialName;

  /// Negative weight in Firestore (`< 0` for removals).
  final int deltaGrams;
  final String dayKey;
  final DateTime createdAt;
  final String note;
  final String createdBy;
  final bool pendingSync;
}

/// One garbage removal entry in the selected period, with its moving-average
/// buying cost at the moment it was removed.
class GarbageEntry {
  const GarbageEntry({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.grams,
    required this.cost,
    required this.rawCost,
    required this.dayKey,
    required this.createdAt,
    this.note = '',
    this.createdBy = '',
    this.pendingSync = false,
  });

  final String id;
  final String materialId;
  final String materialName;

  /// Positive weight removed as garbage (in grams).
  final int grams;

  /// Rounded cost of this entry (`rawCost.round()`).
  final int cost;

  /// Exact unrounded moving-average cost (`st.avg * grams`).
  final double rawCost;

  final String dayKey;
  final DateTime createdAt;
  final String note;
  final String createdBy;
  final bool pendingSync;
}

/// Per-material garbage subtotal for the selected period.
class GarbageMaterialTotal {
  const GarbageMaterialTotal({
    required this.materialId,
    required this.name,
    required this.grams,
    required this.cost,
    required this.entryCount,
  });

  final String materialId;
  final String name;
  final int grams;

  /// Rounded from the unrounded sum of `c` for this material (`a.garbageCost.round()`),
  /// matching `MaterialProfit.garbageCost` in `computeProfit`.
  final int cost;
  final int entryCount;
}

class GarbageHistorySummary {
  const GarbageHistorySummary({
    required this.entries,
    required this.materials,
  });

  /// Newest first (`createdAt` descending).
  final List<GarbageEntry> entries;

  /// Highest garbage cost first (then highest weight).
  final List<GarbageMaterialTotal> materials;

  int get entryCount => entries.length;

  /// Matches `ProfitReport.garbageGrams`.
  int get totalGrams => materials.fold(0, (s, m) => s + m.grams);

  /// Sum of per-material rounded costs, matching `ProfitReport.garbageCost`.
  int get totalCost => materials.fold(0, (s, m) => s + m.cost);
}

class _State {
  int grams = 0;
  double cost = 0;
  double lastRate = 0; // cost per gram of the most recent purchase

  double get avg => grams > 0 ? cost / grams : lastRate;

  void take(int g, double removedCost) {
    cost -= removedCost > cost ? cost : removedCost;
    grams = grams - g < 0 ? 0 : grams - g;
    if (grams == 0) cost = 0; // only rounding dust can be left
  }
}

class _MatAcc {
  String name = '';
  int grams = 0;
  double cost = 0;
  int count = 0;
}

GarbageHistorySummary computeGarbageHistory(
  List<LedgerEvent> events, {
  required String from,
  required String to,
  List<GarbageAdjustmentDoc> docs = const [],
}) {
  final sorted = [...events]
    ..sort((a, b) {
      final t = a.at.compareTo(b.at);
      return t != 0 ? t : a.kind.index.compareTo(b.kind.index);
    });

  bool inRange(String d) => d.compareTo(from) >= 0 && d.compareTo(to) <= 0;

  // Keep a mutable pool of range docs so each garbage LedgerEvent can claim its
  // matching adjustment document metadata (note, createdBy, pendingSync, id).
  final unmatchedDocs = [...docs];

  GarbageAdjustmentDoc? claimDoc(LedgerEvent e) {
    for (var i = 0; i < unmatchedDocs.length; i++) {
      final d = unmatchedDocs[i];
      if (d.materialId == e.materialId &&
          d.deltaGrams == e.grams &&
          d.dayKey == e.dayKey &&
          d.createdAt.isAtSameMomentAs(e.at)) {
        return unmatchedDocs.removeAt(i);
      }
    }
    for (var i = 0; i < unmatchedDocs.length; i++) {
      final d = unmatchedDocs[i];
      if (d.materialId == e.materialId &&
          d.deltaGrams == e.grams &&
          d.dayKey == e.dayKey) {
        return unmatchedDocs.removeAt(i);
      }
    }
    return null;
  }

  final states = <String, _State>{};
  final accs = <String, _MatAcc>{};
  final entries = <GarbageEntry>[];
  var seq = 0;

  for (final e in sorted) {
    final st = states.putIfAbsent(e.materialId, _State.new);
    final acc = accs.putIfAbsent(e.materialId, _MatAcc.new);
    if (e.materialName.isNotEmpty) acc.name = e.materialName;
    final counts = inRange(e.dayKey);

    switch (e.kind) {
      case LedgerKind.purchase:
        st.grams += e.grams;
        st.cost += e.amount;
        if (e.grams > 0) st.lastRate = e.amount / e.grams;
      case LedgerKind.sale:
        final a = st.avg;
        final c = a * e.grams;
        st.take(e.grams, c);
      case LedgerKind.adjustment:
        if (e.grams > 0) {
          if (e.reason == AdjustmentReason.openingStock) {
            final totalCost = e.costPerKg * e.grams / 1000;
            st.cost += totalCost;
            st.grams += e.grams;
            if (e.grams > 0) st.lastRate = e.costPerKg / 1000;
          } else {
            st.cost += st.avg * e.grams;
            st.grams += e.grams;
          }
        } else if (e.grams < 0) {
          final n = -e.grams;
          final c = st.avg * n;
          st.take(n, c);
          if (counts && e.reason == AdjustmentReason.garbage) {
            acc.grams += n;
            acc.cost += c;
            acc.count += 1;
            final doc = claimDoc(e);
            seq += 1;
            entries.add(
              GarbageEntry(
                id: doc?.id ?? 'garbage_$seq',
                materialId: e.materialId,
                materialName: e.materialName.isEmpty
                    ? (acc.name.isEmpty ? e.materialId : acc.name)
                    : e.materialName,
                grams: n,
                cost: c.round(),
                rawCost: c,
                dayKey: e.dayKey,
                createdAt: e.at,
                note: doc?.note ?? '',
                createdBy: doc?.createdBy ?? '',
                pendingSync: doc?.pendingSync ?? false,
              ),
            );
          }
        }
    }
  }

  entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final materials = <GarbageMaterialTotal>[];
  accs.forEach((id, a) {
    if (a.grams <= 0) return;
    materials.add(
      GarbageMaterialTotal(
        materialId: id,
        name: a.name.isEmpty ? id : a.name,
        grams: a.grams,
        cost: a.cost.round(),
        entryCount: a.count,
      ),
    );
  });
  materials.sort((a, b) {
    final c = b.cost.compareTo(a.cost);
    return c != 0 ? c : b.grams.compareTo(a.grams);
  });

  return GarbageHistorySummary(entries: entries, materials: materials);
}
