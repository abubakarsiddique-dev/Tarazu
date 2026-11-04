import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/format.dart';
import '../application/inventory_providers.dart';
import '../domain/models.dart';
import '../domain/sale_models.dart';
import '../domain/sale_strings.dart';

/// Today's sales. Like purchases, only TODAY's sales can be cancelled.
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Sale s) async {
    final theme = Theme.of(context);
    final wantsCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${SaleStrings.sale}: ${formatRs(s.totalAmount)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatTime(s.createdAt)}'
                '${s.buyerName.isEmpty ? '' : '  •  ${SaleStrings.buyerLabel}: ${s.buyerName}'}',
              ),
              const Divider(height: 24),
              for (final i in s.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.materialName),
                  subtitle: Text(i.detail),
                  trailing: Text(formatRs(i.amount)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(SaleStrings.cancelSale, style: TextStyle(color: theme.colorScheme.error)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.close),
          ),
        ],
      ),
    );
    if (wantsCancel != true || !context.mounted) return;

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(SaleStrings.cancelSaleTitle),
        content: const Text(SaleStrings.cancelSaleBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text(SaleStrings.keep)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text(SaleStrings.yesCancel)),
        ],
      ),
    );
    if (sure == true) ref.read(inventoryActionsProvider).voidSale(s);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = dayKey(DateTime.now());
    final sales = ref.watch(salesForDayProvider(day));
    final summary = ref.watch(salesDailyProvider(day)).value ?? const DailySummary.empty();

    return Scaffold(
      appBar: AppBar(title: const Text(SaleStrings.todaysSales)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newSale),
        icon: const Icon(Icons.add),
        label: const Text(SaleStrings.sellStock),
      ),
      body: sales.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.errGeneric)),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(SaleStrings.todaysSales, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      formatRs(summary.totalAmount),
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('${formatKg(summary.totalWeightGrams)} • ${summary.entryCount} ${AppStrings.entries}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text(SaleStrings.noSalesToday)),
              ),
            for (final s in list)
              Card(
                child: ListTile(
                  onTap: () => _open(context, ref, s),
                  title: Text(s.title),
                  subtitle: Text(
                    '${formatTime(s.createdAt)} • ${formatKg(s.totalWeightGrams)}'
                    '${s.buyerName.isEmpty ? '' : ' • ${s.buyerName}'}'
                    '${s.pendingSync ? ' • ${SaleStrings.waitingToSync}' : ''}',
                  ),
                  trailing: Text(formatRs(s.totalAmount), style: theme.textTheme.titleMedium),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
