import 'package:cloud_firestore/cloud_firestore.dart';

/// Stored by name in Firestore.
enum ExpenseCategory { labour, rent, utilities, transport, food, other }

extension ExpenseCategoryLabel on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.labour => 'Labour',
        ExpenseCategory.rent => 'Rent',
        ExpenseCategory.utilities => 'Electricity / gas',
        ExpenseCategory.transport => 'Transport / loading',
        ExpenseCategory.food => 'Tea / food',
        ExpenseCategory.other => 'Other',
      };
}

ExpenseCategory expenseCategoryFromName(String? n) =>
    ExpenseCategory.values.firstWhere((c) => c.name == n, orElse: () => ExpenseCategory.other);

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.dayKey,
    required this.createdAt,
    required this.pendingSync,
  });

  final String id;
  final int amount;
  final ExpenseCategory category;
  final String note;
  final String dayKey;
  final DateTime createdAt;
  final bool pendingSync;

  factory Expense.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Expense(
      id: d.id,
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      category: expenseCategoryFromName(m['category'] as String?),
      note: m['note'] as String? ?? '',
      dayKey: m['dayKey'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pendingSync: d.metadata.hasPendingWrites,
    );
  }
}
