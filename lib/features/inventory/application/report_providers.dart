import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../domain/sale_models.dart';
import 'inventory_providers.dart' show shopIdProvider;

/// Non-voided sales between two day keys (inclusive).
/// Range filter on ONE field, so no composite index is needed.
final salesRangeProvider =
    StreamProvider.family<List<Sale>, ({String from, String to})>((ref, range) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const <Sale>[]);
  return ref
      .watch(firestoreProvider)
      .collection('shops')
      .doc(shopId)
      .collection('sales')
      .where('dayKey', isGreaterThanOrEqualTo: range.from)
      .where('dayKey', isLessThanOrEqualTo: range.to)
      .snapshots()
      .map((snap) => snap.docs
          .where((d) => (d.data()['isVoided'] as bool? ?? false) == false)
          .map(Sale.fromDoc)
          .toList());
});
