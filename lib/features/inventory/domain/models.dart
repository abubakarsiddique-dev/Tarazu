import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/format.dart';

/// "2026-11-04" in the phone's local time. Used as the id of the daily summary.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// How a material is priced.
///  * kg        : rate is per kg of the weight shown on the scale.
///  * pakaSeer  : the scale weight is "kacha" (1 kacha seer = 1 kg). It is
///                converted to paka seer (1 paka seer = 1250 g) and the rate is
///                per paka seer. Example: 5 kg on the scale = 4 paka seer.
/// The 1250 lives ONLY here. Change it here if the shops use a different cut.
enum PriceUnit {
  kg(1000),
  pakaSeer(1250);

  const PriceUnit(this.gramsPerUnit);

  final int gramsPerUnit;

  static PriceUnit fromString(String? v) =>
      v == 'pakaSeer' ? PriceUnit.pakaSeer : PriceUnit.kg;
}

/// Money = whole rupees, weight = whole grams (integers), so totals built from
/// increments never drift.
int computeAmount(int weightGrams, double rate, [PriceUnit unit = PriceUnit.kg]) =>
    (weightGrams * rate / unit.gramsPerUnit).round();

/// Named ScrapMaterial because Flutter already has a `Material` widget.
class ScrapMaterial {
  const ScrapMaterial({
    required this.id,
    required this.name,
    required this.rateKg,
    required this.ratePakaSeer,
    required this.priceUnit,
    required this.isActive,
  });

  final String id;
  final String name;

  /// Fixed rate in Rs per kg (0 = not set).
  final double rateKg;

  /// Fixed rate in Rs per paka seer (0 = not set).
  final double ratePakaSeer;

  /// Which unit is pre-selected when this material is added to a slip.
  final PriceUnit priceUnit;
  final bool isActive;

  double rateFor(PriceUnit unit) => unit == PriceUnit.pakaSeer ? ratePakaSeer : rateKg;

  /// Rate of the default unit.
  double get rate => rateFor(priceUnit);

  factory ScrapMaterial.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final unit = PriceUnit.fromString(m['priceUnit'] as String?);
    // Older docs only have one `rate` (ratePerKg = even older name) for [unit].
    final legacy = ((m['rate'] ?? m['ratePerKg']) as num?)?.toDouble() ?? 0;
    return ScrapMaterial(
      id: d.id,
      name: m['name'] as String? ?? '',
      rateKg: (m['rateKg'] as num?)?.toDouble() ?? (unit == PriceUnit.kg ? legacy : 0),
      ratePakaSeer:
          (m['ratePakaSeer'] as num?)?.toDouble() ?? (unit == PriceUnit.pakaSeer ? legacy : 0),
      priceUnit: unit,
      isActive: m['isActive'] as bool? ?? true,
    );
  }
}

/// One line on a purchase slip.
class PurchaseItem {
  const PurchaseItem({
    required this.materialId,
    required this.materialName,
    required this.weightGrams,
    required this.unit,
    required this.rate,
    required this.amount,
  });

  final String materialId;
  final String materialName;

  /// Weight on the scale (kacha), in grams.
  final int weightGrams;
  final PriceUnit unit;
  final double rate;
  final int amount;

  Map<String, Object?> toMap() => {
        'materialId': materialId,
        'materialName': materialName, // copied so later renames don't rewrite history
        'weightGrams': weightGrams,
        'unit': unit.name,
        'rate': rate,
        'amount': amount,
      };

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
        materialId: m['materialId'] as String? ?? '',
        materialName: m['materialName'] as String? ?? '',
        weightGrams: (m['weightGrams'] as num?)?.toInt() ?? 0,
        unit: PriceUnit.fromString(m['unit'] as String?),
        rate: ((m['rate'] ?? m['ratePerKg']) as num?)?.toDouble() ?? 0,
        amount: (m['amount'] as num?)?.toInt() ?? 0,
      );

  /// "12.5 kg × Rs 40"  or  "5 kg → 4 paka seer × Rs 200"
  String get detail => unit == PriceUnit.pakaSeer
      ? '${formatKg(weightGrams)} → ${formatSeer(weightGrams)} × ${formatRate(rate)}'
      : '${formatKg(weightGrams)} × ${formatRate(rate)}';
}

/// A purchase slip: one customer, one or more items, one total.
class Purchase {
  const Purchase({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.totalWeightGrams,
    required this.sellerName,
    required this.dayKey,
    required this.createdAt,
    required this.pendingSync,
  });

  final String id;
  final List<PurchaseItem> items;
  final int totalAmount;
  final int totalWeightGrams;
  final String sellerName;
  final String dayKey;
  final DateTime createdAt;

  /// True while this slip exists only on the phone (not yet confirmed by server).
  final bool pendingSync;

  String get title {
    final names = items.map((i) => i.materialName).toList();
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  factory Purchase.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final raw = m['items'];
    final List<PurchaseItem> items;
    if (raw is List && raw.isNotEmpty) {
      items = raw
          .whereType<Map>()
          .map((e) => PurchaseItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      // Older single-material entries (before slips existed).
      items = [PurchaseItem.fromMap(m)];
    }
    return Purchase(
      id: d.id,
      items: items,
      totalAmount: ((m['totalAmount'] ?? m['amount']) as num?)?.toInt() ?? 0,
      totalWeightGrams:
          ((m['totalWeightGrams'] ?? m['weightGrams']) as num?)?.toInt() ?? 0,
      sellerName: m['sellerName'] as String? ?? '',
      dayKey: m['dayKey'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pendingSync: d.metadata.hasPendingWrites,
    );
  }
}

class DailySummary {
  const DailySummary({
    required this.totalAmount,
    required this.totalWeightGrams,
    required this.entryCount,
  });

  const DailySummary.empty() : this(totalAmount: 0, totalWeightGrams: 0, entryCount: 0);

  final int totalAmount;
  final int totalWeightGrams;

  /// Number of slips.
  final int entryCount;

  factory DailySummary.fromMap(Map<String, dynamic>? m) => m == null
      ? const DailySummary.empty()
      : DailySummary(
          totalAmount: (m['totalAmount'] as num?)?.toInt() ?? 0,
          totalWeightGrams: (m['totalWeightGrams'] as num?)?.toInt() ?? 0,
          entryCount: (m['entryCount'] as num?)?.toInt() ?? 0,
        );
}

class StockItem {
  const StockItem({
    required this.materialId,
    required this.materialName,
    required this.weightGrams,
  });

  final String materialId;
  final String materialName;
  final int weightGrams;

  factory StockItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return StockItem(
      materialId: d.id,
      materialName: m['materialName'] as String? ?? '',
      weightGrams: (m['weightGrams'] as num?)?.toInt() ?? 0,
    );
  }
}
