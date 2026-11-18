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
    test('piece pricing: 5 pieces at Rs 120 = Rs 600 and whole number parsing', () {
      expect(parsePositiveInt('5'), 5);
      expect(parsePositiveInt('1'), 1);
      expect(parsePositiveInt('0'), isNull);
      expect(parsePositiveInt('-3'), isNull);
      expect(parsePositiveInt('2.5'), isNull);
      expect(parsePositiveInt('2,5'), isNull);
      expect(formatPcs(5000), '5 pcs');
      expect(computeAmount(5000, 120, PriceUnit.piece), 600);
    });
  });

  group('PurchaseItem', () {
    test('detail text for kg, paka seer and piece lines', () {
      const kg = PurchaseItem(
        materialId: 'a', materialName: 'Iron', weightGrams: 12500,
        unit: PriceUnit.kg, rate: 40, amount: 500,
      );
      const seer = PurchaseItem(
        materialId: 'b', materialName: 'Bones', weightGrams: 5000,
        unit: PriceUnit.pakaSeer, rate: 200, amount: 800,
      );
      const pc = PurchaseItem(
        materialId: 'c', materialName: 'Oil Can', weightGrams: 5000,
        unit: PriceUnit.piece, rate: 120, amount: 600,
      );
      expect(kg.detail, '12.5 kg × Rs 40');
      expect(seer.detail, '5 kg → 4 paka seer × Rs 200');
      expect(pc.detail, '5 pcs × Rs 120');
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
