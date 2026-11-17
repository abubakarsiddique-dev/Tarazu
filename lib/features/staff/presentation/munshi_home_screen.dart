import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sync_status_chip.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/models.dart';
import '../../inventory/domain/sale_strings.dart';
import '../domain/staff_strings.dart';

/// Set to false if the munshi should not even see his own entries of today.
const bool kMunshiSeesOwnTodayList = true;

/// Home screen for a MUNSHI. By design it has:
///  - NO today total, NO history, NO reports / profit
///  - NO owner name, NO shop phone, NO other munshi
///  - only the munshi's OWN purchases and sales (detail per slip)
class MunshiHomeScreen extends ConsumerWidget {
  const MunshiHomeScreen({super.key});

  Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref, {
    required bool hasPendingSync,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.logoutConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppStrings.logoutConfirmBody),
            if (hasPendingSync) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.munshiContainer,
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: AppColors.munshiAccent),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: AppColors.munshiAccent,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        AppStrings.logoutPendingSyncWarning,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onMunshiContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              minimumSize: const Size(96, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.logout),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(userProfileProvider).value;
    final day = dayKey(DateTime.now());
    final purchasesAsync = ref.watch(purchasesForDayProvider(day));
    final salesAsync = ref.watch(salesForDayProvider(day));

    final hasPendingPurchases =
        (purchasesAsync.value ?? const []).any((p) => p.pendingSync);
    final hasPendingSales =
        (salesAsync.value ?? const []).any((s) => s.pendingSync);
    final hasPendingSync = hasPendingPurchases || hasPendingSales;

    return Scaffold(
      appBar: AppBar(
        // The munshi's own name, not the shop / owner details.
        title: Text(user?.ownerName ?? AppStrings.appName),
        actions: [
          IconButton(
            tooltip: AppStrings.logout,
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(
              context,
              ref,
              hasPendingSync: hasPendingSync,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PrimaryButton(
            label: AppStrings.addPurchase,
            icon: Icons.add_rounded,
            onPressed: () => context.push(Routes.addPurchase),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: SaleStrings.newSale,
            icon: Icons.local_shipping_outlined,
            onPressed: () => context.push(Routes.newSale),
          ),
          if (kMunshiSeesOwnTodayList) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              StaffStrings.meriPurchases,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            purchasesAsync.when(
              loading: () => const LoadingState(compact: true),
              error: (_, _) => const ErrorState(compact: true),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: AppStrings.noPurchasesToday,
                    compact: true,
                  );
                }
                return Column(
                  children: [
                    for (final p in list)
                      Card(
                        child: ListTile(
                          title: Text(p.title),
                          subtitle: Text(
                            '${formatTime(p.createdAt)} • ${p.items.length} ${AppStrings.items} • '
                            '${formatKg(p.totalWeightGrams)}'
                            '${p.sellerName.isEmpty ? '' : ' • ${p.sellerName}'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SyncStatusChip(
                                pendingSync: p.pendingSync,
                                compact: true,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                formatRs(p.totalAmount),
                                style: AppTextStyles.cardAmount,
                              ),
                            ],
                          ),
                          onTap: () => _showLines(
                            context,
                            title: p.sellerName.isEmpty
                                ? p.title
                                : p.sellerName,
                            lines: [
                              for (final i in p.items)
                                (i.materialName, i.detail, i.amount),
                            ],
                            total: p.totalAmount,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              StaffStrings.meriSales,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            salesAsync.when(
              loading: () => const LoadingState(compact: true),
              error: (_, _) => const ErrorState(compact: true),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.local_shipping_outlined,
                    message: SaleStrings.noSalesToday,
                    compact: true,
                  );
                }
                return Column(
                  children: [
                    for (final s in list)
                      Card(
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
                          onTap: () => _showLines(
                            context,
                            title:
                                s.buyerName.isEmpty ? s.title : s.buyerName,
                            lines: [
                              for (final i in s.items)
                                (i.materialName, i.detail, i.amount),
                            ],
                            total: s.totalAmount,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Plain detail sheet (no shop phone / owner info, no void button).
  static void _showLines(
    BuildContext context, {
    required String title,
    required List<(String, String, int)> lines,
    required int total,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in lines)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.$1),
                        subtitle: Text(l.$2),
                        trailing: Text(
                          formatRs(l.$3),
                          style: AppTextStyles.cardAmount,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              AppCard(
                backgroundColor: AppColors.primaryContainer,
                borderColor: AppColors.primary.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.total,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      formatRs(total),
                      style: AppTextStyles.statNumber.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
