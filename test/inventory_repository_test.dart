
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/features/inventory/data/inventory_repository.dart';
import 'package:tarazu/features/inventory/domain/models.dart';

const _iron1 = PurchaseItem(
  materialId: 'iron', materialName: 'Iron', weightGrams: 12500,
  unit: PriceUnit.kg, rate: 40, amount: 500,
);
const _iron2 = PurchaseItem(
  materialId: 'iron', materialName: 'Iron', weightGrams: 2500,
  unit: PriceUnit.kg, rate: 40, amount: 100,
);
const _bones = PurchaseItem(
  materialId: 'bones', materialName: 'Bones', weightGrams: 5000,
  unit: PriceUnit.pakaSeer, rate: 200, amount: 800,
);

void main() {
  late FakeFirebaseFirestore db;
  late InventoryRepository repo;
  final today = dayKey(DateTime.now());

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = InventoryRepository(db);
  });

  // addSlip / voidPurchase are fire-and-forget, so let the batch finish first.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<Map<String, dynamic>?> daily() async =>
      (await db.doc('shops/s1/daily/$today').get()).data();

  Future<int> stockOf(String id) async =>
      (await db.doc('shops/s1/stock/$id').get()).data()!['weightGrams'] as int;

  group('addSlip', () {
    test('writes the slip, the day totals and the stock together', () async {
      repo.addSlip(shopId: 's1', uid: 'u1', sellerName: '  Bilal ', items: [_iron1, _iron2, _bones]);
      await settle();

      final slips = await db.collection('shops/s1/purchases').get();
      expect(slips.docs.length, 1);
      final slip = slips.docs.single.data();
      expect(slip['totalAmount'], 1400);
      expect(slip['totalWeightGrams'], 20000);
      expect(slip['sellerName'], 'Bilal'); // trimmed
      expect(slip['isVoided'], false);
      expect(slip['createdBy'], 'u1');

      final d = (await daily())!;
      expect(d['totalAmount'], 1400);
      expect(d['totalWeightGrams'], 20000);
      expect(d['entryCount'], 1);
    });

    test('same material on two lines is summed into one stock entry', () async {
      repo.addSlip(shopId: 's1', uid: 'u1', sellerName: '', items: [_iron1, _iron2, _bones]);
      await settle();

      expect(await stockOf('iron'), 15000);
      expect(await stockOf('bones'), 5000);
    });

    test('a second slip adds to the totals', () async {
      repo.addSlip(shopId: 's1', uid: 'u1', sellerName: '', items: [_iron1]);
      repo.addSlip(shopId: 's1', uid: 'u1', sellerName: '', items: [_iron2]);
      await settle();

      final d = (await daily())!;
      expect(d['totalAmount'], 600);
      expect(d['entryCount'], 2);
      expect(await stockOf('iron'), 15000);
    });

    test('an empty slip writes nothing', () async {
      repo.addSlip(shopId: 's1', uid: 'u1', sellerName: '', items: const []);
      await settle();

      expect((await db.collection('shops/s1/purchases').get()).docs, isEmpty);
      expect(await daily(), isNull);
    });
  });

  group('voidPurchase', () {
    Future<Purchase> saveOneSlip() async {
      repo.addSlip(shopId: 's1', uid: 'u1', sellerName: '', items: [_iron1, _bones]);
      await settle();
      final snap = await db.collection('shops/s1/purchases').get();
      return Purchase.fromDoc(snap.docs.single);
    }

    test('reverses day totals and stock, keeps the record', () async {
      final slip = await saveOneSlip();

      repo.voidPurchase('s1', slip);
      await settle();

      final d = (await daily())!;
      expect(d['totalAmount'], 0);
      expect(d['totalWeightGrams'], 0);
      expect(d['entryCount'], 0);
      expect(await stockOf('iron'), 0);
      expect(await stockOf('bones'), 0);

      final doc = await db.doc('shops/s1/purchases/${slip.id}').get();
      expect(doc.exists, isTrue); // audit trail kept
      expect(doc.data()!['isVoided'], true);
      expect(doc.data()!['voidedAt'], isNotNull);
    });

    test('a voided slip disappears from today\'s list', () async {
      final slip = await saveOneSlip();
      repo.voidPurchase('s1', slip);
      await settle();

      final list = await repo.watchPurchases('s1', today).first;
      expect(list, isEmpty);
    });

    test('only the voided slip is reversed when there are two', () async {
      final first = await saveOneSlip();
      repo.addSlip(shopId: 's1', uid: 'u1', sellerName: '', items: [_iron2]);
      await settle();

      repo.voidPurchase('s1', first);
      await settle();

      final d = (await daily())!;
      expect(d['totalAmount'], 100);
      expect(d['entryCount'], 1);
      expect(await stockOf('iron'), 2500);
    });
  });
}
