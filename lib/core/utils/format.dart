String _trim(double v) => v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

/// 12500 grams -> "12.5 kg"
String formatKg(int grams) => '${_trim(grams / 1000)} kg';

/// 5000 grams -> "4 paka seer" (1 paka seer = 1250 g)
String formatSeer(int grams) => '${_trim(grams / 1250)} paka seer';

/// 5000 internal units -> "5 pcs" (1 piece = 1000 internal units)
String formatPcs(int grams) => '${(grams / 1000).round()} pcs';

/// Parses a strictly positive whole integer ("1", "2", "15").
/// Rejects decimals ("1.5", "2,5"), zero, and negative numbers.
int? parsePositiveInt(String? text) {
  final s = (text ?? '').trim();
  if (!RegExp(r'^\d+$').hasMatch(s)) return null;
  final n = int.tryParse(s);
  return (n == null || n <= 0) ? null : n;
}

/// 1234567 -> "Rs 1,234,567"
String formatRs(int value) {
  final s = value.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'Rs ${value < 0 ? '-' : ''}$b';
}

/// Rates can have decimals: 40 -> "Rs 40", 42.5 -> "Rs 42.5"
String formatRate(double rate) =>
    rate == rate.roundToDouble() ? formatRs(rate.round()) : 'Rs $rate';

/// Accepts "12.5" and "12,5".
double? parseNumber(String? text) =>
    double.tryParse((text ?? '').trim().replaceAll(',', '.'));

/// 14:05
String formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
