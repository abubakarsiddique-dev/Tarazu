import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/format.dart';
import 'models.dart';

/// One line on a sale: weight leaving the shop, priced per kg.
class SaleItem {
  const SaleItem({
    required this.materialId,
    required this.materialName,
    required this.weightGrams,
    required this.ratePerKg,
    required this.amount,
  });

  final String materialId;
  final String materialName;
  final int weightGrams;
  final double ratePerKg;
  final int amount;

  Map<String, Object?> toMap() => {
        'materialId': materialId,
        'materialName': materialName, // copied so later renames don't rewrite history
        'weightGrams': weightGrams,
        'ratePerKg': ratePerKg,
        'amount': amount,
      };

  factory SaleItem.fromMap(Map<String, dynamic> m) => SaleItem(
        materialId: m['materialId'] as String? ?? '',
        materialName: m['materialName'] as String? ?? '',
        weightGrams: (m['weightGrams'] as num?)?.toInt() ?? 0,
        ratePerKg: (m['ratePerKg'] as num?)?.toDouble() ?? 0,
        amount: (m['amount'] as num?)?.toInt() ?? 0,
      );

  /// "12.5 kg × Rs 55"
  String get detail => '${formatKg(weightGrams)} × ${formatRate(ratePerKg)}';
}

/// A sale (dispatch) to a bigger dealer or factory: one buyer, 1..n items.
class Sale {
  const Sale({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.totalWeightGrams,
    required this.buyerName,
    required this.dayKey,
    required this.createdAt,
    required this.pendingSync,
    this.createdBy = '',
  });

  final String id;
  final List<SaleItem> items;
  final int totalAmount;
  final int totalWeightGrams;
  final String buyerName;
  final String dayKey;
  final DateTime createdAt;
  final bool pendingSync;

  String get title {
    final names = items.map((i) => i.materialName).toList();
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }
  final String createdBy;
  factory Sale.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final raw = m['items'];
    final items = raw is List
        ? raw.whereType<Map>().map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e))).toList()
        : <SaleItem>[];
    return Sale(
      id: d.id,
      items: items,
      totalAmount: (m['totalAmount'] as num?)?.toInt() ?? 0,
      totalWeightGrams: (m['totalWeightGrams'] as num?)?.toInt() ?? 0,
      buyerName: m['buyerName'] as String? ?? '',
      dayKey: m['dayKey'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pendingSync: d.metadata.hasPendingWrites,
      createdBy: m['createdBy'] as String? ?? '',
    );
  }
}

/// Why stock was changed by hand. Stored by name in Firestore.
enum AdjustmentReason { correction, loss, other }

/// Grams of [materialId] still free to sell: what is in stock minus what is
/// already on the sale slip being typed. Pure, so it can be unit tested.
int remainingToSell(List<StockItem> stock, List<SaleItem> onSlip, String materialId) {
  final inStock = stock
      .where((s) => s.materialId == materialId)
      .fold<int>(0, (total, s) => total + s.weightGrams);
  final used = onSlip
      .where((i) => i.materialId == materialId)
      .fold<int>(0, (total, i) => total + i.weightGrams);
  return inStock - used;
}
