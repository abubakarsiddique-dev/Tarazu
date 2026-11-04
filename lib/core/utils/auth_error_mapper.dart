import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_strings.dart';

/// Turns any thrown error into a short, user-friendly message.
String mapAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'network-request-failed':
        return AppStrings.errNetwork;
      // Newer Firebase SDKs return invalid-credential for both
      // "wrong password" and "no such user" (email enumeration protection).
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return AppStrings.errWrongCredentials;
      case 'email-already-in-use':
        return AppStrings.errEmailInUse;
      case 'weak-password':
        return AppStrings.errWeakPassword;
      case 'too-many-requests':
        return AppStrings.errTooMany;
      case 'user-disabled':
        return AppStrings.errUserDisabled;
      default:
        return AppStrings.errGeneric;
    }
  }
  if (error is FirebaseException && error.code == 'unavailable') {
    return AppStrings.errNetwork;
  }
  return AppStrings.errGeneric;
}
