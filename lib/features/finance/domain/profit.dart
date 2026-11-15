/// Pure Dart (no Firebase) so it can be unit tested.
///
/// Profit = sales - cost of the stock that was sold - stock loss - expenses.
/// The cost of sold stock uses a MOVING AVERAGE per material, replaying every
/// purchase, sale and stock adjustment in the order it happened:
///   * purchase         -> stock weight and stock cost go up
///   * sale             -> cost of sold stock = weight x current average cost
///   * minus adjustment -> counted as stock loss at the current average cost
///   * plus adjustment  -> added at the current average cost (no profit effect)
/// Cancelled (voided) slips are left out before this function is called.
library;

import '../../inventory/domain/sale_models.dart' show AdjustmentReason;

enum LedgerKind { purchase, adjustment, sale }

class LedgerEvent {
  const LedgerEvent({
    required this.kind,
    required this.at,
    required this.dayKey,
    required this.materialId,
    required this.materialName,
    required this.grams,
    this.amount = 0,
    this.reason,
  });

  final LedgerKind kind;
  final DateTime at;
  final String dayKey; // "yyyy-MM-dd"
  final String materialId;
  final String materialName;

  /// purchase / sale: weight on the scale (> 0). adjustment: signed change.
  final int grams;

  /// purchase / sale: money paid / received. adjustment: 0.
  final int amount;

  final AdjustmentReason? reason;
}

class MaterialProfit {
  const MaterialProfit({
    required this.materialId,
    required this.name,
    required this.soldGrams,
    required this.salesAmount,
    required this.cost,
    required this.lossCost,
    required this.noCostGrams,
    this.garbageGrams = 0,
    this.garbageCost = 0,
  });

  final String materialId;
  final String name;
  final int soldGrams;
  final int salesAmount;
  final int cost;
  final int lossCost;

  /// Grams sold while the app had no buying record for this material.
  final int noCostGrams;

  final int garbageGrams;
  final int garbageCost;

  int get profit => salesAmount - cost;

  /// Null when nothing was sold.
  double? get marginPercent => salesAmount <= 0 ? null : profit * 100 / salesAmount;

  /// Profit per kg sold. Null when nothing was sold.
  int? get profitPerKg => soldGrams <= 0 ? null : (profit * 1000 / soldGrams).round();
}

class ProfitReport {
  const ProfitReport({
    required this.materials,
    required this.stockCostNow,
  });

  /// Best profit first.
  final List<MaterialProfit> materials;

  /// What the stock still in the shop cost (as of now, not of the period end).
  final int stockCostNow;

  int get salesAmount => materials.fold(0, (s, m) => s + m.salesAmount);
  int get soldGrams => materials.fold(0, (s, m) => s + m.soldGrams);
  int get cost => materials.fold(0, (s, m) => s + m.cost);
  int get lossCost => materials.fold(0, (s, m) => s + m.lossCost);
  int get noCostGrams => materials.fold(0, (s, m) => s + m.noCostGrams);
  int get garbageGrams => materials.fold(0, (s, m) => s + m.garbageGrams);
  int get garbageCost => materials.fold(0, (s, m) => s + m.garbageCost);
  int get grossProfit => salesAmount - cost;

  int netProfit(int expenses) => grossProfit - lossCost - expenses;
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

class _Acc {
  String name = '';
  int soldGrams = 0;
  int sales = 0;
  double cost = 0;
  double loss = 0;
  int noCost = 0;
  int garbageGrams = 0;
  double garbageCost = 0;
}

ProfitReport computeProfit(
  List<LedgerEvent> events, {
  required String from,
  required String to,
}) {
  final sorted = [...events]
    ..sort((a, b) {
      final t = a.at.compareTo(b.at);
      return t != 0 ? t : a.kind.index.compareTo(b.kind.index);
    });

  bool inRange(String d) => d.compareTo(from) >= 0 && d.compareTo(to) <= 0;

  final states = <String, _State>{};
  final accs = <String, _Acc>{};

  for (final e in sorted) {
    final st = states.putIfAbsent(e.materialId, _State.new);
    final acc = accs.putIfAbsent(e.materialId, _Acc.new);
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
        if (counts) {
          acc.soldGrams += e.grams;
          acc.sales += e.amount;
          acc.cost += c;
          if (a == 0) acc.noCost += e.grams;
        }
      case LedgerKind.adjustment:
        if (e.grams > 0) {
          st.cost += st.avg * e.grams;
          st.grams += e.grams;
        } else if (e.grams < 0) {
          final n = -e.grams;
          final c = st.avg * n;
          st.take(n, c);
          if (counts) {
            acc.loss += c;
            if (e.reason == AdjustmentReason.garbage) {
              acc.garbageGrams += n;
              acc.garbageCost += c;
            }
          }
        }
    }
  }

  final rows = <MaterialProfit>[];
  accs.forEach((id, a) {
    if (a.soldGrams == 0 && a.loss == 0) return;
    rows.add(MaterialProfit(
      materialId: id,
      name: a.name.isEmpty ? id : a.name,
      soldGrams: a.soldGrams,
      salesAmount: a.sales,
      cost: a.cost.round(),
      lossCost: a.loss.round(),
      noCostGrams: a.noCost,
      garbageGrams: a.garbageGrams,
      garbageCost: a.garbageCost.round(),
    ));
  });
  rows.sort((a, b) => b.profit.compareTo(a.profit));

  final stockCost = states.values.fold<double>(0, (s, st) => s + st.cost);
  return ProfitReport(materials: rows, stockCostNow: stockCost.round());
}
