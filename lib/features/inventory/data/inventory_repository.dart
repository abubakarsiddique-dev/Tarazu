import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/models.dart';

/// Offline-first rules used here:
///  * Writes are NOT awaited. Firestore's future only completes when the SERVER
///    confirms, which never happens without internet. The local cache updates
///    immediately and all listeners fire, so the UI is instant.
///  * Totals and stock are kept with FieldValue.increment inside the same batch
///    as the slip. Increments work offline and merge correctly on sync.
class InventoryRepository {
  InventoryRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _shop(String shopId) =>
      _db.collection('shops').doc(shopId);

  void _send(Future<void> write) {
    write.catchError((Object e, StackTrace s) {
      debugPrint('Firestore write failed: $e');
    });
  }

  // ---------- reads ----------

  Stream<List<ScrapMaterial>> watchMaterials(String shopId) {
    return _shop(shopId).collection('materials').snapshots().map((snap) {
      final list = snap.docs.map(ScrapMaterial.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Single-field filter only, so no composite index is needed.
  Stream<List<Purchase>> watchPurchases(String shopId, String day) {
    return _shop(shopId)
        .collection('purchases')
        .where('dayKey', isEqualTo: day)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final list = snap.docs
          .where((d) => (d.data()['isVoided'] as bool? ?? false) == false)
          .map(Purchase.fromDoc)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Slips from [fromDay] to [toDay] (inclusive, "yyyy-MM-dd" keys sort by date).
  /// Range filter on ONE field, so no composite index is needed.
  Stream<List<Purchase>> watchPurchasesRange(String shopId, String fromDay, String toDay) {
    return _shop(shopId)
        .collection('purchases')
        .where('dayKey', isGreaterThanOrEqualTo: fromDay)
        .where('dayKey', isLessThanOrEqualTo: toDay)
        .snapshots()
        .map((snap) => snap.docs
            .where((d) => (d.data()['isVoided'] as bool? ?? false) == false)
            .map(Purchase.fromDoc)
            .toList());
  }

  Stream<DailySummary> watchDaily(String shopId, String day) {
    return _shop(shopId)
        .collection('daily')
        .doc(day)
        .snapshots()
        .map((s) => DailySummary.fromMap(s.data()));
  }

  Stream<List<StockItem>> watchStock(String shopId) {
    return _shop(shopId).collection('stock').snapshots().map((snap) {
      final list = snap.docs.map(StockItem.fromDoc).toList()
        ..sort((a, b) => a.materialName.toLowerCase().compareTo(b.materialName.toLowerCase()));
      return list;
    });
  }

  // ---------- materials ----------

  void addMaterial(
    String shopId,
    String name,
    double rateKg,
    double ratePakaSeer,
    PriceUnit unit,
  ) {
    _send(_shop(shopId).collection('materials').doc().set({
      'name': name.trim(),
      'rateKg': rateKg,
      'ratePakaSeer': ratePakaSeer,
      // `rate` = rate of the default unit (kept for older app versions).
      'rate': unit == PriceUnit.pakaSeer ? ratePakaSeer : rateKg,
      'priceUnit': unit.name,
      'isActive': true,
      'createdAt': Timestamp.now(),
    }));
  }

  void updateMaterial(
    String shopId,
    String id, {
    String? name,
    double? rateKg,
    double? ratePakaSeer,
    PriceUnit? priceUnit,
    bool? isActive,
  }) {
    final data = <String, Object?>{
      'name': ?name?.trim(),
      'rateKg': ?rateKg,
      'ratePakaSeer': ?ratePakaSeer,
      'priceUnit': ?priceUnit?.name,
      'isActive': ?isActive,
    };
    if (rateKg != null && ratePakaSeer != null && priceUnit != null) {
      data['rate'] = priceUnit == PriceUnit.pakaSeer ? ratePakaSeer : rateKg;
    }
    if (data.isEmpty) return;
    _send(_shop(shopId).collection('materials').doc(id).update(data));
  }

  void seedMaterials(String shopId, List<String> names) {
    final batch = _db.batch();
    for (final name in names) {
      batch.set(_shop(shopId).collection('materials').doc(), {
        'name': name,
        'rate': 0,
        'rateKg': 0,
        'ratePakaSeer': 0,
        'priceUnit': PriceUnit.kg.name,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });
    }
    _send(batch.commit());
  }

  // ---------- slips ----------

  /// Weight per material (the same material may appear on two lines).
  Map<String, ({String name, int grams})> _stockDeltas(List<PurchaseItem> items) {
    final out = <String, ({String name, int grams})>{};
    for (final i in items) {
      final prev = out[i.materialId];
      out[i.materialId] = (name: i.materialName, grams: (prev?.grams ?? 0) + i.weightGrams);
    }
    return out;
  }

  void addSlip({
    required String shopId,
    required String uid,
    required String sellerName,
    required List<PurchaseItem> items,
  }) {
    if (items.isEmpty) return;
    final now = DateTime.now();
    final day = dayKey(now);
    final totalAmount = items.fold<int>(0, (s, i) => s + i.amount);
    final totalGrams = items.fold<int>(0, (s, i) => s + i.weightGrams);
    final shop = _shop(shopId);

    final batch = _db.batch()
      ..set(shop.collection('purchases').doc(), {
        'items': items.map((i) => i.toMap()).toList(),
        'totalAmount': totalAmount,
        'totalWeightGrams': totalGrams,
        'sellerName': sellerName.trim(),
        'dayKey': day,
        'createdAt': Timestamp.fromDate(now),
        'createdBy': uid,
        'isVoided': false,
      })
      ..set(
        shop.collection('daily').doc(day),
        {
          'totalAmount': FieldValue.increment(totalAmount),
          'totalWeightGrams': FieldValue.increment(totalGrams),
          'entryCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

    // Stock = what is physically on the scale, per material.
    _stockDeltas(items).forEach((materialId, d) {
      batch.set(
        shop.collection('stock').doc(materialId),
        {'materialName': d.name, 'weightGrams': FieldValue.increment(d.grams)},
        SetOptions(merge: true),
      );
    });
    _send(batch.commit());
  }

  /// Cancelling keeps the record (audit trail) and reverses totals and stock.
  void voidPurchase(String shopId, Purchase p) {
    final shop = _shop(shopId);
    final batch = _db.batch()
      ..update(shop.collection('purchases').doc(p.id), {
        'isVoided': true,
        'voidedAt': Timestamp.now(),
      })
      ..set(
        shop.collection('daily').doc(p.dayKey),
        {
          'totalAmount': FieldValue.increment(-p.totalAmount),
          'totalWeightGrams': FieldValue.increment(-p.totalWeightGrams),
          'entryCount': FieldValue.increment(-1),
        },
        SetOptions(merge: true),
      );
    _stockDeltas(p.items).forEach((materialId, d) {
      batch.set(
        shop.collection('stock').doc(materialId),
        {'weightGrams': FieldValue.increment(-d.grams)},
        SetOptions(merge: true),
      );
    });
    _send(batch.commit());
  }
}
