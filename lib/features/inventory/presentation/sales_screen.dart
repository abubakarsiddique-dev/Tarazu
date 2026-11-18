import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarazu/features/staff/presentation/staff_entry_card.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/sync_status_chip.dart';
import '../../auth/application/auth_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/models.dart';
import '../domain/sale_models.dart';
import '../domain/sale_strings.dart';

/// Today's sales. Like purchases, only TODAY's sales can be cancelled.
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  Future<void> _confirmVoidSale(
    BuildContext context,
    WidgetRef ref,
    Sale s,
  ) async {
    final theme = Theme.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(SaleStrings.cancelSaleTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(SaleStrings.cancelSaleBody),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: AppRadius.brSm,
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.buyerName.isEmpty
                          ? s.title
                          : '${s.title} • ${s.buyerName}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final i in s.items)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                i.materialName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.onErrorContainer,
                                ),
                              ),
                            ),
                            Text(
                              '+${formatKg(i.weightGrams)}',
                              style: AppTextStyles.badge.copyWith(
                                color: AppColors.onErrorContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '+${formatKg(s.totalWeightGrams)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '-${formatRs(s.totalAmount)}',
                          style: AppTextStyles.cardAmount.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(SaleStrings.keep),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              minimumSize: const Size(96, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(SaleStrings.yesCancel),
          ),
        ],
      ),
    );
    if (sure == true) ref.read(inventoryActionsProvider).voidSale(s);
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Sale s, {
    required bool isOwner,
  }) async {
    final theme = Theme.of(context);
    final wantsCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${SaleStrings.sale}: ${formatRs(s.totalAmount)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatTime(s.createdAt)}'
                '${s.buyerName.isEmpty ? '' : '  •  ${SaleStrings.buyerLabel}: ${s.buyerName}'}',
                style: theme.textTheme.bodyMedium,
              ),
              const Divider(height: AppSpacing.xl),
              for (final i in s.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.materialName),
                  subtitle: Text(i.detail),
                  trailing: Text(
                    formatRs(i.amount),
                    style: AppTextStyles.cardAmount,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                backgroundColor: AppColors.secondaryContainer,
                borderColor: AppColors.secondary.withValues(alpha: 0.3),
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${s.items.length} ${AppStrings.items} • ${formatKg(s.totalWeightGrams)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      formatRs(s.totalAmount),
                      style: AppTextStyles.cardAmount.copyWith(
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isOwner)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                SaleStrings.cancelSale,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.close),
          ),
        ],
      ),
    );
    if (wantsCancel != true || !context.mounted) return;
    await _confirmVoidSale(context, ref, s);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(isOwnerProvider);
    final day = dayKey(DateTime.now());
    final sales = ref.watch(salesForDayProvider(day));
    final summary =
        ref.watch(salesDailyProvider(day)).value ?? const DailySummary.empty();

    return Scaffold(
      appBar: AppBar(title: const Text(SaleStrings.todaysSales)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newSale),
        icon: const Icon(Icons.add_rounded),
        label: const Text(SaleStrings.sellStock),
      ),
      body: sales.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (list) {
          final pendingCount = list.where((s) => s.pendingSync).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.fabClearance,
            ),
            children: [
              StatTile(
                label: SaleStrings.todaysSales,
                icon: Icons.local_shipping_outlined,
                value: formatRs(summary.totalAmount),
                subtitle:
                    '${formatKg(summary.totalWeightGrams)} • ${summary.entryCount} ${AppStrings.entries}',
                variant: StatTileVariant.secondary,
                trailing: list.isEmpty
                    ? null
                    : Flexible(
                        child: SyncStatusChip(
                          pendingSync: pendingCount > 0,
                          pendingCount: pendingCount,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              const StaffLegend(),
              const SizedBox(height: AppSpacing.xs),
              if (list.isEmpty)
                const EmptyState(
                  icon: Icons.local_shipping_outlined,
                  message: SaleStrings.noSalesToday,
                  compact: true,
                )
              else
                for (final s in list)
                  StaffEntryCard(
                    createdBy: s.createdBy,
                    child: ListTile(
                      title: Text(s.title),
                      subtitle: Text(
                        '${formatTime(s.createdAt)} • ${s.items.length} ${AppStrings.items} • '
                        '${formatKg(s.totalWeightGrams)}'
                        '${s.buyerName.isEmpty ? '' : ' • ${s.buyerName}'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SyncStatusChip(
                            pendingSync: s.pendingSync,
                            compact: true,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            formatRs(s.totalAmount),
                            style: AppTextStyles.cardAmount,
                          ),
                        ],
                      ),
                      onTap: () => _open(context, ref, s, isOwner: isOwner),
                      onLongPress: isOwner
                          ? () => _confirmVoidSale(context, ref, s)
                          : null,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
