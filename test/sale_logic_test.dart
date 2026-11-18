import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/features/inventory/domain/models.dart';
import 'package:tarazu/features/inventory/domain/sale_models.dart';

SaleItem _line(String id, int grams) => SaleItem(
      materialId: id,
      materialName: id,
      weightGrams: grams,
      ratePerKg: 50,
      amount: computeAmount(grams, 50),
    );

void main() {
  const stock = [
    StockItem(materialId: 'iron', materialName: 'Iron', weightGrams: 20000),
    StockItem(materialId: 'bones', materialName: 'Bones', weightGrams: 3000),
  ];

  group('remainingToSell', () {
    test('equals the stock when nothing is on the slip', () {
      expect(remainingToSell(stock, const [], 'iron'), 20000);
    });

    test('subtracts lines already on the slip, per material', () {
      final slip = [_line('iron', 12500), _line('bones', 1000)];
      expect(remainingToSell(stock, slip, 'iron'), 7500);
      expect(remainingToSell(stock, slip, 'bones'), 2000);
    });

    test('two lines of the same material both count', () {
      final slip = [_line('iron', 12500), _line('iron', 7500)];
      expect(remainingToSell(stock, slip, 'iron'), 0);
    });

    test('a material that is not in stock has nothing to sell', () {
      expect(remainingToSell(stock, const [], 'copper'), 0);
    });
  });

  group('SaleItem', () {
    test('survives a trip through a Firestore map', () {
      final original = _line('iron', 12500);
      final copy = SaleItem.fromMap(Map<String, dynamic>.from(original.toMap()));
      expect(copy.materialId, 'iron');
      expect(copy.weightGrams, 12500);
      expect(copy.ratePerKg, 50);
      expect(copy.amount, 625); // 12.5 kg * Rs 50
    });

    test('detail reads like the purchase lines (kg and piece)', () {
      expect(_line('iron', 12500).detail, '12.5 kg × Rs 50');
      const pcSale = SaleItem(
        materialId: 'can',
        materialName: 'Oil Can',
        weightGrams: 4000,
        ratePerKg: 150,
        amount: 600,
        unit: PriceUnit.piece,
      );
      expect(pcSale.detail, '4 pcs × Rs 150');
      final copy = SaleItem.fromMap(Map<String, dynamic>.from(pcSale.toMap()));
      expect(copy.unit, PriceUnit.piece);
      expect(copy.detail, '4 pcs × Rs 150');
    });
  });
}
