import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/app_user.dart';
import 'staff_providers.dart';

/// uid -> munshi name. Only the owner's device fills this (staffListProvider is
/// empty on a munshi's phone), so a munshi never learns anybody's name.
final staffNamesProvider = Provider<Map<String, String>>((ref) {
  final list = ref.watch(staffListProvider).value ?? const <AppUser>[];
  return {for (final u in list) u.uid: u.ownerName};
});

/// Name of the munshi who created an entry, or null when the owner made it
/// (or when this is not the owner's device).
final staffNameProvider = Provider.family<String?, String>((ref, uid) {
  if (uid.isEmpty) return null;
  return ref.watch(staffNamesProvider)[uid];
});
