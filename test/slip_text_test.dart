import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/core/utils/validators.dart';
import 'package:tarazu/features/inventory/domain/models.dart';
import 'package:tarazu/features/inventory/domain/slip_text.dart';

Purchase _slip({String seller = ''}) => Purchase(
      id: 'p1',
      items: const [
        PurchaseItem(
          materialId: 'a', materialName: 'Iron', weightGrams: 12500,
          unit: PriceUnit.kg, rate: 40, amount: 500,
        ),
        PurchaseItem(
          materialId: 'b', materialName: 'Bones', weightGrams: 5000,
          unit: PriceUnit.pakaSeer, rate: 200, amount: 800,
        ),
      ],
      totalAmount: 1300,
      totalWeightGrams: 17500,
      sellerName: seller,
      dayKey: '2026-11-04',
      createdAt: DateTime(2026, 11, 4, 14, 5),
      pendingSync: false,
    );

void main() {
  test('slip text has shop name, phone, items and total', () {
    final t = slipShareText(_slip(seller: 'Bilal'), shopName: 'Ali Kabari', shopPhone: '0300-1234567');
    expect(t, startsWith('*Ali Kabari*\nTel: 0300-1234567\n\n'));
    expect(t, contains('Date: 2026-11-04  14:05'));
    expect(t, contains('Seller: Bilal'));
    expect(t, contains('1. Iron\n   12.5 kg × Rs 40 = Rs 500'));
    expect(t, contains('2. Bones\n   5 kg → 4 paka seer × Rs 200 = Rs 800'));
    expect(t, endsWith('*Total: Rs 1,300*'));
  });

  test('empty phone, seller and shop name are left out', () {
    final t = slipShareText(_slip(), shopName: 'Ali Kabari');
    expect(t, isNot(contains('Tel:')));
    expect(t, isNot(contains('Seller:')));
    final bare = slipShareText(_slip(), shopName: '');
    expect(bare, startsWith('Purchase slip'));
  });

  test('phone validator: optional, but must look like a number', () {
    expect(Validators.phoneOptional(''), isNull);
    expect(Validators.phoneOptional(null), isNull);
    expect(Validators.phoneOptional('0300-1234567'), isNull);
    expect(Validators.phoneOptional('+92 300 1234567'), isNull);
    expect(Validators.phoneOptional('abc'), isNotNull);
    expect(Validators.phoneOptional('123'), isNotNull);
  });
}
