import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/onboarding/application/onboarding_provider.dart';

enum SessionStatus {
  loading,
  registering,
  needsOnboarding,
  signedOut,
  active,
  disabled,
  profileMissing,
}

/// Pure function = easy to unit test, no Firebase needed.
/// Decides everything from LOCAL state only (never waits on the network).
SessionStatus computeSession({
  required bool minTimeDone,
  required bool authResolved,
  required bool signedIn,
  required bool onboardingSeen,
  required bool registering,
  required bool profileLoading,
  required AppUser? profile,
}) {
  if (!minTimeDone || !authResolved) return SessionStatus.loading;
  if (registering) return SessionStatus.registering;
  if (!signedIn) {
    return onboardingSeen ? SessionStatus.signedOut : SessionStatus.needsOnboarding;
  }
  if (profileLoading) return SessionStatus.loading;
  if (profile == null) return SessionStatus.profileMissing;
  return profile.isActive ? SessionStatus.active : SessionStatus.disabled;
}

/// Keeps the splash visible for a minimum time so it does not flash.
final splashMinTimeProvider = FutureProvider<bool>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  return true;
});

final sessionStatusProvider = Provider<SessionStatus>((ref) {
  final auth = ref.watch(authStateProvider);
  final signedIn = auth.value != null;
  final profile = signedIn ? ref.watch(userProfileProvider) : null;

  return computeSession(
    minTimeDone: ref.watch(splashMinTimeProvider).hasValue,
    authResolved: auth.hasValue || auth.hasError,
    signedIn: signedIn,
    onboardingSeen: ref.watch(onboardingSeenProvider),
    registering: ref.watch(registrationInProgressProvider),
    profileLoading: profile?.isLoading ?? false,
    profile: profile?.value,
  );
});
