import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarazu/features/staff/presentation/staff_entry_card.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/sync_status_chip.dart';
import '../../auth/application/auth_providers.dart';
import '../../finance/domain/finance_strings.dart';
import '../../staff/application/staff_lookup.dart';
import '../application/garbage_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/garbage_history.dart';
import '../domain/history.dart';
import '../domain/models.dart';
import '../domain/sale_models.dart';
import '../domain/sale_strings.dart';
import 'adjust_stock_dialog.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _short(DateTime d) =>
    '${d.day} ${_monthNames[d.month - 1].substring(0, 3)}';

String _dayLabel(DateTime d) =>
    '${_weekdayNames[d.weekday - 1]}, ${_short(d)} ${d.year}';

String _periodLabel(HistoryPeriod p, DateTime start) {
  switch (p) {
    case HistoryPeriod.day:
      return _dayLabel(start);
    case HistoryPeriod.week:
      final end = periodEnd(p, start);
      return '${_short(start)} – ${_short(end)} ${end.year}';
    case HistoryPeriod.month:
      return '${_monthNames[start.month - 1]} ${start.year}';
  }
}

/// Owner-only Garbage history screen: Day / Week / Month filter, total garbage
/// weight and moving-average cost, per-material subtotals, and entry list.
class GarbageHistoryScreen extends ConsumerStatefulWidget {
  const GarbageHistoryScreen({super.key});

  @override
  ConsumerState<GarbageHistoryScreen> createState() =>
      _GarbageHistoryScreenState();
}

class _GarbageHistoryScreenState extends ConsumerState<GarbageHistoryScreen> {
  HistoryPeriod _period = HistoryPeriod.month;
  DateTime _start = periodStart(HistoryPeriod.month, DateTime.now());

  bool get _isCurrent => !_start.isBefore(periodStart(_period, DateTime.now()));

  void _setPeriod(HistoryPeriod p) => setState(() {
    _period = p;
    _start = periodStart(p, _start);
  });

  void _move(int n) => setState(() => _start = shiftPeriod(_period, _start, n));

  Future<void> _recordGarbage(
    BuildContext context,
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
    final materials =
        ref.read(materialsProvider).value ?? const <ScrapMaterial>[];
    final result = await showAdjustStockDialog(
      context,
      items: positiveItems,
      materials: materials,
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
    final remLabel = formatStockQty(
      remaining,
      materials: materials,
      materialId: result.item.materialId,
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${result.item.materialName}: ${SaleStrings.remainingStock} $remLabel',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = (from: dayKey(_start), to: dayKey(periodEnd(_period, _start)));
    final data = ref.watch(garbageHistoryProvider(range));
    final stockAsync = ref.watch(stockProvider);
    final ownerName = ref.watch(userProfileProvider).value?.ownerName ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text(SaleStrings.garbageHistory)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _recordGarbage(context, stockAsync),
        icon: const Icon(Icons.delete_sweep_outlined),
        label: const Text(SaleStrings.recordGarbage),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.fabClearance,
        ),
        children: [
          SegmentedButton<HistoryPeriod>(
            segments: const [
              ButtonSegment(
                value: HistoryPeriod.day,
                label: Text(AppStrings.periodDay),
              ),
              ButtonSegment(
                value: HistoryPeriod.week,
                label: Text(AppStrings.periodWeek),
              ),
              ButtonSegment(
                value: HistoryPeriod.month,
                label: Text(AppStrings.periodMonth),
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
                  tooltip: AppStrings.previous,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _move(-1),
                ),
                Expanded(
                  child: Text(
                    _periodLabel(_period, _start),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.next,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _isCurrent ? null : () => _move(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          data.when(
            loading: () => const LoadingState(compact: true),
            error: (_, _) => const ErrorState(compact: true),
            data: (summary) => _GarbageBody(
              summary: summary,
              period: _period,
              ownerName: ownerName,
            ),
          ),
        ],
      ),
    );
  }
}

class _GarbageBody extends ConsumerWidget {
  const _GarbageBody({
    required this.summary,
    required this.period,
    required this.ownerName,
  });

  final GarbageHistorySummary summary;
  final HistoryPeriod period;
  final String ownerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final materials =
        ref.watch(materialsProvider).value ?? const <ScrapMaterial>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatTile(
          label: SaleStrings.garbageCost,
          icon: Icons.delete_sweep_outlined,
          value: formatRs(summary.totalCost),
          subtitle:
              '${formatKg(summary.totalGrams)} • ${summary.entryCount} ${AppStrings.entries}',
          variant: StatTileVariant.secondary,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(FinanceStrings.estimateNote, style: theme.textTheme.bodySmall),
        if (summary.entryCount == 0)
          const EmptyState(
            icon: Icons.delete_sweep_outlined,
            message: SaleStrings.noGarbageInPeriod,
            compact: true,
          )
        else ...[
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.byMaterial, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < summary.materials.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(summary.materials[i].name),
                    subtitle: Text(
                      '${formatStockQty(summary.materials[i].grams, materials: materials, materialId: summary.materials[i].materialId)} • '
                      '${summary.materials[i].entryCount} ${AppStrings.entries}',
                    ),
                    trailing: Text(
                      '${FinanceStrings.cost} ${formatRs(summary.materials[i].cost)}',
                      style: AppTextStyles.cardAmount,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(SaleStrings.garbageEntries, style: theme.textTheme.titleMedium),
          const StaffLegend(),
          const SizedBox(height: AppSpacing.sm),
          for (final e in summary.entries)
            _GarbageEntryTile(
              entry: e,
              materials: materials,
              showDayKey: period != HistoryPeriod.day,
              ownerName: ownerName,
            ),
        ],
      ],
    );
  }
}

class _GarbageEntryTile extends ConsumerWidget {
  const _GarbageEntryTile({
    required this.entry,
    required this.materials,
    required this.showDayKey,
    required this.ownerName,
  });

  final GarbageEntry entry;
  final List<ScrapMaterial> materials;
  final bool showDayKey;
  final String ownerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffName = ref.watch(staffNameProvider(entry.createdBy));
    final who = staffName ??
        (ownerName.trim().isNotEmpty
            ? ownerName.trim()
            : SaleStrings.recordedByOwner);
    final timeStr = showDayKey
        ? '${entry.dayKey} ${formatTime(entry.createdAt)}'
        : formatTime(entry.createdAt);
    final subtitleParts = <String>[
      formatStockQty(
        entry.grams,
        materials: materials,
        materialId: entry.materialId,
      ),
      timeStr,
      who,
      if (entry.note.trim().isNotEmpty) entry.note.trim(),
    ];

    return StaffEntryCard(
      createdBy: entry.createdBy,
      child: ListTile(
        title: Text(entry.materialName),
        subtitle: Text(subtitleParts.join('  •  ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SyncStatusChip(pendingSync: entry.pendingSync, compact: true),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${FinanceStrings.cost} ${formatRs(entry.cost)}',
              style: AppTextStyles.cardAmount,
            ),
          ],
        ),
      ),
    );
  }
}
