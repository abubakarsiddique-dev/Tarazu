import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/format.dart';
import '../application/inventory_providers.dart';
import '../domain/history.dart';
import '../domain/models.dart';
import 'slip_sheet.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _short(DateTime d) => '${d.day} ${_monthNames[d.month - 1].substring(0, 3)}';

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
    final materials = ref.watch(materialsProvider).value ?? const <ScrapMaterial>[];
    final range = (
      from: dayKey(_start),
      to: dayKey(periodEnd(_period, _start)),
    );
    final data = ref.watch(purchasesRangeProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.history)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<HistoryPeriod>(
            segments: const [
              ButtonSegment(value: HistoryPeriod.day, label: Text(AppStrings.periodDay)),
              ButtonSegment(value: HistoryPeriod.week, label: Text(AppStrings.periodWeek)),
              ButtonSegment(value: HistoryPeriod.month, label: Text(AppStrings.periodMonth)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => _setPeriod(s.first),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: AppStrings.previous,
                icon: const Icon(Icons.chevron_left),
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
                icon: const Icon(Icons.chevron_right),
                onPressed: _isCurrent ? null : () => _move(1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text(AppStrings.allMaterials),
                  selected: _materialId == null,
                  onSelected: (_) => setState(() => _materialId = null),
                ),
                for (final m in materials) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(m.name),
                    selected: _materialId == m.id,
                    onSelected: (_) => setState(() => _materialId = m.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          data.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text(AppStrings.errGeneric)),
            ),
            data: (purchases) => _Body(
              summary: summarizeHistory(purchases, materialId: _materialId),
              period: _period,
              onOpenDay: _openDay,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary, required this.period, required this.onOpenDay});

  final HistorySummary summary;
  final HistoryPeriod period;
  final void Function(String dayKey) onOpenDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.total, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  formatRs(summary.totalAmount),
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('${formatKg(summary.totalGrams)} • ${summary.slipCount} ${AppStrings.entries}'),
              ],
            ),
          ),
        ),
        if (summary.slipCount == 0)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text(AppStrings.nothingInPeriod)),
          )
        else ...[
          const SizedBox(height: 20),
          Text(AppStrings.byMaterial, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final m in summary.materials)
                  ListTile(
                    title: Text(m.name),
                    subtitle: Text(formatKg(m.grams)),
                    trailing: Text(
                      formatRs(m.amount),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          if (period != HistoryPeriod.day) ...[
            const SizedBox(height: 20),
            Text(AppStrings.byDay, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final d in summary.days)
                    ListTile(
                      title: Text(_dayLabel(_parseDayKey(d.dayKey))),
                      subtitle: Text('${formatKg(d.grams)} • ${d.slips} ${AppStrings.entries}'),
                      trailing: Text(
                        formatRs(d.amount),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => onOpenDay(d.dayKey),
                    ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            Text(AppStrings.slipsOfDay, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final p in summary.slips)
              Card(
                child: ListTile(
                  title: Text(p.title),
                  subtitle: Text(
                    '${formatTime(p.createdAt)} • ${p.items.length} ${AppStrings.items} • '
                    '${formatKg(p.totalWeightGrams)}'
                    '${p.sellerName.isEmpty ? '' : ' • ${p.sellerName}'}',
                  ),
                  trailing: Text(
                    formatRs(p.totalAmount),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  // No cancel button here: old slips can't be cancelled (yet).
                  onTap: () => showSlipSheet(context, p),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
