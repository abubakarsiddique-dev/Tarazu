import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/app_user.dart';

/// The only place that talks to FirebaseAuth / Firestore for auth + profile.
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Emits the locally restored user on app start, even when offline.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Stream<AppUser?> watchProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      return (snap.exists && data != null) ? AppUser.fromMap(snap.id, data) : null;
    });
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> register({
    required String ownerName,
    required String shopName,
    String phone = '',
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;

    try {
      final shopRef = _db.collection('shops').doc();
      final userRef = _db.collection('users').doc(user.uid);

      // One atomic batch: both documents are written, or neither.
      final batch = _db.batch()
        ..set(shopRef, {
          'ownerUid': user.uid,
          'name': shopName.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..set(userRef, {
          'uid': user.uid,
          'ownerName': ownerName.trim(),
          'shopName': shopName.trim(),
          'phone': phone.trim(),
          'email': email.trim().toLowerCase(),
          'role': UserRole.owner.name,
          'shopId': shopRef.id,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

      // commit() only completes once the SERVER confirms. If the connection
      // drops right now it would hang, so we cap the wait.
      await batch.commit().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // Write is queued in the local Firestore cache and will sync later.
      // Do NOT delete the Auth user here, the queued write still needs it.
    } catch (_) {
      // Server rejected the write (rules, quota, ...). Roll back the Auth user
      // so the person can retry cleanly instead of being stuck half-registered.
      await _rollbackUser(user);
      rethrow;
    }
  }

  /// Offline-first: the write is not awaited (it completes only when the server
  /// confirms). The local cache updates at once and syncs later.
  void updatePhone(String uid, String phone) {
    _db.collection('users').doc(uid).update({'phone': phone.trim()}).catchError((Object e) {
      debugPrint('Phone update failed: $e');
    });
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  Future<void> _rollbackUser(User user) async {
    try {
      await user.delete();
    } catch (_) {
      await _auth.signOut();
    }
  }
}
