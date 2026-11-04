import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

// Relative imports so this works regardless of your package name.
import 'package:tarazu/core/constants/app_strings.dart';
import 'package:tarazu/core/router/app_router.dart';
import 'package:tarazu/core/router/session.dart';
import 'package:tarazu/core/utils/auth_error_mapper.dart';
import 'package:tarazu/core/utils/validators.dart';
import 'package:tarazu/features/auth/domain/app_user.dart';

AppUser _user({bool active = true}) => AppUser(
      uid: 'u1',
      ownerName: 'Ali',
      shopName: 'Ali Kabari',
      email: 'a@b.com',
      role: UserRole.owner,
      shopId: 's1',
      isActive: active,
    );

SessionStatus _compute({
  bool minTimeDone = true,
  bool authResolved = true,
  bool signedIn = false,
  bool onboardingSeen = false,
  bool registering = false,
  bool profileLoading = false,
  AppUser? profile,
}) =>
    computeSession(
      minTimeDone: minTimeDone,
      authResolved: authResolved,
      signedIn: signedIn,
      onboardingSeen: onboardingSeen,
      registering: registering,
      profileLoading: profileLoading,
      profile: profile,
    );

void main() {
  group('mapAuthError', () {
    test('network', () {
      expect(mapAuthError(FirebaseAuthException(code: 'network-request-failed')), AppStrings.errNetwork);
    });
    test('invalid-credential', () {
      expect(mapAuthError(FirebaseAuthException(code: 'invalid-credential')), AppStrings.errWrongCredentials);
    });
    test('email in use', () {
      expect(mapAuthError(FirebaseAuthException(code: 'email-already-in-use')), AppStrings.errEmailInUse);
    });
    test('unknown error', () {
      expect(mapAuthError(Exception('x')), AppStrings.errGeneric);
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email('a@b.com'), isNull);
      expect(Validators.email('abc'), AppStrings.emailInvalid);
    });
    test('password', () {
      expect(Validators.password('12345'), AppStrings.passwordShort);
      expect(Validators.password('123456'), isNull);
    });
    test('confirm', () {
      expect(Validators.confirmPassword('a', 'b'), AppStrings.passwordMismatch);
    });
  });

  group('computeSession (splash decision)', () {
    test('loading until min time and auth resolved', () {
      expect(_compute(minTimeDone: false), SessionStatus.loading);
      expect(_compute(authResolved: false), SessionStatus.loading);
    });
    test('first launch -> onboarding', () {
      expect(_compute(), SessionStatus.needsOnboarding);
    });
    test('onboarding done, signed out -> signedOut', () {
      expect(_compute(onboardingSeen: true), SessionStatus.signedOut);
    });
    test('signed in with active profile -> active', () {
      expect(_compute(signedIn: true, profile: _user()), SessionStatus.active);
    });
    test('inactive profile -> disabled', () {
      expect(_compute(signedIn: true, profile: _user(active: false)), SessionStatus.disabled);
    });
    test('signed in, no profile -> profileMissing', () {
      expect(_compute(signedIn: true), SessionStatus.profileMissing);
    });
    test('registering is not treated as missing profile', () {
      expect(_compute(signedIn: true, registering: true), SessionStatus.registering);
    });
  });

  group('redirectFor', () {
    test('signed out cannot open home', () {
      expect(redirectFor(SessionStatus.signedOut, Routes.home), Routes.login);
      expect(redirectFor(SessionStatus.signedOut, Routes.register), isNull);
    });
    test('active user is pushed away from login/onboarding', () {
      expect(redirectFor(SessionStatus.active, Routes.login), Routes.home);
      expect(redirectFor(SessionStatus.active, Routes.onboarding), Routes.home);
      expect(redirectFor(SessionStatus.active, Routes.home), isNull);
    });
    test('disabled user is locked to disabled screen', () {
      expect(redirectFor(SessionStatus.disabled, Routes.home), Routes.disabled);
    });
    test('first launch goes to onboarding', () {
      expect(redirectFor(SessionStatus.needsOnboarding, Routes.login), Routes.onboarding);
    });
  });
}
