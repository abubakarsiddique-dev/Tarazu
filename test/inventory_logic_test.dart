import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/core/utils/format.dart';
import 'package:tarazu/features/inventory/domain/models.dart';

void main() {
  test('dayKey pads month and day', () {
    expect(dayKey(DateTime(2026, 3, 5)), '2026-03-05');
    expect(dayKey(DateTime(2026, 11, 4)), '2026-11-04');
  });

  group('computeAmount', () {
    test('12.5 kg at Rs 40 = Rs 500', () => expect(computeAmount(12500, 40), 500));
    test('rounds to whole rupees', () => expect(computeAmount(333, 45.5), 15)); // 15.1515
    test('zero weight is zero', () => expect(computeAmount(0, 40), 0));
  });

  group('formatKg', () {
    test('trims trailing zeros', () {
      expect(formatKg(12000), '12 kg');
      expect(formatKg(12500), '12.5 kg');
      expect(formatKg(100000), '100 kg');
      expect(formatKg(250), '0.25 kg');
      expect(formatKg(0), '0 kg');
    });
  });

  test('formatRs groups thousands', () {
    expect(formatRs(0), 'Rs 0');
    expect(formatRs(999), 'Rs 999');
    expect(formatRs(1234567), 'Rs 1,234,567');
  });

  test('parseNumber accepts comma and dot', () {
    expect(parseNumber('12,5'), 12.5);
    expect(parseNumber(' 7 '), 7);
    expect(parseNumber('abc'), isNull);
    expect(parseNumber(null), isNull);
  });
}
