import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/format.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _confirmVoid(BuildContext context, WidgetRef ref, Purchase p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.voidPurchase),
        content: const Text(AppStrings.voidBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text(AppStrings.keep)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.voidAction),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(inventoryActionsProvider).voidPurchase(p);
  }

  /// The slip, like a printed receipt.
  void _showSlip(BuildContext context, WidgetRef ref, Purchase p) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.slip, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${p.dayKey}  ${formatTime(p.createdAt)}'
                '${p.sellerName.isEmpty ? '' : '  •  ${AppStrings.seller}: ${p.sellerName}'}',
              ),
              const Divider(height: 24),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final i in p.items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(i.materialName),
                        subtitle: Text(i.detail),
                        trailing: Text(formatRs(i.amount), style: theme.textTheme.titleMedium),
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.total, style: theme.textTheme.titleMedium),
                  Text(
                    formatRs(p.totalAmount),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _confirmVoid(context, ref, p);
                      },
                      child: Text(AppStrings.voidAction, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(AppStrings.close),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(userProfileProvider).value;
    final day = dayKey(DateTime.now());
    final summary = ref.watch(dailySummaryProvider(day)).value ?? const DailySummary.empty();
    final purchases = ref.watch(purchasesForDayProvider(day));

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.shopName ?? AppStrings.appName),
        actions: [
          IconButton(
            tooltip: AppStrings.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.addPurchase),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addPurchase),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.today, style: theme.textTheme.titleMedium),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(Routes.stock),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text(AppStrings.stock),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(Routes.materials),
                  icon: const Icon(Icons.category_outlined),
                  label: const Text(AppStrings.materials),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(AppStrings.purchasesToday, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          purchases.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Text(AppStrings.errGeneric),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text(AppStrings.noPurchasesToday)),
                );
              }
              return Column(
                children: [
                  for (final p in list)
                    Card(
                      child: ListTile(
                        title: Text(p.title),
                        subtitle: Text(
                          '${p.items.length} ${AppStrings.items} • ${formatKg(p.totalWeightGrams)}'
                          '${p.sellerName.isEmpty ? '' : ' • ${p.sellerName}'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: p.pendingSync ? AppStrings.waitingToSync : AppStrings.synced,
                              child: Icon(
                                p.pendingSync ? Icons.cloud_off : Icons.cloud_done_outlined,
                                size: 18,
                                color: p.pendingSync ? theme.colorScheme.error : theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatRs(p.totalAmount),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        onTap: () => _showSlip(context, ref, p),
                        onLongPress: () => _confirmVoid(context, ref, p),
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
