import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/models.dart' show dayKey;
import '../application/staff_lookup.dart';
import '../domain/staff_summary.dart';
import 'staff_entry_card.dart';

/// OWNER ONLY. Who bought and sold how much on a day, one card per munshi.
class StaffSummaryScreen extends ConsumerStatefulWidget {
  const StaffSummaryScreen({super.key});

  @override
  ConsumerState<StaffSummaryScreen> createState() => _StaffSummaryScreenState();
}

class _StaffSummaryScreenState extends ConsumerState<StaffSummaryScreen> {
  late DateTime _day = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => _day == _today();

  void _move(int n) => setState(() => _day = DateTime(_day.year, _day.month, _day.day + n));

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: _today(),
    );
    if (picked != null) setState(() => _day = DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = dayKey(_day);
    final purchases = ref.watch(purchasesForDayProvider(key));
    final sales = ref.watch(salesForDayProvider(key));
    final names = ref.watch(staffNamesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Munshi hisaab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Pichla din',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _move(-1),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _pick,
                  child: Text(
                    _isToday ? 'Aaj ($key)' : key,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Agla din',
                icon: const Icon(Icons.chevron_right),
                onPressed: _isToday ? null : () => _move(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (purchases.isLoading || sales.isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (purchases.hasError || sales.hasError)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Something went wrong. Please try again.')),
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
                          child: Text('Is din koi entry nahi.'),
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
        Expanded(
          child: Text('$label  •  $slips slip  •  ${formatKg(grams)}'),
        ),
        Text(
          formatRs(amount),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
