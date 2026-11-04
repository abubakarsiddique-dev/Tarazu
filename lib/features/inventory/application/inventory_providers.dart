import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/write_failures.dart';
import '../../auth/application/auth_providers.dart';
import '../data/inventory_repository.dart';
import '../domain/models.dart';
import '../domain/sale_models.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(
    ref.watch(firestoreProvider),
    // Tell the user when the server rejects a write that looked saved.
    onWriteError: ref.read(writeFailureProvider.notifier).report,
  ),
);

/// The signed-in owner's shop. Null only while signed out.
final shopIdProvider = Provider<String?>((ref) {
  final id = ref.watch(userProfileProvider).value?.shopId;
  return (id == null || id.isEmpty) ? null : id;
});

final materialsProvider = StreamProvider<List<ScrapMaterial>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const <ScrapMaterial>[]);
  return ref.watch(inventoryRepositoryProvider).watchMaterials(shopId);
});

final purchasesForDayProvider = StreamProvider.family<List<Purchase>, String>((ref, day) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const <Purchase>[]);
  return ref.watch(inventoryRepositoryProvider).watchPurchases(shopId, day);
});

/// Slips between two day keys (inclusive). Used by the History screen.
final purchasesRangeProvider =
    StreamProvider.family<List<Purchase>, ({String from, String to})>((ref, range) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const <Purchase>[]);
  return ref.watch(inventoryRepositoryProvider).watchPurchasesRange(shopId, range.from, range.to);
});

final dailySummaryProvider = StreamProvider.family<DailySummary, String>((ref, day) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const DailySummary.empty());
  return ref.watch(inventoryRepositoryProvider).watchDaily(shopId, day);
});

final stockProvider = StreamProvider<List<StockItem>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const <StockItem>[]);
  return ref.watch(inventoryRepositoryProvider).watchStock(shopId);
});

final salesForDayProvider = StreamProvider.family<List<Sale>, String>((ref, day) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const <Sale>[]);
  return ref.watch(inventoryRepositoryProvider).watchSales(shopId, day);
});

final salesDailyProvider = StreamProvider.family<DailySummary, String>((ref, day) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const DailySummary.empty());
  return ref.watch(inventoryRepositoryProvider).watchSalesDaily(shopId, day);
});

/// Thin facade so screens never deal with shopId / uid.
class InventoryActions {
  InventoryActions(this._ref);

  final Ref _ref;

  InventoryRepository get _repo => _ref.read(inventoryRepositoryProvider);

  String get _shopId {
    final id = _ref.read(shopIdProvider);
    if (id == null) throw StateError('No shop for the current user');
    return id;
  }

  String get _uid => _ref.read(firebaseAuthProvider).currentUser!.uid;

  static const commonMaterials = [
    'Iron', 'Steel', 'Cardboard', 'Paper', 'Plastic', 'Aluminium', 'Copper', 'Brass',
  ];

  void addMaterial(String name, double rateKg, double ratePakaSeer, PriceUnit unit) =>
      _repo.addMaterial(_shopId, name, rateKg, ratePakaSeer, unit);

  void updateMaterial(
    String id, {
    String? name,
    double? rateKg,
    double? ratePakaSeer,
    PriceUnit? priceUnit,
    bool? isActive,
  }) =>
      _repo.updateMaterial(_shopId, id,
          name: name,
          rateKg: rateKg,
          ratePakaSeer: ratePakaSeer,
          priceUnit: priceUnit,
          isActive: isActive);

  void seedCommonMaterials() => _repo.seedMaterials(_shopId, commonMaterials);

  void addSlip({required List<PurchaseItem> items, String sellerName = ''}) =>
      _repo.addSlip(shopId: _shopId, uid: _uid, sellerName: sellerName, items: items);

  void voidPurchase(Purchase p) => _repo.voidPurchase(_shopId, p);

  void addSale({required List<SaleItem> items, String buyerName = ''}) =>
      _repo.addSale(shopId: _shopId, uid: _uid, buyerName: buyerName, items: items);

  void voidSale(Sale s) => _repo.voidSale(_shopId, s);

  void adjustStock({
    required String materialId,
    required String materialName,
    required int deltaGrams,
    required AdjustmentReason reason,
    String note = '',
  }) =>
      _repo.adjustStock(
        shopId: _shopId,
        uid: _uid,
        materialId: materialId,
        materialName: materialName,
        deltaGrams: deltaGrams,
        reason: reason,
        note: note,
      );
}

final inventoryActionsProvider = Provider<InventoryActions>((ref) => InventoryActions(ref));
