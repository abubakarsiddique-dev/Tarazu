import '../../../core/utils/format.dart';
import 'history.dart';
import 'sale_models.dart';

class SalesMaterialTotal {
  const SalesMaterialTotal({
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

class SalesSummary {
  const SalesSummary({
    required this.totalAmount,
    required this.totalGrams,
    required this.saleCount,
    required this.materials,
  });

  final int totalAmount;
  final int totalGrams;
  final int saleCount;

  /// Biggest amount first.
  final List<SalesMaterialTotal> materials;
}

/// Pure function (no Firebase): totals for a list of (non-voided) sales.
SalesSummary summarizeSales(List<Sale> sales) {
  final map = <String, ({String name, int amount, int grams})>{};
  var totalAmount = 0;
  var totalGrams = 0;

  for (final s in sales) {
    totalAmount += s.totalAmount;
    totalGrams += s.totalWeightGrams;
    for (final i in s.items) {
      final prev = map[i.materialId];
      map[i.materialId] = (
        name: i.materialName,
        amount: (prev?.amount ?? 0) + i.amount,
        grams: (prev?.grams ?? 0) + i.weightGrams,
      );
    }
  }

  final materials = map.entries
      .map((e) => SalesMaterialTotal(
            materialId: e.key,
            name: e.value.name,
            amount: e.value.amount,
            grams: e.value.grams,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  return SalesSummary(
    totalAmount: totalAmount,
    totalGrams: totalGrams,
    saleCount: sales.length,
    materials: materials,
  );
}

/// One material: what was bought and what was sold in the period.
class MaterialRow {
  const MaterialRow({
    required this.name,
    required this.boughtGrams,
    required this.boughtAmount,
    required this.soldGrams,
    required this.soldAmount,
  });

  final String name;
  final int boughtGrams;
  final int boughtAmount;
  final int soldGrams;
  final int soldAmount;
}

List<MaterialRow> combineMaterials(HistorySummary purchases, SalesSummary sales) {
  final map = <String, MaterialRow>{};
  for (final m in purchases.materials) {
    map[m.materialId] = MaterialRow(
      name: m.name,
      boughtGrams: m.grams,
      boughtAmount: m.amount,
      soldGrams: 0,
      soldAmount: 0,
    );
  }
  for (final m in sales.materials) {
    final prev = map[m.materialId];
    map[m.materialId] = MaterialRow(
      name: prev?.name ?? m.name,
      boughtGrams: prev?.boughtGrams ?? 0,
      boughtAmount: prev?.boughtAmount ?? 0,
      soldGrams: m.grams,
      soldAmount: m.amount,
    );
  }
  return map.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Plain text for WhatsApp. Sales minus purchases is NOT profit: stock that is
/// still unsold was paid for but not yet sold. The text says so.
String buildReportText({
  required String shopName,
  required String periodLabel,
  required HistorySummary purchases,
  required SalesSummary sales,
}) {
  final diff = sales.totalAmount - purchases.totalAmount;
  final rows = combineMaterials(purchases, sales);
  final b = StringBuffer()
    ..writeln(shopName.isEmpty ? 'Report' : shopName)
    ..writeln(periodLabel)
    ..writeln()
    ..writeln('Purchases: ${formatRs(purchases.totalAmount)} '
        '(${formatKg(purchases.totalGrams)}, ${purchases.slipCount} slips)')
    ..writeln('Sales: ${formatRs(sales.totalAmount)} '
        '(${formatKg(sales.totalGrams)}, ${sales.saleCount} sales)')
    ..writeln('Sales minus purchases: ${diff < 0 ? '-' : ''}${formatRs(diff.abs())}');
  if (rows.isNotEmpty) {
    b
      ..writeln()
      ..writeln('By material');
    for (final r in rows) {
      b.writeln('${r.name}: bought ${formatKg(r.boughtGrams)} / ${formatRs(r.boughtAmount)}'
          '  |  sold ${formatKg(r.soldGrams)} / ${formatRs(r.soldAmount)}');
    }
  }
  b
    ..writeln()
    ..write('Note: this is not profit. Unsold stock is not counted.');
  return b.toString();
}
