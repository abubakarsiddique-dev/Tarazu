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
import '../../../core/widgets/stat_tile.dart';
import '../../auth/application/auth_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/models.dart';
import '../domain/sale_strings.dart';
import 'adjust_stock_dialog.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  Future<void> _adjust(
    BuildContext context,
    WidgetRef ref,
    StockItem item,
  ) async {
    final result = await showAdjustStockDialog(context, item: item);
    if (result == null) return;
    ref.read(inventoryActionsProvider).adjustStock(
      materialId: item.materialId,
      materialName: item.materialName,
      deltaGrams: result.deltaGrams,
      reason: result.reason,
      note: result.note,
      costPerKg: result.costPerKg,
    );
    if (!context.mounted) return;
    final remaining = item.weightGrams + result.deltaGrams;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${item.materialName}: ${SaleStrings.remainingStock} ${formatKg(remaining)}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(stockProvider);
    final isOwner = ref.watch(isOwnerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.stock),
        actions: [
          IconButton(
            tooltip: SaleStrings.sales,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push(Routes.sales),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newSale),
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text(SaleStrings.sellStock),
      ),
      body: stock.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              message: AppStrings.noStockYet,
            );
          }
          final totalGrams = items.fold<int>(
            0,
            (sum, i) => sum + i.weightGrams,
          );
          final anyNegative = items.any((i) => i.weightGrams < 0);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.fabClearance,
            ),
            children: [
              StatTile(
                label: AppStrings.totalStock,
                icon: Icons.inventory_2_outlined,
                value: formatKg(totalGrams),
                variant: anyNegative
                    ? StatTileVariant.danger
                    : StatTileVariant.secondary,
              ),
              if (anyNegative) ...[
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  backgroundColor: AppColors.errorContainer,
                  borderColor: AppColors.error,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          SaleStrings.negativeStockWarning,
                          style: TextStyle(
                            color: AppColors.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final i in items)
                AppCard(
                  padding: EdgeInsets.zero,
                  onTap: isOwner ? () => _adjust(context, ref, i) : null,
                  child: ListTile(
                    title: Text(i.materialName),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatKg(i.weightGrams),
                          style: AppTextStyles.cardAmount.copyWith(
                            color: i.weightGrams < 0 ? AppColors.error : null,
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
