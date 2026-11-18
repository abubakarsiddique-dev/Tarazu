import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../auth/application/auth_providers.dart';
import '../application/inventory_providers.dart';
import '../application/report_providers.dart';
import '../domain/history.dart';
import '../domain/models.dart' show dayKey;
import '../domain/report.dart';

// Kept here so this feature is a pure copy-paste (same approach as write_failures.dart).
class ReportStrings {
  ReportStrings._();
  static const title = 'Report';
  static const day = 'Day';
  static const week = 'Week';
  static const month = 'Month';
  static const previous = 'Previous';
  static const next = 'Next';
  static const purchases = 'Purchases';
  static const sales = 'Sales';
  static const difference = 'Sales minus purchases';
  static const notProfit =
      'Not profit: stock you have not sold yet is not counted.';
  static const byMaterial = 'By material';
  static const bought = 'Bought';
  static const sold = 'Sold';
  static const share = 'Share report (WhatsApp)';
  static const nothing = 'Nothing in this period.';
  static const error = 'Something went wrong. Please try again.';
}

String _label(HistoryPeriod p, DateTime start) {
  final from = dayKey(start);
  final to = dayKey(periodEnd(p, start));
  return p == HistoryPeriod.day ? from : '$from  to  $to';
}

/// Purchases + sales for a day / week / month, shareable as text.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
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
    final shopName = ref.watch(userProfileProvider).value?.shopName ?? '';

    Widget body;
    if (purchasesAsync.hasError || salesAsync.hasError) {
      body = const ErrorState(message: ReportStrings.error, compact: true);
    } else if (!purchasesAsync.hasValue || !salesAsync.hasValue) {
      body = const LoadingState(compact: true);
    } else {
      final p = summarizeHistory(purchasesAsync.requireValue);
      final s = summarizeSales(salesAsync.requireValue);
      final diff = s.totalAmount - p.totalAmount;
      final rows = combineMaterials(p, s);
      final empty = p.slipCount == 0 && s.saleCount == 0;

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatTile(
            label: ReportStrings.purchases,
            icon: Icons.shopping_cart_checkout_rounded,
            value: formatRs(p.totalAmount),
            subtitle:
                '${formatKg(p.totalGrams)} • ${p.slipCount} ${AppStrings.entries}',
            variant: StatTileVariant.primary,
            isHero: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          StatTile(
            label: ReportStrings.sales,
            icon: Icons.local_shipping_outlined,
            value: formatRs(s.totalAmount),
            subtitle:
                '${formatKg(s.totalGrams)} • ${s.saleCount} ${AppStrings.entries}',
            variant: StatTileVariant.secondary,
            isHero: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            backgroundColor: diff < 0
                ? AppColors.errorContainer
                : AppColors.surfaceCard,
            borderColor: diff < 0
                ? AppColors.error.withValues(alpha: 0.4)
                : AppColors.outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ReportStrings.difference,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: diff < 0
                              ? AppColors.onErrorContainer
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${diff < 0 ? '-' : ''}${formatRs(diff.abs())}',
                      style: AppTextStyles.statNumber.copyWith(
                        color: diff < 0
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ReportStrings.notProfit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: diff < 0
                        ? AppColors.onErrorContainer.withValues(alpha: 0.85)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (empty)
            const EmptyState(
              icon: Icons.bar_chart_rounded,
              message: ReportStrings.nothing,
              compact: true,
            )
          else ...[
            const SizedBox(height: AppSpacing.xl),
            Text(ReportStrings.byMaterial, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final r in rows)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${ReportStrings.bought}: ${formatKg(r.boughtGrams)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          formatRs(r.boughtAmount),
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
                            '${ReportStrings.sold}: ${formatKg(r.soldGrams)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          formatRs(r.soldAmount),
                          style: AppTextStyles.cardAmount.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: buildReportText(
                    shopName: shopName,
                    periodLabel: _label(_period, _start),
                    purchases: p,
                    sales: s,
                  ),
                ),
              ),
              icon: Icons.share_outlined,
              label: ReportStrings.share,
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(ReportStrings.title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SegmentedButton<HistoryPeriod>(
            segments: const [
              ButtonSegment(
                value: HistoryPeriod.day,
                label: Text(ReportStrings.day),
              ),
              ButtonSegment(
                value: HistoryPeriod.week,
                label: Text(ReportStrings.week),
              ),
              ButtonSegment(
                value: HistoryPeriod.month,
                label: Text(ReportStrings.month),
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
                  tooltip: ReportStrings.previous,
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
                  tooltip: ReportStrings.next,
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
