import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/sync/write_failures.dart';
import 'core/theme/app_theme.dart';

/// Lets us show a snackbar from anywhere (e.g. after a screen was popped).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class KabariApp extends ConsumerWidget {
  const KabariApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A write that the server rejected after the UI already showed it as saved.
    ref.listen<WriteFailure?>(writeFailureProvider, (_, failure) {
      if (failure == null) return;
      rootMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message),
            duration: const Duration(seconds: 10),
            showCloseIcon: true,
          ),
        );
    });

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
