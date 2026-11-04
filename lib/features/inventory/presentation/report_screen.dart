import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/format.dart';
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
  static const notProfit = 'Not profit: stock you have not sold yet is not counted.';
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
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text(ReportStrings.error)),
      );
    } else if (!purchasesAsync.hasValue || !salesAsync.hasValue) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      final p = summarizeHistory(purchasesAsync.requireValue);
      final s = summarizeSales(salesAsync.requireValue);
      final diff = s.totalAmount - p.totalAmount;
      final rows = combineMaterials(p, s);
      final empty = p.slipCount == 0 && s.saleCount == 0;

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalCard(
            title: ReportStrings.purchases,
            amount: formatRs(p.totalAmount),
            detail: '${formatKg(p.totalGrams)} • ${p.slipCount}',
            color: theme.colorScheme.primaryContainer,
          ),
          const SizedBox(height: 8),
          _TotalCard(
            title: ReportStrings.sales,
            amount: formatRs(s.totalAmount),
            detail: '${formatKg(s.totalGrams)} • ${s.saleCount}',
            color: theme.colorScheme.secondaryContainer,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text(ReportStrings.difference),
              subtitle: const Text(ReportStrings.notProfit),
              trailing: Text(
                '${diff < 0 ? '-' : ''}${formatRs(diff.abs())}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: diff < 0 ? theme.colorScheme.error : null,
                ),
              ),
            ),
          ),
          if (empty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text(ReportStrings.nothing)),
            )
          else ...[
            const SizedBox(height: 20),
            Text(ReportStrings.byMaterial, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final r in rows)
                    ListTile(
                      title: Text(r.name),
                      subtitle: Text(
                        '${ReportStrings.bought}: ${formatKg(r.boughtGrams)} • ${formatRs(r.boughtAmount)}\n'
                        '${ReportStrings.sold}: ${formatKg(r.soldGrams)} • ${formatRs(r.soldAmount)}',
                      ),
                      isThreeLine: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
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
              icon: const Icon(Icons.share),
              label: const Text(ReportStrings.share),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(ReportStrings.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<HistoryPeriod>(
            segments: const [
              ButtonSegment(value: HistoryPeriod.day, label: Text(ReportStrings.day)),
              ButtonSegment(value: HistoryPeriod.week, label: Text(ReportStrings.week)),
              ButtonSegment(value: HistoryPeriod.month, label: Text(ReportStrings.month)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => _setPeriod(s.first),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: ReportStrings.previous,
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
                tooltip: ReportStrings.next,
                icon: const Icon(Icons.chevron_right),
                onPressed: _isCurrent ? null : () => _move(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.title,
    required this.amount,
    required this.detail,
    required this.color,
  });

  final String title;
  final String amount;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(detail),
                ],
              ),
            ),
            Text(
              amount,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
