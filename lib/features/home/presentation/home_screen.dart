import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarazu/features/staff/presentation/munshi_home_screen.dart';

import '../../../core/constants/app_strings.dart';
import '../../staff/presentation/staff_summary_screen.dart'; 
import '../../../core/router/app_router.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/validators.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/domain/models.dart';
import '../../inventory/presentation/slip_sheet.dart';
import '../../inventory/presentation/report_screen.dart' show ReportStrings;
import '../../finance/domain/finance_strings.dart';
import '../../staff/domain/staff_strings.dart';
import '../../staff/presentation/staff_entry_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _confirmVoid(
    BuildContext context,
    WidgetRef ref,
    Purchase p,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.voidPurchase),
        content: const Text(AppStrings.voidBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.keep),
          ),
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

  /// Lets the owner set the phone number that is printed on shared slips.
  Future<void> _editShopDetails(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ShopDetailsDialog(initialPhone: user.phone),
    );
    if (result == null) return;
    ref.read(authRepositoryProvider).updatePhone(user.uid, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(userProfileProvider).value;
    final isOwner = ref.watch(isOwnerProvider);
     if (user != null && !isOwner) return const MunshiHomeScreen();
    final day = dayKey(DateTime.now());
    final summary =
        ref.watch(dailySummaryProvider(day)).value ??
        const DailySummary.empty();
    final purchases = ref.watch(purchasesForDayProvider(day));

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.shopName ?? AppStrings.appName),
        actions: [
          IconButton(
            tooltip: AppStrings.shopDetails,
            icon: const Icon(Icons.storefront_outlined),
            onPressed: user == null
                ? null
                : () => _editShopDetails(context, ref, user),
          ),
          IconButton(
            tooltip: AppStrings.logout,
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatKg(summary.totalWeightGrams)} • ${summary.entryCount} ${AppStrings.entries}',
                  ),
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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.history),
            icon: const Icon(Icons.bar_chart),
            label: const Text(AppStrings.history),
          ),
                    if (isOwner) ...[
           const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.staffSummary),
              icon: const Icon(Icons.groups_2_outlined),
              label: const Text('Munshi hisaab'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.profit),
              icon: const Icon(Icons.trending_up),
              label: const Text(FinanceStrings.profit),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.expenses),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text(FinanceStrings.expensesTitle),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.staff),
              icon: const Icon(Icons.group),
              label: const Text(StaffStrings.title),
            ),
          ],

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
                    StaffEntryCard(
                      createdBy: p.createdBy,
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
                              message: p.pendingSync
                                  ? AppStrings.waitingToSync
                                  : AppStrings.synced,
                              child: Icon(
                                p.pendingSync
                                    ? Icons.cloud_off
                                    : Icons.cloud_done_outlined,
                                size: 18,
                                color: p.pendingSync
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatRs(p.totalAmount),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => showSlipSheet(
                          context,
                          p,
                          onVoid: isOwner ? () => _confirmVoid(context, ref, p) : null,
                          shopName: user?.shopName ?? '',
                          shopPhone: user?.phone ?? '',
                        ),
                        onLongPress: isOwner ? () => _confirmVoid(context, ref, p) : null,
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

class _ShopDetailsDialog extends StatefulWidget {
  const _ShopDetailsDialog({required this.initialPhone});

  final String initialPhone;

  @override
  State<_ShopDetailsDialog> createState() => _ShopDetailsDialogState();
}

class _ShopDetailsDialogState extends State<_ShopDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_phone.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.shopDetails),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: AppStrings.shopPhone,
              ),
              validator: Validators.phoneOptional,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                AppStrings.phoneShownOnSlip,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _submit,
          child: const Text(AppStrings.save),
        ),
      ],
    );
  }
}
