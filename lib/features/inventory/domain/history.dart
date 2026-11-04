import 'models.dart';

enum HistoryPeriod { day, week, month }

/// First day of the period that contains [d]. Weeks start on Monday.
DateTime periodStart(HistoryPeriod p, DateTime d) {
  switch (p) {
    case HistoryPeriod.day:
      return DateTime(d.year, d.month, d.day);
    case HistoryPeriod.week:
      return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
    case HistoryPeriod.month:
      return DateTime(d.year, d.month, 1);
  }
}

/// Last day (inclusive) of the period starting at [start].
DateTime periodEnd(HistoryPeriod p, DateTime start) {
  switch (p) {
    case HistoryPeriod.day:
      return start;
    case HistoryPeriod.week:
      return DateTime(start.year, start.month, start.day + 6);
    case HistoryPeriod.month:
      return DateTime(start.year, start.month + 1, 0);
  }
}

/// Start of the period [n] steps away (n = -1 previous, +1 next).
DateTime shiftPeriod(HistoryPeriod p, DateTime start, int n) {
  switch (p) {
    case HistoryPeriod.day:
      return DateTime(start.year, start.month, start.day + n);
    case HistoryPeriod.week:
      return DateTime(start.year, start.month, start.day + 7 * n);
    case HistoryPeriod.month:
      return DateTime(start.year, start.month + n, 1);
  }
}

class DayTotal {
  const DayTotal({
    required this.dayKey,
    required this.amount,
    required this.grams,
    required this.slips,
  });

  final String dayKey;
  final int amount;
  final int grams;
  final int slips;
}

class MaterialTotal {
  const MaterialTotal({
    required this.materialId,
    required this.name,
    required this.amount,
    required this.grams,
  });

  final String materialId;
  final String name;
  final int amount;
  final int grams;
}

class HistorySummary {
  const HistorySummary({
    required this.totalAmount,
    required this.totalGrams,
    required this.slipCount,
    required this.days,
    required this.materials,
    required this.slips,
  });

  final int totalAmount;
  final int totalGrams;
  final int slipCount;

  /// Newest day first.
  final List<DayTotal> days;

  /// Biggest amount first.
  final List<MaterialTotal> materials;

  /// Newest first. With a material filter: only slips that contain it.
  final List<Purchase> slips;
}

/// Pure function (no Firebase): totals for a list of purchases.
/// When [materialId] is set, only the lines of that material are counted, and
/// a slip counts only if it has such a line.
HistorySummary summarizeHistory(List<Purchase> purchases, {String? materialId}) {
  final dayMap = <String, ({int amount, int grams, int slips})>{};
  final matMap = <String, ({String name, int amount, int grams})>{};
  final slips = <Purchase>[];
  var totalAmount = 0;
  var totalGrams = 0;

  for (final p in purchases) {
    final lines = materialId == null
        ? p.items
        : p.items.where((i) => i.materialId == materialId).toList();
    if (lines.isEmpty) continue;
    slips.add(p);

    var slipAmount = 0;
    var slipGrams = 0;
    for (final i in lines) {
      slipAmount += i.amount;
      slipGrams += i.weightGrams;
      final prev = matMap[i.materialId];
      matMap[i.materialId] = (
        name: i.materialName,
        amount: (prev?.amount ?? 0) + i.amount,
        grams: (prev?.grams ?? 0) + i.weightGrams,
      );
    }
    totalAmount += slipAmount;
    totalGrams += slipGrams;

    final d = dayMap[p.dayKey];
    dayMap[p.dayKey] = (
      amount: (d?.amount ?? 0) + slipAmount,
      grams: (d?.grams ?? 0) + slipGrams,
      slips: (d?.slips ?? 0) + 1,
    );
  }

  final days = dayMap.entries
      .map((e) => DayTotal(
            dayKey: e.key,
            amount: e.value.amount,
            grams: e.value.grams,
            slips: e.value.slips,
          ))
      .toList()
    ..sort((a, b) => b.dayKey.compareTo(a.dayKey));

  final materials = matMap.entries
      .map((e) => MaterialTotal(
            materialId: e.key,
            name: e.value.name,
            amount: e.value.amount,
            grams: e.value.grams,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  slips.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return HistorySummary(
    totalAmount: totalAmount,
    totalGrams: totalGrams,
    slipCount: slips.length,
    days: days,
    materials: materials,
    slips: slips,
  );
}
