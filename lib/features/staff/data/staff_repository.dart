import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../auth/domain/app_user.dart';

/// Owner-side management of munshi (staff) accounts.
///
/// Creating the login uses a SECOND FirebaseApp instance. If we called
/// createUserWithEmailAndPassword on the main FirebaseAuth, Firebase would sign
/// the owner out and sign the new munshi in.
class StaffRepository {
  StaffRepository(this._db);

  final FirebaseFirestore _db;

  static const _secondaryName = 'staffCreator';

  /// Munshis of this shop (the owner's own profile is filtered out).
  /// Single-field filter, so no composite index is needed.
  Stream<List<AppUser>> watchStaff(String shopId) {
    return _db
        .collection('users')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => AppUser.fromMap(d.id, d.data()))
          .where((u) => u.role == UserRole.staff)
          .toList()
        ..sort((a, b) => a.ownerName.toLowerCase().compareTo(b.ownerName.toLowerCase()));
      return list;
    });
  }

  Future<FirebaseApp> _secondaryApp() async {
    for (final a in Firebase.apps) {
      if (a.name == _secondaryName) return a;
    }
    return Firebase.initializeApp(name: _secondaryName, options: Firebase.app().options);
  }

  /// Needs internet (creating a login cannot work offline). Throws on failure,
  /// the caller shows the message.
  Future<void> createStaff({
    required String shopId,
    required String shopName,
    String shopPhone = '',
    required String name,
    required String email,
    required String password,
  }) async {
    final app = await _secondaryApp();
    final auth = FirebaseAuth.instanceFor(app: app);

    final cred = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;

    try {
      // Written by the OWNER (main Firestore instance, owner is still signed in).
      await _db
          .collection('users')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'ownerName': name.trim(), // for a munshi this is the munshi's own name
            'shopName': shopName,
            'phone': shopPhone, // shop phone, printed on the slips the munshi shares
            'email': email.trim().toLowerCase(),
            'role': UserRole.staff.name,
            'shopId': shopId,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // Connection dropped: the write is queued and will sync. Keep the login.
    } catch (_) {
      // Rejected by the server: remove the half-made login so it can be retried.
      try {
        await user.delete();
      } catch (e) {
        debugPrint('Could not roll back munshi login: $e');
      }
      rethrow;
    } finally {
      await auth.signOut();
    }
  }

  /// Offline-first like the other writes: not awaited.
  void setActive(String uid, bool active) {
    _db.collection('users').doc(uid).update({'isActive': active}).catchError((Object e) {
      debugPrint('Munshi on/off failed: $e');
    });
  }
}
