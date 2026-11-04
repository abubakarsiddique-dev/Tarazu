import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/inventory_repository.dart';
import '../domain/models.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.watch(firestoreProvider)),
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
}

final inventoryActionsProvider = Provider<InventoryActions>((ref) => InventoryActions(ref));
