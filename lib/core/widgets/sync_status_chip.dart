import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// Shows whether a single entry (or a list of entries) is synced or waiting for
/// internet. Can render as a compact icon for list rows or a labeled pill badge.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    super.key,
    required this.pendingSync,
    this.pendingCount,
    this.syncedLabel,
    this.pendingLabel,
    this.compact = false,
  });

  /// True if the entry (or at least one entry) has pending local writes.
  final bool pendingSync;

  /// Optional count of pending entries (e.g., on Dashboard header).
  final int? pendingCount;

  /// Optional custom label when synced (defaults to `AppStrings.synced`).
  final String? syncedLabel;

  /// Optional custom label when pending (overrides default pending label).
  final String? pendingLabel;

  /// When true, renders only a high-contrast icon with a tooltip (for tight list rows).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tooltipText =
        pendingSync ? AppStrings.waitingToSync : AppStrings.synced;

    if (compact) {
      return Tooltip(
        message: tooltipText,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: pendingSync ? AppColors.munshiContainer : Colors.transparent,
            borderRadius: AppRadius.brSm,
          ),
          child: Icon(
            pendingSync
                ? Icons.cloud_upload_outlined
                : Icons.cloud_done_outlined,
            size: 18,
            color: pendingSync ? AppColors.munshiAccent : AppColors.success,
          ),
        ),
      );
    }

    final label = pendingSync
        ? (pendingLabel ??
            (pendingCount != null && pendingCount! > 0
                ? '$pendingCount ${AppStrings.syncRemainingSuffix}'
                : AppStrings.waitingToSync))
        : (syncedLabel ?? AppStrings.synced);

    final bg =
        pendingSync ? AppColors.munshiContainer : AppColors.primaryContainer;
    final fg = pendingSync
        ? AppColors.onMunshiContainer
        : AppColors.onPrimaryContainer;
    final iconColor = pendingSync ? AppColors.munshiAccent : AppColors.primary;
    final border = pendingSync
        ? AppColors.munshiAccent.withValues(alpha: 0.45)
        : AppColors.primary.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.brSm,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pendingSync
                ? Icons.cloud_upload_outlined
                : Icons.cloud_done_outlined,
            size: 16,
            color: iconColor,
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.badge.copyWith(color: fg),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
