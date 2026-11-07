import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/format.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/models.dart';
import '../../inventory/domain/sale_strings.dart';

/// Set to false if the munshi should not even see his own entries of today.
const bool kMunshiSeesOwnTodayList = true;

/// Home screen for a MUNSHI. By design it has:
///  - NO today total, NO history, NO reports / profit
///  - NO owner name, NO shop phone, NO other munshi
///  - only the munshi's OWN purchases and sales (detail per slip)
class MunshiHomeScreen extends ConsumerWidget {
  const MunshiHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(userProfileProvider).value;
    final day = dayKey(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        // The munshi's own name, not the shop / owner details.
        title: Text(user?.ownerName ?? AppStrings.appName),
        actions: [
          IconButton(
            tooltip: AppStrings.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => context.push(Routes.addPurchase),
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.addPurchase),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => context.push(Routes.newSale),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text(SaleStrings.newSale),
          ),
          if (kMunshiSeesOwnTodayList) ...[
            const SizedBox(height: 24),
            Text('Meri purchases', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ref.watch(purchasesForDayProvider(day)).when(
                  loading: _loading,
                  error: (_, _) => const Text(AppStrings.errGeneric),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
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
                                '${formatTime(p.createdAt)} • ${p.items.length} ${AppStrings.items} • '
                                '${formatKg(p.totalWeightGrams)}'
                                '${p.sellerName.isEmpty ? '' : ' • ${p.sellerName}'}',
                              ),
                              trailing: Text(
                                formatRs(p.totalAmount),
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              onTap: () => _showLines(
                                context,
                                title: p.sellerName.isEmpty ? p.title : p.sellerName,
                                lines: [
                                  for (final i in p.items) (i.materialName, i.detail, i.amount),
                                ],
                                total: p.totalAmount,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            const SizedBox(height: 24),
            Text('Meri sales', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ref.watch(salesForDayProvider(day)).when(
                  loading: _loading,
                  error: (_, _) => const Text(AppStrings.errGeneric),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text(SaleStrings.noSalesToday)),
                      );
                    }
                    return Column(
                      children: [
                        for (final s in list)
                          Card(
                            child: ListTile(
                              title: Text(s.title),
                              subtitle: Text(
                                '${formatTime(s.createdAt)} • ${s.items.length} ${AppStrings.items} • '
                                '${formatKg(s.totalWeightGrams)}'
                                '${s.buyerName.isEmpty ? '' : ' • ${s.buyerName}'}',
                              ),
                              trailing: Text(
                                formatRs(s.totalAmount),
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              onTap: () => _showLines(
                                context,
                                title: s.buyerName.isEmpty ? s.title : s.buyerName,
                                lines: [
                                  for (final i in s.items) (i.materialName, i.detail, i.amount),
                                ],
                                total: s.totalAmount,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
          ],
        ],
      ),
    );
  }

  static Widget _loading() => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );

  /// Plain detail sheet (no shop phone / owner info, no void button).
  static void _showLines(
    BuildContext context, {
    required String title,
    required List<(String, String, int)> lines,
    required int total,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final l in lines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.$1),
                  subtitle: Text(l.$2),
                  trailing: Text(
                    formatRs(l.$3),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.total, style: theme.textTheme.titleMedium),
                  Text(
                    formatRs(total),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
