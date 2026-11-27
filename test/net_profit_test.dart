import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/features/finance/domain/expense.dart';
import 'package:tarazu/features/finance/domain/net_profit.dart';
import 'package:tarazu/features/inventory/domain/garbage_history.dart';
import 'package:tarazu/features/inventory/domain/models.dart';
import 'package:tarazu/features/inventory/domain/sale_models.dart';

Purchase _purchase(String id, String name, int grams, int amount) => Purchase(
      id: 'p_$id',
      items: [
        PurchaseItem(
          materialId: id,
          materialName: name,
          weightGrams: grams,
          unit: PriceUnit.kg,
          rate: grams > 0 ? amount * 1000 / grams : 0,
          amount: amount,
        ),
      ],
      totalAmount: amount,
      totalWeightGrams: grams,
      sellerName: '',
      dayKey: '2026-11-10',
      createdAt: DateTime(2026, 11, 10, 10),
      pendingSync: false,
    );

Sale _sale(String id, String name, int grams, int amount) => Sale(
      id: 's_$id',
      items: [
        SaleItem(
          materialId: id,
          materialName: name,
          weightGrams: grams,
          ratePerKg: grams > 0 ? amount * 1000 / grams : 0,
          amount: amount,
        ),
      ],
      totalAmount: amount,
      totalWeightGrams: grams,
      buyerName: '',
      dayKey: '2026-11-12',
      createdAt: DateTime(2026, 11, 12, 14),
      pendingSync: false,
    );

Expense _expense(int amount) => Expense(
      id: 'e1',
      amount: amount,
      category: ExpenseCategory.labour,
      note: '',
      dayKey: '2026-11-12',
      createdAt: DateTime(2026, 11, 12, 16),
      pendingSync: false,
    );

GarbageHistorySummary _garbage(String id, String name, int grams, int cost) =>
    GarbageHistorySummary(
      entries: [
        GarbageEntry(
          id: 'g1',
          materialId: id,
          materialName: name,
          grams: grams,
          cost: cost,
          rawCost: cost.toDouble(),
          dayKey: '2026-11-13',
          createdAt: DateTime(2026, 11, 13, 9),
        ),
      ],
      materials: [
        GarbageMaterialTotal(
          materialId: id,
          name: name,
          grams: grams,
          cost: cost,
          entryCount: 1,
        ),
      ],
    );

void main() {
  test('profit case: selling - buying - expenses - garbage > 0', () {
    final s = computeNetProfitSummary(
      purchases: [_purchase('iron', 'Iron', 20000, 800)],
      sales: [_sale('iron', 'Iron', 18000, 1200)],
      expenses: [_expense(150)],
      garbage: _garbage('iron', 'Iron', 2000, 80),
    );

    expect(s.totalSellingPrice, 1200);
    expect(s.totalBuyingPrice, 800);
    expect(s.totalExpenses, 150);
    expect(s.totalGarbageCost, 80);
    expect(s.netProfit, 170); // 1200 - 800 - 150 - 80
    expect(s.isProfit, isTrue);
    expect(s.isLoss, isFalse);
    expect(s.isEmpty, isFalse);

    final row = s.materials.single;
    expect(row.boughtAmount, 800);
    expect(row.soldAmount, 1200);
    expect(row.garbageCost, 80);
  });

  test('loss case: buying + expenses + garbage exceeds selling price', () {
    final s = computeNetProfitSummary(
      purchases: [_purchase('iron', 'Iron', 20000, 1000)],
      sales: [_sale('iron', 'Iron', 15000, 900)],
      expenses: [_expense(200)],
      garbage: _garbage('iron', 'Iron', 2000, 100),
    );

    expect(s.netProfit, -400); // 900 - 1000 - 200 - 100
    expect(s.isProfit, isFalse);
    expect(s.isLoss, isTrue);
  });

  test('break-even and empty cases', () {
    final empty = computeNetProfitSummary(
      purchases: const [],
      sales: const [],
      expenses: const [],
      garbage: const GarbageHistorySummary(entries: [], materials: []),
    );
    expect(empty.netProfit, 0);
    expect(empty.isProfit, isFalse);
    expect(empty.isLoss, isFalse);
    expect(empty.isEmpty, isTrue);

    final even = computeNetProfitSummary(
      purchases: [_purchase('copper', 'Copper', 10000, 500)],
      sales: [_sale('copper', 'Copper', 10000, 600)],
      expenses: [_expense(100)],
      garbage: const GarbageHistorySummary(entries: [], materials: []),
    );
    expect(even.netProfit, 0);
    expect(even.isProfit, isFalse);
    expect(even.isLoss, isFalse);
    expect(even.isEmpty, isFalse);
  });
}
