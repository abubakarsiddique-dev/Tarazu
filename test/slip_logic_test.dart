import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/core/utils/format.dart';
import 'package:tarazu/features/inventory/domain/models.dart';

void main() {
  group('kacha -> paka seer', () {
    test('5 kg on scale = 4 paka seer', () {
      expect(formatSeer(5000), '4 paka seer');
    });
    test('amount is paid on paka seer, not on kg', () {
      // 5 kg -> 4 paka seer at Rs 200 per paka seer = Rs 800 (not 5 x 200)
      expect(computeAmount(5000, 200, PriceUnit.pakaSeer), 800);
    });
    test('fractions: 3 kg = 2.4 paka seer', () {
      expect(formatSeer(3000), '2.4 paka seer');
      expect(computeAmount(3000, 200, PriceUnit.pakaSeer), 480);
    });
    test('kg pricing is unchanged', () {
      expect(computeAmount(12500, 40), 500);
      expect(computeAmount(12500, 40, PriceUnit.kg), 500);
    });
  });

  group('PurchaseItem', () {
    test('detail text for kg and paka seer lines', () {
      const kg = PurchaseItem(
        materialId: 'a', materialName: 'Iron', weightGrams: 12500,
        unit: PriceUnit.kg, rate: 40, amount: 500,
      );
      const seer = PurchaseItem(
        materialId: 'b', materialName: 'Bones', weightGrams: 5000,
        unit: PriceUnit.pakaSeer, rate: 200, amount: 800,
      );
      expect(kg.detail, '12.5 kg × Rs 40');
      expect(seer.detail, '5 kg → 4 paka seer × Rs 200');
    });

    test('toMap / fromMap round trip', () {
      const item = PurchaseItem(
        materialId: 'b', materialName: 'Bones', weightGrams: 5000,
        unit: PriceUnit.pakaSeer, rate: 42.5, amount: 170,
      );
      final back = PurchaseItem.fromMap(Map<String, dynamic>.from(item.toMap()));
      expect(back.unit, PriceUnit.pakaSeer);
      expect(back.rate, 42.5);
      expect(back.amount, 170);
    });

    test('old docs with ratePerKg still load', () {
      final item = PurchaseItem.fromMap({
        'materialId': 'x', 'materialName': 'Iron', 'weightGrams': 1000,
        'ratePerKg': 30, 'amount': 30,
      });
      expect(item.rate, 30);
      expect(item.unit, PriceUnit.kg);
    });
  });

  test('formatRate keeps decimals only when needed', () {
    expect(formatRate(40), 'Rs 40');
    expect(formatRate(42.5), 'Rs 42.5');
  });
}
