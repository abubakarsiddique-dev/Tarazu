import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/account_blocked_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/inventory/presentation/add_purchase_screen.dart';
import '../../features/inventory/presentation/history_screen.dart';
import '../../features/inventory/presentation/materials_screen.dart';
import '../../features/inventory/presentation/new_sale_screen.dart';
import '../../features/inventory/presentation/sales_screen.dart';
import '../../features/inventory/presentation/stock_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../constants/app_strings.dart';
import 'session.dart';
import '../../features/inventory/presentation/report_screen.dart';

class Routes {
  Routes._();
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const addPurchase = '/purchases/new';
  static const materials = '/materials';
  static const stock = '/stock';
  static const history = '/history';
  static const newSale = '/sales/new';
  static const sales = '/sales';
  static const disabled = '/disabled';
  static const profileMissing = '/profile-missing';
  static const report = '/report';

}

const _publicAuthPages = [Routes.login, Routes.register, Routes.forgotPassword];
const _preAuthPages = [Routes.splash, Routes.onboarding, ..._publicAuthPages];

/// Redirect rules, extracted so they can be unit tested.
String? redirectFor(SessionStatus status, String location) {
  switch (status) {
    case SessionStatus.loading:
      return location == Routes.splash ? null : Routes.splash;
    case SessionStatus.registering:
      return null; // stay on the register screen while it finishes
    case SessionStatus.needsOnboarding:
      return location == Routes.onboarding ? null : Routes.onboarding;
    case SessionStatus.signedOut:
      return _publicAuthPages.contains(location) ? null : Routes.login;
    case SessionStatus.active:
      return _preAuthPages.contains(location) ? Routes.home : null;
    case SessionStatus.disabled:
      return location == Routes.disabled ? null : Routes.disabled;
    case SessionStatus.profileMissing:
      return location == Routes.profileMissing ? null : Routes.profileMissing;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod -> go_router: re-run redirect whenever session status changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionStatus>(sessionStatusProvider, (prev, next) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        redirectFor(ref.read(sessionStatusProvider), state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(path: Routes.addPurchase, builder: (_, _) => const AddPurchaseScreen()),
      GoRoute(path: Routes.materials, builder: (_, _) => const MaterialsScreen()),
      GoRoute(path: Routes.stock, builder: (_, _) => const StockScreen()),
      GoRoute(path: Routes.history, builder: (_, _) => const HistoryScreen()),
      GoRoute(path: Routes.newSale, builder: (_, _) => const NewSaleScreen()),
      GoRoute(path: Routes.sales, builder: (_, _) => const SalesScreen()),
      GoRoute(path: Routes.report, builder: (_, _) => const ReportScreen()),
      GoRoute(
        path: Routes.disabled,
        builder: (_, _) => const AccountBlockedScreen(
          title: AppStrings.disabledTitle,
          message: AppStrings.disabledBody,
        ),
      ),
      GoRoute(
        path: Routes.profileMissing,
        builder: (_, _) => const AccountBlockedScreen(
          title: AppStrings.profileMissingTitle,
          message: AppStrings.profileMissingBody,
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
