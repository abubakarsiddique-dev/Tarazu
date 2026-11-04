import '../../../core/constants/app_strings.dart';
import '../../../core/utils/format.dart';
import 'models.dart';

/// Plain-text receipt for sharing (WhatsApp, SMS, ...). WhatsApp shows
/// *text* in bold. Pure function, so it is easy to unit test.
///
///   *Ali Kabari*
///   Tel: 0300-1234567
///
///   Purchase slip
///   Date: 2026-11-04  14:05
///   Seller: Bilal
///
///   1. Iron
///      12.5 kg × Rs 40 = Rs 500
///
///   *Total: Rs 500*
String slipShareText(Purchase p, {required String shopName, String shopPhone = ''}) {
  final b = StringBuffer();
  final name = shopName.trim();
  final phone = shopPhone.trim();

  if (name.isNotEmpty) b.writeln('*$name*');
  if (phone.isNotEmpty) b.writeln('${AppStrings.tel}: $phone');
  if (name.isNotEmpty || phone.isNotEmpty) b.writeln();

  b.writeln(AppStrings.slip);
  b.writeln('${AppStrings.date}: ${p.dayKey}  ${formatTime(p.createdAt)}');
  if (p.sellerName.trim().isNotEmpty) {
    b.writeln('${AppStrings.seller}: ${p.sellerName.trim()}');
  }
  b.writeln();

  for (var i = 0; i < p.items.length; i++) {
    final item = p.items[i];
    b.writeln('${i + 1}. ${item.materialName}');
    b.writeln('   ${item.detail} = ${formatRs(item.amount)}');
  }

  b.writeln();
  b.write('*${AppStrings.total}: ${formatRs(p.totalAmount)}*');
  return b.toString();
}
