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
import '../application/inventory_providers.dart';
import '../domain/history.dart';
import '../domain/models.dart';
import 'slip_sheet.dart';

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

DateTime _parseDayKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Day / Week (Monday to Sunday) / Month totals, with a material filter.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryPeriod _period = HistoryPeriod.day;
  DateTime _start = periodStart(HistoryPeriod.day, DateTime.now());
  String? _materialId; // null = all materials

  bool get _isCurrent => !_start.isBefore(periodStart(_period, DateTime.now()));

  void _setPeriod(HistoryPeriod p) => setState(() {
    _period = p;
    _start = periodStart(p, _start);
  });

  void _move(int n) => setState(() => _start = shiftPeriod(_period, _start, n));

  void _openDay(String key) => setState(() {
    _period = HistoryPeriod.day;
    _start = _parseDayKey(key);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final materials =
        ref.watch(materialsProvider).value ?? const <ScrapMaterial>[];
    final range = (from: dayKey(_start), to: dayKey(periodEnd(_period, _start)));
    final data = ref.watch(purchasesRangeProvider(range));
    final user = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.history)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.minTapTarget,
                  ),
                  child: ChoiceChip(
                    label: const Text(AppStrings.allMaterials),
                    selected: _materialId == null,
                    onSelected: (_) => setState(() => _materialId = null),
                  ),
                ),
                for (final m in materials) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.minTapTarget,
                    ),
                    child: ChoiceChip(
                      label: Text(m.name),
                      selected: _materialId == m.id,
                      onSelected: (_) => setState(() => _materialId = m.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          data.when(
            loading: () => const LoadingState(compact: true),
            error: (_, _) => const ErrorState(compact: true),
            data: (purchases) => _Body(
              summary: summarizeHistory(purchases, materialId: _materialId),
              period: _period,
              onOpenDay: _openDay,
              shopName: user?.shopName ?? '',
              shopPhone: user?.phone ?? '',
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.summary,
    required this.period,
    required this.onOpenDay,
    required this.shopName,
    required this.shopPhone,
  });

  final HistorySummary summary;
  final HistoryPeriod period;
  final void Function(String dayKey) onOpenDay;
  final String shopName;
  final String shopPhone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatTile(
          label: AppStrings.total,
          icon: Icons.history_rounded,
          value: formatRs(summary.totalAmount),
          subtitle:
              '${formatKg(summary.totalGrams)} • ${summary.slipCount} ${AppStrings.entries}',
        ),
        if (summary.slipCount == 0)
          const EmptyState(
            icon: Icons.history_rounded,
            message: AppStrings.nothingInPeriod,
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
                    subtitle: Text(formatKg(summary.materials[i].grams)),
                    trailing: Text(
                      formatRs(summary.materials[i].amount),
                      style: AppTextStyles.cardAmount,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (period != HistoryPeriod.day) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(AppStrings.byDay, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final d in summary.days)
              AppCard(
                padding: EdgeInsets.zero,
                onTap: () => onOpenDay(d.dayKey),
                child: ListTile(
                  title: Text(_dayLabel(_parseDayKey(d.dayKey))),
                  subtitle: Text(
                    '${formatKg(d.grams)} • ${d.slips} ${AppStrings.entries}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatRs(d.amount),
                        style: AppTextStyles.cardAmount,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: AppSpacing.xl),
            Text(AppStrings.slipsOfDay, style: theme.textTheme.titleMedium),
            const StaffLegend(),
            const SizedBox(height: AppSpacing.sm),
            for (final p in summary.slips)
              StaffEntryCard(
                createdBy: p.createdBy,
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
                  // No cancel button here: old slips can't be cancelled (yet).
                  onTap: () => showSlipSheet(
                    context,
                    p,
                    shopName: shopName,
                    shopPhone: shopPhone,
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
