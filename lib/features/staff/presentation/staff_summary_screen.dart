import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/application/report_providers.dart' show salesRangeProvider;
import '../../inventory/domain/history.dart';
import '../../inventory/domain/models.dart' show dayKey;
import '../application/staff_lookup.dart';
import '../domain/staff_summary.dart';
import 'staff_entry_card.dart';

String _label(HistoryPeriod p, DateTime start) {
  final from = dayKey(start);
  final to = dayKey(periodEnd(p, start));
  return p == HistoryPeriod.day ? from : '$from  to  $to';
}

/// OWNER ONLY. Who bought and sold how much in a day / week / month,
/// one card per munshi.
class StaffSummaryScreen extends ConsumerStatefulWidget {
  const StaffSummaryScreen({super.key});

  @override
  ConsumerState<StaffSummaryScreen> createState() => _StaffSummaryScreenState();
}

class _StaffSummaryScreenState extends ConsumerState<StaffSummaryScreen> {
  HistoryPeriod _period = HistoryPeriod.day;
  DateTime _start = periodStart(HistoryPeriod.day, DateTime.now());

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
    final purchases = ref.watch(purchasesRangeProvider(range));
    final sales = ref.watch(salesRangeProvider(range));
    final names = ref.watch(staffNamesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Munshi hisaab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<HistoryPeriod>(
            segments: const [
              ButtonSegment(value: HistoryPeriod.day, label: Text('Din')),
              ButtonSegment(value: HistoryPeriod.week, label: Text('Hafta')),
              ButtonSegment(value: HistoryPeriod.month, label: Text('Mahina')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => _setPeriod(s.first),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Pichla',
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
                tooltip: 'Agla',
                icon: const Icon(Icons.chevron_right),
                onPressed: _isCurrent ? null : () => _move(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (purchases.hasError || sales.hasError)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Something went wrong. Please try again.')),
            )
          else if (!purchases.hasValue || !sales.hasValue)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (names.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Abhi koi munshi nahi. "Munshi accounts" se banao.'),
              ),
            for (final r in summarizeByStaff(
              purchases: purchases.requireValue,
              sales: sales.requireValue,
              staffNames: names,
              ownerLabel: 'Owner (aap) / purani entries',
            ))
              StaffEntryCard(
                createdBy: r.uid, // '' for the owner row -> normal card
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.isOwner) Text(r.name, style: theme.textTheme.titleMedium),
                      if (r.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Is muddat mein koi entry nahi.'),
                        )
                      else ...[
                        const SizedBox(height: 4),
                        _line(theme, 'Purchase', r.boughtSlips, r.boughtGrams, r.boughtAmount),
                        const SizedBox(height: 6),
                        _line(theme, 'Sale', r.soldSlips, r.soldGrams, r.soldAmount),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _line(ThemeData theme, String label, int slips, int grams, int amount) {
    return Row(
      children: [
        Expanded(child: Text('$label  •  $slips slip  •  ${formatKg(grams)}')),
        Text(
          formatRs(amount),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
