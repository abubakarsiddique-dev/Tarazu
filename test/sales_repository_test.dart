// Needs:  flutter pub add --dev fake_cloud_firestore   (already added in Phase 1)
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/core/utils/format.dart';
import 'package:tarazu/features/inventory/data/inventory_repository.dart';
import 'package:tarazu/features/inventory/domain/models.dart';
import 'package:tarazu/features/inventory/domain/sale_models.dart';

const _bought = PurchaseItem(
  materialId: 'iron', materialName: 'Iron', weightGrams: 20000,
  unit: PriceUnit.kg, rate: 40, amount: 800,
);

const _sold = SaleItem(
  materialId: 'iron', materialName: 'Iron', weightGrams: 15000,
  ratePerKg: 55, amount: 825,
);

void main() {
  late FakeFirebaseFirestore db;
  late InventoryRepository repo;
  final today = dayKey(DateTime.now());

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = InventoryRepository(db);
    repo.addSlip(shopId: 's1', uid: 'u1', sellerName: '', items: [_bought]); // 20 kg in stock
    await settle();
  });

  Future<Map<String, dynamic>?> salesDaily() async =>
      (await db.doc('shops/s1/salesDaily/$today').get()).data();

  Future<int> stockOf(String id) async =>
      (await db.doc('shops/s1/stock/$id').get()).data()!['weightGrams'] as int;

  group('addSale', () {
    test('writes the sale, the sales totals and takes the weight out of stock', () async {
      repo.addSale(shopId: 's1', uid: 'u1', buyerName: '  Khan Traders ', items: [_sold]);
      await settle();

      final sales = await db.collection('shops/s1/sales').get();
      expect(sales.docs.length, 1);
      final s = sales.docs.single.data();
      expect(s['totalAmount'], 825);
      expect(s['totalWeightGrams'], 15000);
      expect(s['buyerName'], 'Khan Traders'); // trimmed
      expect(s['isVoided'], false);

      final d = (await salesDaily())!;
      expect(d['totalAmount'], 825);
      expect(d['entryCount'], 1);
      expect(await stockOf('iron'), 5000);
    });

    test('does not touch the purchase totals', () async {
      repo.addSale(shopId: 's1', uid: 'u1', buyerName: '', items: [_sold]);
      await settle();

      final bought = (await db.doc('shops/s1/daily/$today').get()).data()!;
      expect(bought['totalAmount'], 800); // still just the purchase
      expect(bought['entryCount'], 1);
    });

    test('an empty sale writes nothing', () async {
      repo.addSale(shopId: 's1', uid: 'u1', buyerName: '', items: const []);
      await settle();
      expect((await db.collection('shops/s1/sales').get()).docs, isEmpty);
      expect(await stockOf('iron'), 20000);
    });
  });

  group('voidSale', () {
    Future<Sale> oneSale() async {
      repo.addSale(shopId: 's1', uid: 'u1', buyerName: '', items: [_sold]);
      await settle();
      final snap = await db.collection('shops/s1/sales').get();
      return Sale.fromDoc(snap.docs.single);
    }

    test('puts the weight back and reverses the sales totals, keeps the record', () async {
      final sale = await oneSale();

      repo.voidSale('s1', sale);
      await settle();

      expect(await stockOf('iron'), 20000);
      final d = (await salesDaily())!;
      expect(d['totalAmount'], 0);
      expect(d['totalWeightGrams'], 0);
      expect(d['entryCount'], 0);

      final doc = await db.doc('shops/s1/sales/${sale.id}').get();
      expect(doc.exists, isTrue); // audit trail kept
      expect(doc.data()!['isVoided'], true);
    });

    test('a cancelled sale disappears from today\'s list', () async {
      final sale = await oneSale();
      repo.voidSale('s1', sale);
      await settle();
      expect(await repo.watchSales('s1', today).first, isEmpty);
    });
  });

  group('adjustStock', () {
    test('removing weight lowers stock and leaves a permanent record', () async {
      repo.adjustStock(
        shopId: 's1', uid: 'u1', materialId: 'iron', materialName: 'Iron',
        deltaGrams: -2000, reason: AdjustmentReason.loss, note: '  rusted ',
      );
      await settle();

      expect(await stockOf('iron'), 18000);
      final rec = (await db.collection('shops/s1/adjustments').get()).docs.single.data();
      expect(rec['deltaGrams'], -2000);
      expect(rec['reason'], 'loss');
      expect(rec['note'], 'rusted'); // trimmed
      expect(rec['createdBy'], 'u1');
    });

    test('adding weight raises stock, even for a material with no stock yet', () async {
      repo.adjustStock(
        shopId: 's1', uid: 'u1', materialId: 'copper', materialName: 'Copper',
        deltaGrams: 4000, reason: AdjustmentReason.correction,
      );
      await settle();
      expect(await stockOf('copper'), 4000);
    });

    test('a zero adjustment writes nothing', () async {
      repo.adjustStock(
        shopId: 's1', uid: 'u1', materialId: 'iron', materialName: 'Iron',
        deltaGrams: 0, reason: AdjustmentReason.other,
      );
      await settle();
      expect((await db.collection('shops/s1/adjustments').get()).docs, isEmpty);
      expect(await stockOf('iron'), 20000);
    });
  });
}

// The repository does not await its writes (offline-first), so let them finish.
Future<void> settle() => Future<void>.delayed(Duration.zero);
