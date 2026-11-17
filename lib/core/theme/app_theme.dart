import 'package:flutter/material.dart';

/// Spacing scale (4 / 8 / 12 / 16 / 24 / 32) and minimum tap targets.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Bottom list padding so a FloatingActionButton never covers the last item.
  static const double fabClearance = 96;

  /// Minimum interactive tap target size (Material 3 accessibility guideline).
  static const double minTapTarget = 48;
  static const double primaryButtonHeight = 52;
}

/// Consistent border radii across cards, inputs, buttons, and sheets.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double sheet = 20;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
}

/// High-contrast semantic colors designed for outdoor daylight readability
/// on budget Android LCD screens.
class AppColors {
  AppColors._();

  // Brand / Primary (deep trustworthy ledger & recycling green)
  static const Color primary = Color(0xFF1B6B2F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFDCF2E1);
  static const Color onPrimaryContainer = Color(0xFF093815);

  // Secondary (muted slate-green for supporting stats & tonal buttons)
  static const Color secondary = Color(0xFF3F5243);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE4ECE5);
  static const Color onSecondaryContainer = Color(0xFF142418);

  // Warm neutral ledger background & crisp white cards
  static const Color background = Color(0xFFF7F6F2);
  static const Color surface = Color(0xFFF7F6F2);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFECEAE3);

  // Borders & Dividers
  static const Color outline = Color(0xFFC8C5BC);
  static const Color outlineVariant = Color(0xFFDFDDD5);

  // High-contrast text
  static const Color textPrimary = Color(0xFF171A17);
  static const Color textSecondary = Color(0xFF525853);

  // Munshi / Warning highlight (warm amber-orange)
  static const Color munshiAccent = Color(0xFFD95D00);
  static const Color munshiContainer = Color(0xFFFFF4E8);
  static const Color onMunshiContainer = Color(0xFF4D1F00);

  // Status: Success & Error
  static const Color success = Color(0xFF1B6B2F);
  static const Color successContainer = Color(0xFFDCF2E1);
  static const Color error = Color(0xFFC62828);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFDECEA);
  static const Color onErrorContainer = Color(0xFF410002);
}

/// Specialized text styles for currency (`Rs`) and weights (`kg`, `paka seer`)
/// with tabular figures so columns and live totals never jitter.
class AppTextStyles {
  AppTextStyles._();

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// Hero totals: Today's total, Slip total, Net profit (30sp ExtraBold).
  static const TextStyle displayNumber = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  /// Secondary stat cards, dialog totals, slip line totals (22sp Bold).
  static const TextStyle statNumber = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.25,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  /// Trailing Rs / kg amounts in list rows (17sp Bold).
  static const TextStyle cardAmount = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  /// Section headers ("Today's purchases", "Select material").
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// Badges, sync pills, Munshi tag (12sp SemiBold).
  static const TextStyle badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textSecondary,
  );
}

class AppTheme {
  AppTheme._();

  /// Kept so any existing code referencing `AppTheme.primary` continues to work.
  static const Color primary = AppColors.primary;

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.munshiAccent,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.munshiContainer,
      onTertiaryContainer: AppColors.onMunshiContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );

    const textTheme = TextTheme(
      headlineLarge: AppTextStyles.displayNumber,
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: AppColors.textPrimary,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      headlineSmall: AppTextStyles.statNumber,
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      labelMedium: AppTextStyles.badge,
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textSecondary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: const BorderSide(color: AppColors.outline, width: 1),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        minVerticalPadding: AppSpacing.sm,
        iconColor: AppColors.secondary,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.3,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.35,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
        helperStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        errorStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.error,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: AppColors.outline, width: 1.2),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: AppColors.outline, width: 1.2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.primaryButtonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surfaceCard,
          side: const BorderSide(color: AppColors.outline, width: 1.2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minTapTarget,
            AppSpacing.minTapTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minTapTarget,
            AppSpacing.minTapTarget,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        extendedTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceCard,
        selectedColor: AppColors.primaryContainer,
        disabledColor: AppColors.surfaceVariant,
        secondarySelectedColor: AppColors.primaryContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.onPrimaryContainer,
        ),
        checkmarkColor: AppColors.onPrimaryContainer,
        side: const BorderSide(color: AppColors.outline, width: 1.2),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.minTapTarget, AppSpacing.minTapTarget),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.outline, width: 1.2),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryContainer;
            }
            return AppColors.surfaceCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.onPrimaryContainer;
            }
            return AppColors.textPrimary;
          }),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: AppSpacing.lg,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),
    );
  }
}
