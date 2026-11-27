/// Pure Dart (no Firebase) so it can be unit tested.
///
/// Net Profit (cash-flow summary):
///   netProfit = totalSellingPrice - totalBuyingPrice - totalExpenses - totalGarbageCost
library;

import '../../inventory/domain/garbage_history.dart';
import '../../inventory/domain/history.dart';
import '../../inventory/domain/models.dart';
import '../../inventory/domain/report.dart';
import '../../inventory/domain/sale_models.dart';
import 'expense.dart';

class NetProfitMaterialRow {
  const NetProfitMaterialRow({
    required this.materialId,
    required this.name,
    required this.boughtGrams,
    required this.boughtAmount,
    required this.soldGrams,
    required this.soldAmount,
    required this.garbageGrams,
    required this.garbageCost,
  });

  final String materialId;
  final String name;
  final int boughtGrams;
  final int boughtAmount;
  final int soldGrams;
  final int soldAmount;
  final int garbageGrams;
  final int garbageCost;
}

class NetProfitSummary {
  const NetProfitSummary({
    required this.totalSellingPrice,
    required this.totalBuyingPrice,
    required this.totalExpenses,
    required this.totalGarbageCost,
    required this.soldGrams,
    required this.boughtGrams,
    required this.garbageGrams,
    required this.saleCount,
    required this.purchaseCount,
    required this.expenseCount,
    required this.garbageCount,
    required this.materials,
  });

  final int totalSellingPrice;
  final int totalBuyingPrice;
  final int totalExpenses;
  final int totalGarbageCost;
  final int soldGrams;
  final int boughtGrams;
  final int garbageGrams;
  final int saleCount;
  final int purchaseCount;
  final int expenseCount;
  final int garbageCount;
  final List<NetProfitMaterialRow> materials;

  int get netProfit =>
      totalSellingPrice -
      totalBuyingPrice -
      totalExpenses -
      totalGarbageCost;

  bool get isProfit => netProfit > 0;
  bool get isLoss => netProfit < 0;
  bool get isEmpty =>
      saleCount == 0 &&
      purchaseCount == 0 &&
      expenseCount == 0 &&
      garbageCount == 0;
}

NetProfitSummary computeNetProfitSummary({
  required List<Purchase> purchases,
  required List<Sale> sales,
  required List<Expense> expenses,
  required GarbageHistorySummary garbage,
}) {
  final purchaseSummary = summarizeHistory(purchases);
  final saleSummary = summarizeSales(sales);
  final expensesTotal = expenses.fold<int>(0, (sum, e) => sum + e.amount);

  final map = <String, NetProfitMaterialRow>{};

  for (final m in purchaseSummary.materials) {
    map[m.materialId] = NetProfitMaterialRow(
      materialId: m.materialId,
      name: m.name,
      boughtGrams: m.grams,
      boughtAmount: m.amount,
      soldGrams: 0,
      soldAmount: 0,
      garbageGrams: 0,
      garbageCost: 0,
    );
  }

  for (final m in saleSummary.materials) {
    final prev = map[m.materialId];
    map[m.materialId] = NetProfitMaterialRow(
      materialId: m.materialId,
      name: prev?.name ?? m.name,
      boughtGrams: prev?.boughtGrams ?? 0,
      boughtAmount: prev?.boughtAmount ?? 0,
      soldGrams: m.grams,
      soldAmount: m.amount,
      garbageGrams: prev?.garbageGrams ?? 0,
      garbageCost: prev?.garbageCost ?? 0,
    );
  }

  for (final m in garbage.materials) {
    final prev = map[m.materialId];
    map[m.materialId] = NetProfitMaterialRow(
      materialId: m.materialId,
      name: prev?.name ?? m.name,
      boughtGrams: prev?.boughtGrams ?? 0,
      boughtAmount: prev?.boughtAmount ?? 0,
      soldGrams: prev?.soldGrams ?? 0,
      soldAmount: prev?.soldAmount ?? 0,
      garbageGrams: m.grams,
      garbageCost: m.cost,
    );
  }

  final rows = map.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return NetProfitSummary(
    totalSellingPrice: saleSummary.totalAmount,
    totalBuyingPrice: purchaseSummary.totalAmount,
    totalExpenses: expensesTotal,
    totalGarbageCost: garbage.totalCost,
    soldGrams: saleSummary.totalGrams,
    boughtGrams: purchaseSummary.totalGrams,
    garbageGrams: garbage.totalGrams,
    saleCount: saleSummary.saleCount,
    purchaseCount: purchaseSummary.slipCount,
    expenseCount: expenses.length,
    garbageCount: garbage.entryCount,
    materials: rows,
  );
}
