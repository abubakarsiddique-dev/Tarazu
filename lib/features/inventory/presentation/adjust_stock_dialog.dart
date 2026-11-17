import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../domain/models.dart';
import '../domain/sale_models.dart';
import '../domain/sale_strings.dart';

typedef StockAdjustmentResult = ({
  StockItem item,
  int deltaGrams,
  AdjustmentReason reason,
  String note,
  double? costPerKg,
});

/// Opens the reusable stock adjustment dialog.
/// - From [StockScreen]: pass [item] (single pre-selected material).
/// - From [HomeScreen] quick garbage entry: pass [items] (positive-stock materials
///   from `stockProvider`), `initialAdd: false`, `initialReason: AdjustmentReason.garbage`,
///   and `lockReason: true`.
Future<StockAdjustmentResult?> showAdjustStockDialog(
  BuildContext context, {
  StockItem? item,
  List<StockItem>? items,
  bool initialAdd = true,
  AdjustmentReason initialReason = AdjustmentReason.correction,
  bool lockReason = false,
}) {
  assert(
    item != null || (items != null && items.isNotEmpty),
    'Provide either a single StockItem or a non-empty list of StockItems.',
  );
  return showDialog<StockAdjustmentResult>(
    context: context,
    builder: (_) => AdjustStockDialog(
      item: item,
      items: items,
      initialAdd: initialAdd,
      initialReason: initialReason,
      lockReason: lockReason,
    ),
  );
}

class AdjustStockDialog extends StatefulWidget {
  const AdjustStockDialog({
    super.key,
    this.item,
    this.items,
    this.initialAdd = true,
    this.initialReason = AdjustmentReason.correction,
    this.lockReason = false,
  });

  /// Fixed material when opened from a specific row on [StockScreen].
  final StockItem? item;

  /// Selectable materials when opened from the Home quick-garbage tile.
  /// No default material is preselected when [item] is null.
  final List<StockItem>? items;

  final bool initialAdd;
  final AdjustmentReason initialReason;
  final bool lockReason;

  @override
  State<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<AdjustStockDialog> {
  final _form = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _note = TextEditingController();
  final _cost = TextEditingController();

  StockItem? _selectedItem;
  late bool _add;
  late AdjustmentReason _reason;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.item; // null when opened from Home quick garbage
    _add = widget.initialAdd;
    _reason = widget.initialReason;
  }

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    _cost.dispose();
    super.dispose();
  }

  static String _label(AdjustmentReason r) => switch (r) {
    AdjustmentReason.correction => SaleStrings.reasonCorrection,
    AdjustmentReason.loss => SaleStrings.reasonLoss,
    AdjustmentReason.other => SaleStrings.reasonOther,
    AdjustmentReason.garbage => SaleStrings.reasonGarbage,
    AdjustmentReason.openingStock => SaleStrings.reasonOpeningStock,
  };

  int? get _parsedGrams {
    final kg = parseNumber(_weight.text);
    if (kg == null || kg <= 0 || kg > 1000000) return null;
    return (kg * 1000).round();
  }

  bool get _canSubmit {
    if (_saving) return false;
    final selected = _selectedItem;
    if (selected == null) return false;
    final grams = _parsedGrams;
    if (grams == null) return false;
    if (!_add && grams > math.max(selected.weightGrams, 0)) return false;
    if (_reason == AdjustmentReason.openingStock) {
      final c = parseNumber(_cost.text);
      if (c == null || c < 0) return false;
    }
    return true;
  }

  void _onMaterialChanged(StockItem? next) {
    setState(() {
      _selectedItem = next;
    });
    // Re-validate immediately against the newly selected material's stock.
    _form.currentState?.validate();
  }

  void _save() {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;
    final selected = _selectedItem;
    if (selected == null) return;
    if (_add && _reason == AdjustmentReason.garbage) return;
    if (!_add && _reason == AdjustmentReason.openingStock) return;
    final grams = (parseNumber(_weight.text)! * 1000).round();
    double? costPerKg;
    if (_reason == AdjustmentReason.openingStock) {
      costPerKg = parseNumber(_cost.text);
    }
    setState(() => _saving = true);
    Navigator.of(context).pop((
      item: selected,
      deltaGrams: _add ? grams : -grams,
      reason: _reason,
      note: _note.text,
      costPerKg: costPerKg,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedItem;
    final current = selected?.weightGrams ?? 0;
    final grams = _parsedGrams;
    final notEnough =
        selected != null &&
        !_add &&
        grams != null &&
        grams > math.max(current, 0);
    final remainingGrams = selected != null && grams != null
        ? (_add ? current + grams : current - grams)
        : null;

    final reasons = _add
        ? AdjustmentReason.values
              .where((r) => r != AdjustmentReason.garbage)
              .toList()
        : AdjustmentReason.values
              .where((r) => r != AdjustmentReason.openingStock)
              .toList();

    final titleText = widget.item != null
        ? '${SaleStrings.adjustStock}: ${widget.item!.materialName}'
        : (widget.lockReason && widget.initialReason == AdjustmentReason.garbage
              ? SaleStrings.recordGarbage
              : SaleStrings.adjustStock);

    return AlertDialog(
      title: Text(titleText),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Material picker (shown when opened without a fixed item)
              if (widget.item == null && widget.items != null) ...[
                DropdownButtonFormField<StockItem>(
                  initialValue: _selectedItem,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: SaleStrings.chooseMaterial,
                  ),
                  items: [
                    for (final m in widget.items!)
                      DropdownMenuItem<StockItem>(
                        value: m,
                        child: Text(
                          '${m.materialName} (${formatKg(m.weightGrams)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving ? null : _onMaterialChanged,
                  validator: (v) =>
                      v == null ? AppStrings.materialRequired : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // 2. Current stock & live remaining stock preview (before Save)
              if (selected != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: notEnough
                        ? AppColors.errorContainer
                        : AppColors.secondaryContainer,
                    borderRadius: AppRadius.brSm,
                    border: Border.all(
                      color: notEnough
                          ? AppColors.error
                          : AppColors.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              SaleStrings.inStock,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: notEnough
                                    ? AppColors.onErrorContainer
                                    : AppColors.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            formatKg(current),
                            style: AppTextStyles.cardAmount.copyWith(
                              color: notEnough
                                  ? AppColors.onErrorContainer
                                  : AppColors.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                      if (remainingGrams != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        const Divider(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                SaleStrings.remainingStock,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: notEnough
                                      ? AppColors.error
                                      : AppColors.onSecondaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              formatKg(remainingGrams),
                              style: AppTextStyles.cardAmount.copyWith(
                                color: notEnough || remainingGrams < 0
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // 3. Add / Remove segmented toggle (hidden when locked to Garbage)
              if (!widget.lockReason) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text(SaleStrings.adjustAdd),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(SaleStrings.adjustRemove),
                    ),
                  ],
                  selected: {_add},
                  onSelectionChanged: _saving
                      ? null
                      : (s) {
                          setState(() {
                            _add = s.first;
                            if (_add && _reason == AdjustmentReason.garbage) {
                              _reason = AdjustmentReason.correction;
                            }
                            if (!_add &&
                                _reason == AdjustmentReason.openingStock) {
                              _reason = AdjustmentReason.correction;
                            }
                          });
                          _form.currentState?.validate();
                        },
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // 4. Weight (kg) input
              TextFormField(
                controller: _weight,
                autofocus: widget.item != null,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: SaleStrings.adjustWeightKg,
                ),
                onChanged: (_) {
                  setState(() {});
                  if (_selectedItem != null) {
                    _form.currentState?.validate();
                  }
                },
                validator: (v) {
                  final kg = parseNumber(v);
                  if (kg == null || kg <= 0 || kg > 1000000) {
                    return AppStrings.invalidNumber;
                  }
                  final g = (kg * 1000).round();
                  final cur = _selectedItem?.weightGrams ?? 0;
                  if (!_add && g > math.max(cur, 0)) {
                    return SaleStrings.notEnoughStock;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // 5. Reason selector (preselected and locked when lockReason is true)
              if (widget.lockReason)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ChoiceChip(
                    label: Text(_label(_reason)),
                    selected: true,
                    onSelected: null,
                  ),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final r in reasons)
                      ChoiceChip(
                        label: Text(_label(r)),
                        selected: _reason == r,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _reason = r),
                      ),
                  ],
                ),

              // 6. Cost per kg (only for openingStock)
              if (_reason == AdjustmentReason.openingStock) ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _cost,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: SaleStrings.costPerKgLabel,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final val = parseNumber(v);
                    if (val == null || val < 0) return AppStrings.invalidNumber;
                    return null;
                  },
                ),
              ],

              // 7. Note (optional)
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _note,
                enabled: !_saving,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: SaleStrings.adjustNote,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(SaleStrings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _canSubmit ? _save : null,
          child: const Text(SaleStrings.adjustSave),
        ),
      ],
    );
  }
}
