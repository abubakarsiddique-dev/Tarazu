import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../inventory/application/garbage_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/application/report_providers.dart';
import '../../inventory/domain/history.dart';
import '../../inventory/domain/models.dart' show ScrapMaterial, dayKey, formatStockQty;
import '../../inventory/domain/sale_strings.dart';
import '../application/finance_providers.dart';
import '../domain/finance_strings.dart';
import '../domain/net_profit.dart';

String _signed(int v) => '${v < 0 ? '-' : ''}${formatRs(v.abs())}';

String _label(HistoryPeriod p, DateTime start) {
  final from = dayKey(start);
  final to = dayKey(periodEnd(p, start));
  return p == HistoryPeriod.day ? from : '$from  to  $to';
}

/// Owner-only Net Profit screen:
/// Selling price - Buying price (total purchases) - Expenses - Garbage cost.
class NetProfitScreen extends ConsumerStatefulWidget {
  const NetProfitScreen({super.key});

  @override
  ConsumerState<NetProfitScreen> createState() => _NetProfitScreenState();
}

class _NetProfitScreenState extends ConsumerState<NetProfitScreen> {
  HistoryPeriod _period = HistoryPeriod.month;
  DateTime _start = periodStart(HistoryPeriod.month, DateTime.now());

  bool get _isCurrent => !_start.isBefore(periodStart(_period, DateTime.now()));

  void _setPeriod(HistoryPeriod p) => setState(() {
        _period = p;
        _start = periodStart(p, _start);
      });

  void _move(int n) => setState(() => _start = shiftPeriod(_period, _start, n));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = (from: dayKey(_start), to: dayKey(periodEnd(_period, _start)));
    final purchasesAsync = ref.watch(purchasesRangeProvider(range));
    final salesAsync = ref.watch(salesRangeProvider(range));
    final expensesAsync = ref.watch(expensesRangeProvider(range));
    final garbageAsync = ref.watch(garbageHistoryProvider(range));
    final materials =
        ref.watch(materialsProvider).value ?? const <ScrapMaterial>[];

    Widget body;
    if (purchasesAsync.hasError ||
        salesAsync.hasError ||
        expensesAsync.hasError ||
        garbageAsync.hasError) {
      body = const ErrorState(message: FinanceStrings.error, compact: true);
    } else if (!purchasesAsync.hasValue ||
        !salesAsync.hasValue ||
        !expensesAsync.hasValue ||
        !garbageAsync.hasValue) {
      body = const LoadingState(compact: true);
    } else {
      final summary = computeNetProfitSummary(
        purchases: purchasesAsync.requireValue,
        sales: salesAsync.requireValue,
        expenses: expensesAsync.requireValue,
        garbage: garbageAsync.requireValue,
      );
      body = _Body(summary: summary, materials: materials);
    }

    return Scaffold(
      appBar: AppBar(title: const Text(FinanceStrings.netProfit)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SegmentedButton<HistoryPeriod>(
            segments: const [
              ButtonSegment(
                value: HistoryPeriod.day,
                label: Text(FinanceStrings.day),
              ),
              ButtonSegment(
                value: HistoryPeriod.week,
                label: Text(FinanceStrings.week),
              ),
              ButtonSegment(
                value: HistoryPeriod.month,
                label: Text(FinanceStrings.month),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (s) => _setPeriod(s.first),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: FinanceStrings.previous,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _move(-1),
                ),
                Expanded(
                  child: Text(
                    _label(_period, _start),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: FinanceStrings.next,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _isCurrent ? null : () => _move(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          body,
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary, required this.materials});

  final NetProfitSummary summary;
  final List<ScrapMaterial> materials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = summary.netProfit;
    final statusLabel = net > 0
        ? FinanceStrings.profitStatus
        : (net < 0
              ? FinanceStrings.lossStatus
              : FinanceStrings.breakEvenStatus);
    final variant = net < 0
        ? StatTileVariant.danger
        : (net > 0 ? StatTileVariant.primary : StatTileVariant.secondary);

    Widget line(
      String label,
      String value, {
      bool bold = false,
      Color? color,
      VoidCallback? onTap,
    }) {
      final row = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: (bold
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      color: onTap != null
                          ? theme.colorScheme.primary
                          : AppColors.textPrimary,
                      fontWeight: onTap != null
                          ? FontWeight.w600
                          : (bold ? FontWeight.w700 : null),
                    ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              value,
              style:
                  (bold
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(
                        fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                        color: color ?? AppColors.textPrimary,
                      ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      );
      if (onTap == null) return row;
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brSm,
        child: row,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatTile(
          label: FinanceStrings.netProfit,
          icon: net < 0
              ? Icons.trending_down_rounded
              : Icons.trending_up_rounded,
          value: _signed(net),
          subtitle: statusLabel,
          variant: variant,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              line(
                FinanceStrings.totalSellingPrice,
                formatRs(summary.totalSellingPrice),
                color: AppColors.primary,
              ),
              line(
                FinanceStrings.totalBuyingPrice,
                '- ${formatRs(summary.totalBuyingPrice)}',
              ),
              line(
                FinanceStrings.expenses,
                '- ${formatRs(summary.totalExpenses)}',
              ),
              line(
                FinanceStrings.totalGarbageCost,
                '- ${formatRs(summary.totalGarbageCost)}',
                onTap: () => context.push(Routes.garbageHistory),
              ),
              const Divider(height: AppSpacing.lg),
              line(
                statusLabel,
                _signed(net),
                bold: true,
                color: net < 0
                    ? AppColors.error
                    : (net > 0 ? AppColors.primary : null),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          FinanceStrings.netProfitFormulaNote,
          style: theme.textTheme.bodySmall,
        ),
        if (summary.isEmpty)
          const EmptyState(
            icon: Icons.calculate_outlined,
            message: FinanceStrings.noNetProfitData,
            compact: true,
          )
        else if (summary.materials.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(SaleStrings.sales, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final m in summary.materials)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Bought: ${formatStockQty(m.boughtGrams, materials: materials, materialId: m.materialId)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        formatRs(m.boughtAmount),
                        style: AppTextStyles.cardAmount,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Sold: ${formatStockQty(m.soldGrams, materials: materials, materialId: m.materialId)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        formatRs(m.soldAmount),
                        style: AppTextStyles.cardAmount.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (m.garbageGrams > 0 || m.garbageCost > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${FinanceStrings.garbage}: ${formatStockQty(m.garbageGrams, materials: materials, materialId: m.materialId)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '- ${formatRs(m.garbageCost)}',
                          style: AppTextStyles.cardAmount.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}
