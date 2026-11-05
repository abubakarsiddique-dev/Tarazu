import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../inventory/domain/history.dart';
import '../../inventory/domain/models.dart' show dayKey;
import '../application/finance_providers.dart';
import '../domain/expense.dart';
import '../domain/finance_strings.dart';

String _label(HistoryPeriod p, DateTime start) {
  final from = dayKey(start);
  final to = dayKey(periodEnd(p, start));
  return p == HistoryPeriod.day ? from : '$from  to  $to';
}

/// Shop running costs (labour, rent, electricity, ...) for a day / week / month.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  HistoryPeriod _period = HistoryPeriod.month;
  DateTime _start = periodStart(HistoryPeriod.month, DateTime.now());

  bool get _isCurrent => !_start.isBefore(periodStart(_period, DateTime.now()));

  void _setPeriod(HistoryPeriod p) => setState(() {
        _period = p;
        _start = periodStart(p, _start);
      });

  void _move(int n) => setState(() => _start = shiftPeriod(_period, _start, n));

  Future<void> _confirmVoid(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(FinanceStrings.cancelExpense),
        content: const Text(FinanceStrings.cancelExpenseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(FinanceStrings.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(FinanceStrings.cancelAction),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(expenseActionsProvider).voidExpense(e);
  }

  Future<void> _openAdd() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _AddExpenseSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = (from: dayKey(_start), to: dayKey(periodEnd(_period, _start)));
    final data = ref.watch(expensesRangeProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text(FinanceStrings.expensesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text(FinanceStrings.addExpense),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
          data.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text(FinanceStrings.error)),
            ),
            data: (list) {
              final total = list.fold<int>(0, (s, e) => s + e.amount);
              final byCat = <ExpenseCategory, int>{};
              for (final e in list) {
                byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(FinanceStrings.total,
                                    style: theme.textTheme.titleSmall),
                              ),
                              Text(
                                formatRs(total),
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (byCat.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final c in ExpenseCategory.values)
                                  if (byCat[c] != null)
                                    Chip(label: Text('${c.label}  ${formatRs(byCat[c]!)}')),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text(FinanceStrings.noExpenses)),
                    )
                  else
                    for (final e in list)
                      Card(
                        child: ListTile(
                          title: Text(e.category.label),
                          subtitle: Text(
                            '${e.dayKey}${e.note.isEmpty ? '' : '  •  ${e.note}'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                e.pendingSync ? Icons.cloud_off : Icons.cloud_done_outlined,
                                size: 18,
                                color: e.pendingSync
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatRs(e.amount),
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                tooltip: FinanceStrings.cancelAction,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmVoid(e),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet();

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.labour;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  static int? _parse(String? v) => int.tryParse((v ?? '').trim().replaceAll(',', ''));

  void _save() {
    if (!_form.currentState!.validate()) return;
    ref.read(expenseActionsProvider).add(
          amount: _parse(_amount.text)!,
          category: _category,
          note: _note.text,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(FinanceStrings.addExpense, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: FinanceStrings.amount),
                validator: (v) {
                  final n = _parse(v);
                  return (n == null || n <= 0 || n > 10000000)
                      ? FinanceStrings.amountInvalid
                      : null;
                },
              ),
              const SizedBox(height: 16),
              Text(FinanceStrings.category, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in ExpenseCategory.values)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                maxLength: 200,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: FinanceStrings.noteOptional),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text(FinanceStrings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
