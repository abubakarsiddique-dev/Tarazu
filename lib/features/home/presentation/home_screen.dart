import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarazu/features/staff/presentation/munshi_home_screen.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/sync_status_chip.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../finance/domain/finance_strings.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/models.dart';
import '../../inventory/domain/sale_models.dart';
import '../../inventory/domain/sale_strings.dart';
import '../../inventory/presentation/adjust_stock_dialog.dart';
import '../../inventory/presentation/report_screen.dart' show ReportStrings;
import '../../inventory/presentation/slip_sheet.dart';
import '../../staff/domain/staff_strings.dart';
import '../../staff/presentation/staff_entry_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _confirmVoid(
    BuildContext context,
    WidgetRef ref,
    Purchase p,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.voidPurchase),
        content: const Text(AppStrings.voidBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.keep),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              minimumSize: const Size(96, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.voidAction),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(inventoryActionsProvider).voidPurchase(p);
  }

  Future<void> _recordGarbage(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<StockItem>> stockAsync,
  ) async {
    if (stockAsync.isLoading) return;
    if (stockAsync.hasError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(AppStrings.errGeneric)));
      return;
    }
    final positiveItems = (stockAsync.value ?? const <StockItem>[])
        .where((i) => i.weightGrams > 0)
        .toList();
    if (positiveItems.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(SaleStrings.noStockToSell)),
        );
      return;
    }
    final result = await showAdjustStockDialog(
      context,
      items: positiveItems,
      initialAdd: false,
      initialReason: AdjustmentReason.garbage,
      lockReason: true,
    );
    if (result == null) return;
    ref.read(inventoryActionsProvider).adjustStock(
          materialId: result.item.materialId,
          materialName: result.item.materialName,
          deltaGrams: result.deltaGrams,
          reason: result.reason,
          note: result.note,
          costPerKg: result.costPerKg,
        );
    if (!context.mounted) return;
    final remaining = result.item.weightGrams + result.deltaGrams;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${result.item.materialName}: ${SaleStrings.remainingStock} ${formatKg(remaining)}',
          ),
        ),
      );
  }

  /// Lets the owner set the phone number that is printed on shared slips.
  Future<void> _editShopDetails(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ShopDetailsDialog(initialPhone: user.phone),
    );
    if (result == null) return;
    ref.read(authRepositoryProvider).updatePhone(user.uid, result);
  }

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
    final isOwner = ref.watch(isOwnerProvider);
    if (user != null && !isOwner) return const MunshiHomeScreen();

    final day = dayKey(DateTime.now());
    final summary =
        ref.watch(dailySummaryProvider(day)).value ??
        const DailySummary.empty();
    final purchases = ref.watch(purchasesForDayProvider(day));
    final stockAsync = ref.watch(stockProvider);

    final purchaseList = purchases.value ?? const <Purchase>[];
    final pendingPurchaseCount =
        purchaseList.where((p) => p.pendingSync).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.shopName ?? AppStrings.appName),
        actions: [
          IconButton(
            tooltip: AppStrings.shopDetails,
            icon: const Icon(Icons.storefront_outlined),
            onPressed: user == null
                ? null
                : () => _editShopDetails(context, ref, user),
          ),
          IconButton(
            tooltip: AppStrings.logout,
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(
              context,
              ref,
              hasPendingSync: pendingPurchaseCount > 0,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.addPurchase),
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.addPurchase),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.fabClearance,
        ),
        children: [
          // 1. Today's Purchase Summary Hero Card
          StatTile(
            label: AppStrings.today,
            icon: Icons.today_outlined,
            value: formatRs(summary.totalAmount),
            subtitle:
                '${formatKg(summary.totalWeightGrams)} • ${summary.entryCount} ${AppStrings.entries}',
            trailing: purchaseList.isEmpty
                ? null
                : Flexible(
                    child: SyncStatusChip(
                      pendingSync: pendingPurchaseCount > 0,
                      pendingCount: pendingPurchaseCount,
                      syncedLabel: AppStrings.todayPurchasesSynced,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Primary Counter Actions: Add Purchase + New Sale side by side
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: AppStrings.addPurchase,
                  icon: Icons.add_rounded,
                  onPressed: () => context.push(Routes.addPurchase),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SecondaryButton(
                  label: SaleStrings.newSale,
                  icon: Icons.local_shipping_outlined,
                  onPressed: () => context.push(Routes.newSale),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 3. Current Stock Summary Card (Owner only, Option B: total kg + top 3 materials)
          if (isOwner) ...[
            _StockOverviewCard(
              stockAsync: stockAsync,
              onTap: () => context.push(Routes.stock),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 4. Navigation Hub Tiles (2-column flexible rows)
          _NavRow(
            left: _NavTile(
              icon: Icons.inventory_2_outlined,
              label: AppStrings.stock,
              onTap: () => context.push(Routes.stock),
            ),
            right: _NavTile(
              icon: Icons.local_shipping_outlined,
              label: SaleStrings.sales,
              onTap: () => context.push(Routes.sales),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavRow(
            left: _NavTile(
              icon: Icons.category_outlined,
              label: AppStrings.materials,
              onTap: () => context.push(Routes.materials),
            ),
            right: _NavTile(
              icon: Icons.history_rounded,
              label: AppStrings.history,
              onTap: () => context.push(Routes.history),
            ),
          ),
          if (isOwner) ...[
            const SizedBox(height: AppSpacing.sm),
            _NavRow(
              left: _NavTile(
                icon: Icons.trending_up_rounded,
                label: FinanceStrings.profit,
                onTap: () => context.push(Routes.profit),
              ),
              right: _NavTile(
                icon: Icons.account_balance_wallet_outlined,
                label: FinanceStrings.expensesTitle,
                onTap: () => context.push(Routes.expenses),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _NavRow(
              left: _NavTile(
                icon: Icons.bar_chart_rounded,
                label: ReportStrings.title,
                onTap: () => context.push(Routes.report),
              ),
              right: _NavTile(
                icon: Icons.groups_2_outlined,
                label: StaffStrings.munshiHisaab,
                onTap: () => context.push(Routes.staffSummary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _NavRow(
              left: _NavTile(
                icon: Icons.manage_accounts_outlined,
                label: StaffStrings.title,
                onTap: () => context.push(Routes.staff),
              ),
              right: _NavTile(
                icon: Icons.delete_sweep_outlined,
                label: SaleStrings.recordGarbage,
                onTap: () => _recordGarbage(context, ref, stockAsync),
              ),
            ),
          ],

          // 5. Today's Purchases List
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.purchasesToday, style: theme.textTheme.titleMedium),
          const StaffLegend(),
          const SizedBox(height: AppSpacing.sm),
          purchases.when(
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
                    StaffEntryCard(
                      createdBy: p.createdBy,
                      child: ListTile(
                        title: Text(p.title),
                        subtitle: Text(
                          '${p.items.length} ${AppStrings.items} • ${formatKg(p.totalWeightGrams)}'
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
                        onTap: () => showSlipSheet(
                          context,
                          p,
                          onVoid: isOwner
                              ? () => _confirmVoid(context, ref, p)
                              : null,
                          shopName: user?.shopName ?? '',
                          shopPhone: user?.phone ?? '',
                        ),
                        onLongPress: isOwner
                            ? () => _confirmVoid(context, ref, p)
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Shows total stock weight and top 3 materials by weight (Option B).
class _StockOverviewCard extends StatelessWidget {
  const _StockOverviewCard({
    required this.stockAsync,
    required this.onTap,
  });

  final AsyncValue<List<StockItem>> stockAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return stockAsync.when(
      loading: () => const AppCard(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: AppSpacing.md),
            Text(AppStrings.stock),
          ],
        ),
      ),
      error: (_, _) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text(AppStrings.errGeneric)),
          ],
        ),
      ),
      data: (items) {
        final totalGrams =
            items.fold<int>(0, (sum, item) => sum + item.weightGrams);
        final topThree = ([...items]
              ..sort((a, b) => b.weightGrams.compareTo(a.weightGrams)))
            .where((i) => i.weightGrams > 0)
            .take(3)
            .toList();

        return AppCard(
          backgroundColor: AppColors.secondaryContainer,
          borderColor: AppColors.secondary.withValues(alpha: 0.3),
          onTap: onTap,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: AppColors.onSecondaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppStrings.totalStock,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ),
                  Text(
                    formatKg(totalGrams),
                    style: AppTextStyles.statNumber.copyWith(
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.onSecondaryContainer,
                  ),
                ],
              ),
              if (topThree.isEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.noStockYet,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSecondaryContainer.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final item in topThree)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: AppRadius.brSm,
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Text(
                          '${item.materialName}: ${formatKg(item.weightGrams)}',
                          style: AppTextStyles.badge.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.minTapTarget - 16,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopDetailsDialog extends StatefulWidget {
  const _ShopDetailsDialog({required this.initialPhone});

  final String initialPhone;

  @override
  State<_ShopDetailsDialog> createState() => _ShopDetailsDialogState();
}

class _ShopDetailsDialogState extends State<_ShopDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_phone.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.shopDetails),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: AppStrings.shopPhone,
                helperText: AppStrings.phoneShownOnSlip,
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: Validators.phoneOptional,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _submit,
          child: const Text(AppStrings.save),
        ),
      ],
    );
  }
}
