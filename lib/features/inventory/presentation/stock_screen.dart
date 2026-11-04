import 'dart:math' as math;

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

typedef _Adjustment = ({int deltaGrams, AdjustmentReason reason, String note});

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  Future<void> _adjust(BuildContext context, WidgetRef ref, StockItem item) async {
    final result = await showDialog<_Adjustment>(
      context: context,
      builder: (_) => _AdjustDialog(item: item),
    );
    if (result == null) return;
    ref.read(inventoryActionsProvider).adjustStock(
          materialId: item.materialId,
          materialName: item.materialName,
          deltaGrams: result.deltaGrams,
          reason: result.reason,
          note: result.note,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(stockProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.stock),
        actions: [
          IconButton(
            tooltip: SaleStrings.sales,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push(Routes.sales),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newSale),
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text(SaleStrings.sellStock),
      ),
      body: stock.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.errGeneric)),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text(AppStrings.noStockYet));
          }
          final totalGrams = items.fold<int>(0, (sum, i) => sum + i.weightGrams);
          final anyNegative = items.any((i) => i.weightGrams < 0);
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              ListTile(
                title: const Text(AppStrings.totalStock),
                trailing: Text(
                  formatKg(totalGrams),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (anyNegative)
                ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                  title: Text(
                    SaleStrings.negativeStockWarning,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const Divider(height: 1),
              for (final i in items)
                ListTile(
                  onTap: () => _adjust(context, ref, i),
                  title: Text(i.materialName),
                  trailing: Text(
                    formatKg(i.weightGrams),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: i.weightGrams < 0 ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.item});

  final StockItem item;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _form = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _note = TextEditingController();
  bool _add = true;
  AdjustmentReason _reason = AdjustmentReason.correction;

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _label(AdjustmentReason r) => switch (r) {
        AdjustmentReason.correction => SaleStrings.reasonCorrection,
        AdjustmentReason.loss => SaleStrings.reasonLoss,
        AdjustmentReason.other => SaleStrings.reasonOther,
      };

  void _save() {
    if (!_form.currentState!.validate()) return;
    final grams = (parseNumber(_weight.text)! * 1000).round();
    Navigator.of(context).pop((
      deltaGrams: _add ? grams : -grams,
      reason: _reason,
      note: _note.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.item.weightGrams;
    return AlertDialog(
      title: Text('${SaleStrings.adjustStock}: ${widget.item.materialName}'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${SaleStrings.inStock}: ${formatKg(current)}'),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text(SaleStrings.adjustAdd)),
                  ButtonSegment(value: false, label: Text(SaleStrings.adjustRemove)),
                ],
                selected: {_add},
                onSelectionChanged: (s) => setState(() => _add = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weight,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: SaleStrings.adjustWeightKg),
                validator: (v) {
                  final kg = parseNumber(v);
                  if (kg == null || kg <= 0 || kg > 1000000) return AppStrings.invalidNumber;
                  final grams = (kg * 1000).round();
                  if (!_add && grams > math.max(current, 0)) return SaleStrings.notEnoughStock;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final r in AdjustmentReason.values)
                    ChoiceChip(
                      label: Text(_label(r)),
                      selected: _reason == r,
                      onSelected: (_) => setState(() => _reason = r),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLength: 200,
                decoration: const InputDecoration(labelText: SaleStrings.adjustNote),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(SaleStrings.cancel),
        ),
        FilledButton(onPressed: _save, child: const Text(SaleStrings.adjustSave)),
      ],
    );
  }
}
