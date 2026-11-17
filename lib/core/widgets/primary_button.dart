import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 52dp+ full-width primary action button with built-in loading spinner and optional icon.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isDestructive;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
      foregroundColor: isDestructive ? AppColors.onError : AppColors.onPrimary,
      minimumSize: Size(
        expand ? double.infinity : AppSpacing.minTapTarget,
        AppSpacing.primaryButtonHeight,
      ),
    );

    final effectiveOnPressed = isLoading ? null : onPressed;

    if (isLoading) {
      return FilledButton(
        style: style,
        onPressed: null,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (icon != null) {
      return FilledButton.icon(
        style: style,
        onPressed: effectiveOnPressed,
        icon: Icon(icon, size: 22),
        label: Text(label),
      );
    }

    return FilledButton(
      style: style,
      onPressed: effectiveOnPressed,
      child: Text(label),
    );
  }
}

/// 48dp+ secondary / outlined button with clear border for daylight visibility.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isDestructive = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isDestructive;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final fg = isDestructive ? AppColors.error : AppColors.textPrimary;
    final border = isDestructive ? AppColors.error : AppColors.outline;

    final style = OutlinedButton.styleFrom(
      foregroundColor: fg,
      side: BorderSide(color: border, width: 1.2),
      minimumSize: Size(
        expand ? double.infinity : AppSpacing.minTapTarget,
        AppSpacing.minTapTarget,
      ),
    );

    if (icon != null) {
      return OutlinedButton.icon(
        style: style,
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: isDestructive ? AppColors.error : AppColors.primary),
        label: Text(label),
      );
    }

    return OutlinedButton(
      style: style,
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
