import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_card.dart';

enum StatTileVariant {
  /// Hero green-tinted container (e.g., Today's total, Slip total).
  primary,

  /// Muted slate-green container (e.g., Sales summary).
  secondary,

  /// Standard white card with border.
  surface,

  /// Red-tinted container for negative numbers / warnings.
  danger,
}

/// Displays a key metric at a glance with big tabular numbers, optional subtitle,
/// and flexible layout that never overflows on small screens or long text.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.trailing,
    this.variant = StatTileVariant.primary,
    this.isHero = true,
    this.onTap,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final StatTileVariant variant;

  /// When true, uses `displayNumber` (30sp). When false, uses `statNumber` (22sp).
  final bool isHero;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color fg, Color subFg) = switch (variant) {
      StatTileVariant.primary => (
          AppColors.primaryContainer,
          AppColors.primary.withValues(alpha: 0.35),
          AppColors.onPrimaryContainer,
          AppColors.onPrimaryContainer.withValues(alpha: 0.85),
        ),
      StatTileVariant.secondary => (
          AppColors.secondaryContainer,
          AppColors.secondary.withValues(alpha: 0.3),
          AppColors.onSecondaryContainer,
          AppColors.onSecondaryContainer.withValues(alpha: 0.85),
        ),
      StatTileVariant.surface => (
          AppColors.surfaceCard,
          AppColors.outline,
          AppColors.textPrimary,
          AppColors.textSecondary,
        ),
      StatTileVariant.danger => (
          AppColors.errorContainer,
          AppColors.error.withValues(alpha: 0.4),
          AppColors.onErrorContainer,
          AppColors.onErrorContainer.withValues(alpha: 0.85),
        ),
    };

    final valueStyle = (isHero ? AppTextStyles.displayNumber : AppTextStyles.statNumber)
        .copyWith(color: fg);

    return AppCard(
      backgroundColor: bg,
      borderColor: border,
      borderRadius: isHero ? AppRadius.brLg : AppRadius.brMd,
      padding: EdgeInsets.all(isHero ? 20 : AppSpacing.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: subFg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: subFg,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: valueStyle),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: subFg,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
