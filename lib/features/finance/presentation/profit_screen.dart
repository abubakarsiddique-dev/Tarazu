import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../inventory/domain/history.dart';
import '../../inventory/domain/models.dart' show dayKey;
import '../application/finance_providers.dart';
import '../domain/finance_strings.dart';
import '../domain/profit.dart';

String _signed(int v) => '${v < 0 ? '-' : ''}${formatRs(v.abs())}';

String _label(HistoryPeriod p, DateTime start) {
  final from = dayKey(start);
  final to = dayKey(periodEnd(p, start));
  return p == HistoryPeriod.day ? from : '$from  to  $to';
}

/// Profit for a day / week / month: total, and for each material.
class ProfitScreen extends ConsumerStatefulWidget {
  const ProfitScreen({super.key});

  @override
  ConsumerState<ProfitScreen> createState() => _ProfitScreenState();
}

class _ProfitScreenState extends ConsumerState<ProfitScreen> {
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
    final ledger = ref.watch(ledgerProvider);
    final expenses = ref.watch(expensesRangeProvider(range)).value ?? const [];
    final expensesTotal = expenses.fold<int>(0, (s, e) => s + e.amount);

    return Scaffold(
      appBar: AppBar(title: const Text(FinanceStrings.profit)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<HistoryPeriod>(
            segments: const [
              ButtonSegment(value: HistoryPeriod.day, label: Text(FinanceStrings.day)),
              ButtonSegment(value: HistoryPeriod.week, label: Text(FinanceStrings.week)),
              ButtonSegment(value: HistoryPeriod.month, label: Text(FinanceStrings.month)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => _setPeriod(s.first),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: FinanceStrings.previous,
                icon: const Icon(Icons.chevron_left),
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
                icon: const Icon(Icons.chevron_right),
                onPressed: _isCurrent ? null : () => _move(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ledger.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text(FinanceStrings.error)),
            ),
            data: (events) {
              final r = computeProfit(events, from: range.from, to: range.to);
              return _Body(report: r, expenses: expensesTotal);
            },
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report, required this.expenses});

  final ProfitReport report;
  final int expenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = report.netProfit(expenses);
    final bad = theme.colorScheme.error;

    Widget line(String label, String value, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: bold
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                value,
                style: (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
                    ?.copyWith(fontWeight: bold ? FontWeight.bold : null, color: color),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                line(FinanceStrings.sales, formatRs(report.salesAmount)),
                line(FinanceStrings.costOfSold, '- ${formatRs(report.cost)}'),
                const Divider(),
                line(
                  FinanceStrings.grossProfit,
                  _signed(report.grossProfit),
                  bold: true,
                  color: report.grossProfit < 0 ? bad : null,
                ),
                line(FinanceStrings.stockLoss, '- ${formatRs(report.lossCost)}'),
                line(FinanceStrings.expenses, '- ${formatRs(expenses)}'),
                const Divider(),
                line(
                  FinanceStrings.netProfit,
                  _signed(net),
                  bold: true,
                  color: net < 0 ? bad : null,
                ),
              ],
            ),
          ),
        ),
        if (report.noCostGrams > 0)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                FinanceStrings.noCostWarning(formatKg(report.noCostGrams)),
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(FinanceStrings.estimateNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Text(FinanceStrings.byMaterial, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (report.materials.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text(FinanceStrings.nothing)),
          )
        else
          for (final m in report.materials) _MaterialCard(m: m),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: line(FinanceStrings.stockCostNow, formatRs(report.stockCostNow)),
          ),
        ),
      ],
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.m});

  final MaterialProfit m;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profit = m.profit;
    final margin = m.marginPercent;
    final perKg = m.profitPerKg;
    final parts = <String>[
      '${FinanceStrings.sold} ${formatKg(m.soldGrams)}',
      '${FinanceStrings.sales} ${formatRs(m.salesAmount)}',
      '${FinanceStrings.cost} ${formatRs(m.cost)}',
      if (m.garbageGrams > 0)
        '${FinanceStrings.garbage} ${formatKg(m.garbageGrams)} (${formatRs(m.garbageCost)})',
      if (m.lossCost > 0) '${FinanceStrings.stockLoss} ${formatRs(m.lossCost)}',
    ];
    return Card(
      child: ListTile(
        title: Text(m.name),
        subtitle: Text(parts.join('  •  ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _signed(profit),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: profit < 0 ? theme.colorScheme.error : null,
              ),
            ),
            if (margin != null && perKg != null)
              Text(
                '${margin.toStringAsFixed(0)}% ${FinanceStrings.margin}  •  '
                '${_signed(perKg)} ${FinanceStrings.perKg}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
