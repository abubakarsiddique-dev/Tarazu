import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../inventory/application/inventory_providers.dart' show shopIdProvider;
import '../data/staff_repository.dart';

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(ref.watch(firestoreProvider)),
);

/// Only the owner can read the munshi list (rules enforce this too).
final staffListProvider = StreamProvider<List<AppUser>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  final isOwner = ref.watch(isOwnerProvider);
  if (shopId == null || !isOwner) return Stream.value(const <AppUser>[]);
  return ref.watch(staffRepositoryProvider).watchStaff(shopId);
});
