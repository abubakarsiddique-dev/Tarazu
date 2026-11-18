import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/staff_lookup.dart';
import '../domain/staff_strings.dart';

/// Drop-in replacement for `Card(child: ...)` in the OWNER's lists.
/// If the entry was made by a munshi it turns orange and shows `Munshi: <name>`.
/// Owner's own entries look like a crisp bordered `Card`.
class StaffEntryCard extends ConsumerWidget {
  const StaffEntryCard({
    super.key,
    required this.createdBy,
    required this.child,
  });

  final String createdBy;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(staffNameProvider(createdBy));
    if (name == null) return Card(child: child);

    return Card(
      color: AppColors.munshiContainer,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: const BorderSide(color: AppColors.munshiAccent, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  size: 16,
                  color: AppColors.munshiAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${StaffStrings.munshiPrefix}: $name',
                    style: AppTextStyles.badge.copyWith(
                      color: AppColors.munshiAccent,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Small legend for the owner's home screen. Hidden when there are no munshis.
class StaffLegend extends ConsumerWidget {
  const StaffLegend({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(staffNamesProvider).isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.munshiContainer,
              border: Border.all(color: AppColors.munshiAccent, width: 1.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              StaffStrings.munshiLegend,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
