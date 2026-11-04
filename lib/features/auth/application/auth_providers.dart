
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)),
);

/// Firebase session. Restored from local storage, so it works offline.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// users/{uid} document of the signed-in user (null if signed out / missing).
/// Served from the Firestore local cache when offline.
final userProfileProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(user.uid);
});

/// True while register() is running, so the router does not react to the
/// half-finished state (Auth user exists, Firestore docs not written yet).
class RegistrationFlag extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final registrationInProgressProvider =
    NotifierProvider<RegistrationFlag, bool>(RegistrationFlag.new);

/// Runs login / register / reset / logout and exposes loading + error state.
/// Intentionally NOT autoDispose: after a successful login the router leaves the
/// screen immediately, and a disposed notifier cannot receive its final state.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signIn(email, password));
  }

  Future<void> register({
    required String ownerName,
    required String shopName,
    String phone = '',
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    ref.read(registrationInProgressProvider.notifier).set(true);
    try {
      state = await AsyncValue.guard(() => _repo.register(
            ownerName: ownerName,
            shopName: shopName,
            phone: phone,
            email: email,
            password: password,
          ));
    } finally {
      ref.read(registrationInProgressProvider.notifier).set(false);
    }
  }

  /// Returns true on success so the screen can show a confirmation.
  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.sendPasswordReset(email));
    return !state.hasError;
  }

  Future<void> signOut() async {
    state = await AsyncValue.guard(() => _repo.signOut());
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
