import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/application/auth_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/models.dart';

/// Builds one purchase SLIP: one customer, many items, one total.
class AddPurchaseScreen extends ConsumerStatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  final _itemFormKey = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _rate = TextEditingController();
  final _seller = TextEditingController();
  final _weightFocus = FocusNode();
  final _rateFocus = FocusNode();
  final List<PurchaseItem> _items = [];
  ScrapMaterial? _selected;
  PriceUnit _unit = PriceUnit.kg;
  bool _showMaterialError = false;
  bool _isSaving = false;

  /// Holds an item currently pulled into the editor so it can never be lost
  /// silently; restored at its original index on cancel or when switching edit.
  ({int index, PurchaseItem item})? _editing;

  @override
  void dispose() {
    _weight.dispose();
    _rate.dispose();
    _seller.dispose();
    _weightFocus.dispose();
    _rateFocus.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v > 0 ? v.toString().replaceFirst(RegExp(r'\.0$'), '') : '';

  void _select(ScrapMaterial m) {
    setState(() {
      _selected = m;
      _unit = m.priceUnit;
      _showMaterialError = false;
      _rate.text = _fmt(m.rateFor(_unit));
    });
    _weightFocus.requestFocus();
  }

  /// Switch this item between per-kg and per-paka-seer pricing; the material's
  /// fixed rate for that unit is filled in (still editable).
  void _setUnit(PriceUnit u) {
    final m = _selected;
    if (m == null) return;
    setState(() {
      _unit = u;
      _rate.text = _fmt(m.rateFor(u));
    });
  }

  int? get _grams {
    final kg = parseNumber(_weight.text);
    return kg == null ? null : (kg * 1000).round();
  }

  /// Live preview of the line being typed.
  int? get _lineTotal {
    final g = _grams;
    final r = parseNumber(_rate.text);
    final m = _selected;
    if (m == null || g == null || r == null || g <= 0 || r <= 0) return null;
    return computeAmount(g, r, _unit);
  }

  int get _slipTotal => _items.fold(0, (s, i) => s + i.amount);

  int get _slipGrams => _items.fold(0, (s, i) => s + i.weightGrams);

  bool get _hasUnsavedWork =>
      _items.isNotEmpty ||
      _editing != null ||
      _weight.text.trim().isNotEmpty ||
      _seller.text.trim().isNotEmpty;

  void _startEditItem(int index, List<ScrapMaterial> activeMaterials) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    var targetIndex = index;

    // If another item is already in edit, restore it at its original index first.
    final prev = _editing;
    if (prev != null) {
      final insertAt = prev.index.clamp(0, _items.length);
      _items.insert(insertAt, prev.item);
      if (insertAt <= targetIndex) {
        targetIndex += 1;
      }
      _editing = null;
    }

    if (targetIndex < 0 || targetIndex >= _items.length) return;
    final item = _items.removeAt(targetIndex);

    final matched = activeMaterials
        .where((m) => m.id == item.materialId)
        .firstOrNull;
    final fallback = ScrapMaterial(
      id: item.materialId,
      name: item.materialName,
      rateKg: item.unit == PriceUnit.kg ? item.rate : 0,
      ratePakaSeer: item.unit == PriceUnit.pakaSeer ? item.rate : 0,
      priceUnit: item.unit,
      isActive: true,
    );

    setState(() {
      _editing = (index: targetIndex, item: item);
      _selected = matched ?? fallback;
      _unit = item.unit;
      _showMaterialError = false;
      _weight.text = _fmt(item.weightGrams / 1000);
      _rate.text = _fmt(item.rate);
    });
    _weightFocus.requestFocus();
  }

  void _cancelEdit() {
    final current = _editing;
    if (current == null) return;
    setState(() {
      final insertAt = current.index.clamp(0, _items.length);
      _items.insert(insertAt, current.item);
      _editing = null;
      _selected = null;
      _showMaterialError = false;
    });
    _itemFormKey.currentState?.reset();
    _weight.clear();
    _rate.clear();
    FocusScope.of(context).unfocus();
  }

  void _removeItemWithUndo(int index) {
    if (index < 0 || index >= _items.length) return;
    final removed = _items[index];
    setState(() {
      _items.removeAt(index);
      final currentEdit = _editing;
      if (currentEdit != null && index < currentEdit.index) {
        _editing = (index: currentEdit.index - 1, item: currentEdit.item);
      }
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${removed.materialName}: ${AppStrings.itemRemoved}'),
          action: SnackBarAction(
            label: AppStrings.undo,
            textColor: AppColors.primaryContainer,
            onPressed: () {
              if (!mounted) return;
              setState(() {
                final insertAt = index.clamp(0, _items.length);
                _items.insert(insertAt, removed);
                final currentEdit = _editing;
                if (currentEdit != null && insertAt <= currentEdit.index) {
                  _editing = (
                    index: currentEdit.index + 1,
                    item: currentEdit.item,
                  );
                }
              });
            },
          ),
        ),
      );
  }

  void _addItem() {
    final okForm = _itemFormKey.currentState!.validate();
    if (_selected == null) setState(() => _showMaterialError = true);
    if (!okForm || _selected == null) return;

    final m = _selected!;
    final grams = _grams!;
    final rate = parseNumber(_rate.text)!;
    final item = PurchaseItem(
      materialId: m.id,
      materialName: m.name,
      weightGrams: grams,
      unit: _unit,
      rate: rate,
      amount: computeAmount(grams, rate, _unit),
    );
    setState(() {
      final currentEdit = _editing;
      if (currentEdit != null) {
        final insertAt = currentEdit.index.clamp(0, _items.length);
        _items.insert(insertAt, item);
        _editing = null;
      } else {
        _items.add(item);
      }
      _selected = null;
      _showMaterialError = false;
    });
    _itemFormKey.currentState!.reset(); // clears weight + rate fields
    _weight.clear();
    _rate.clear();
    FocusScope.of(context).unfocus();
  }

  void _saveSlip() {
    if (_isSaving) return;
    if (_editing != null || _weight.text.trim().isNotEmpty) {
      // A half-typed or in-edit item would be silently lost, so stop and tell the user.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.tapAddItemFirst)),
        );
      return;
    }
    if (_items.isEmpty) return;

    setState(() => _isSaving = true);

    ref.read(inventoryActionsProvider).addSlip(
          items: List.of(_items),
          sellerName: _seller.text,
        );

    final messenger = ScaffoldMessenger.of(context);
    final total = _slipTotal;
    context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${AppStrings.slip}: ${formatRs(total)}')),
      );
  }

  Future<void> _confirmDiscardAndPop() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.discardSlipTitle),
        content: const Text(AppStrings.discardSlipBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.keep),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              minimumSize: const Size(96, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.discardSlipAction),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(materialsProvider);
    final isOwner = ref.watch(isOwnerProvider);
    final theme = Theme.of(context);

    if (materialsAsync.isLoading && !materialsAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.newSlip)),
        body: const LoadingState(),
      );
    }

    if (materialsAsync.hasError && !materialsAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.newSlip)),
        body: const ErrorState(message: AppStrings.errGeneric),
      );
    }

    final active = (materialsAsync.value ?? const <ScrapMaterial>[])
        .where((m) => m.isActive)
        .toList();

    if (active.isEmpty && _items.isEmpty && _editing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.newSlip)),
        body: EmptyState(
          icon: Icons.category_outlined,
          message: AppStrings.addMaterialsFirst,
          actionLabel: isOwner ? AppStrings.materials : null,
          actionIcon: isOwner ? Icons.add_rounded : null,
          onAction: isOwner
              ? () => context.pushReplacement(Routes.materials)
              : null,
        ),
      );
    }

    final selected = _selected;
    final isSeer = selected != null && _unit == PriceUnit.pakaSeer;
    final lineTotal = _lineTotal;
    final grams = _grams;
    final rateNum = parseNumber(_rate.text);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final canSave = _items.isNotEmpty && _editing == null && !_isSaving;

    return PopScope(
      canPop: _isSaving || !_hasUnsavedWork,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmDiscardAndPop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.newSlip)),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ----- 1. Item Builder Card (Fast Counter Entry) -----
                    AppCard(
                      backgroundColor: _editing != null
                          ? AppColors.munshiContainer.withValues(alpha: 0.45)
                          : AppColors.surfaceCard,
                      borderColor: _editing != null
                          ? AppColors.munshiAccent
                          : AppColors.outline,
                      borderWidth: _editing != null ? 1.5 : 1.0,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _editing != null
                                    ? Icons.edit_note_rounded
                                    : Icons.scale_outlined,
                                size: 22,
                                color: _editing != null
                                    ? AppColors.munshiAccent
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _editing != null
                                      ? '${AppStrings.editItem} #${_editing!.index + 1}'
                                      : AppStrings.selectMaterial,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: _editing != null
                                        ? AppColors.onMunshiContainer
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (_editing != null)
                                TextButton.icon(
                                  onPressed: _cancelEdit,
                                  icon: const Icon(
                                    Icons.undo_rounded,
                                    size: 18,
                                    color: AppColors.munshiAccent,
                                  ),
                                  label: const Text(
                                    AppStrings.cancelEdit,
                                    style: TextStyle(
                                      color: AppColors.onMunshiContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Material Picker Chips (48dp+ touch targets)
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final m in active)
                                _MaterialChip(
                                  material: m,
                                  isSelected: selected?.id == m.id,
                                  onTap: () => _select(m),
                                ),
                            ],
                          ),
                          if (_showMaterialError)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      AppStrings.materialRequired,
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Price Unit Selector (Kg vs Paka Seer)
                          if (selected != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              AppStrings.priceBy,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SegmentedButton<PriceUnit>(
                              segments: [
                                ButtonSegment(
                                  value: PriceUnit.kg,
                                  label: Text(
                                    selected.rateKg > 0
                                        ? '${AppStrings.perKg} (${formatRate(selected.rateKg)})'
                                        : AppStrings.perKg,
                                  ),
                                ),
                                ButtonSegment(
                                  value: PriceUnit.pakaSeer,
                                  label: Text(
                                    selected.ratePakaSeer > 0
                                        ? '${AppStrings.perPakaSeer} (${formatRate(selected.ratePakaSeer)})'
                                        : AppStrings.perPakaSeer,
                                  ),
                                ),
                              ],
                              selected: {_unit},
                              onSelectionChanged: (s) => _setUnit(s.first),
                            ),
                          ],

                          const SizedBox(height: AppSpacing.lg),

                          // Weight & Rate Form
                          Form(
                            key: _itemFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _weight,
                                  focusNode: _weightFocus,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.next,
                                  style: AppTextStyles.statNumber,
                                  onChanged: (_) => setState(() {}),
                                  onFieldSubmitted: (_) =>
                                      _rateFocus.requestFocus(),
                                  decoration: const InputDecoration(
                                    labelText: AppStrings.scaleWeight,
                                    suffixText: 'kg',
                                  ),
                                  validator: (v) {
                                    final n = parseNumber(v);
                                    return (n == null ||
                                            n <= 0 ||
                                            n > 100000)
                                        ? AppStrings.invalidNumber
                                        : null;
                                  },
                                ),

                                // Kacha-to-Paka Seer Conversion Banner
                                if (isSeer) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm + 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryContainer,
                                      borderRadius: AppRadius.brSm,
                                      border: Border.all(
                                        color: AppColors.secondary.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (grams != null && grams > 0) ...[
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.swap_horiz_rounded,
                                                size: 20,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.xs + 2,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  '${formatKg(grams)} → ${formatSeer(grams)}',
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        Text(
                                          AppStrings.kachaToPaka,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppColors
                                                    .onSecondaryContainer,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: AppSpacing.lg),

                                TextFormField(
                                  controller: _rate,
                                  focusNode: _rateFocus,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.done,
                                  style: AppTextStyles.statNumber,
                                  onChanged: (_) => setState(() {}),
                                  onFieldSubmitted: (_) => _addItem(),
                                  decoration: InputDecoration(
                                    labelText: isSeer
                                        ? AppStrings.ratePerPakaSeer
                                        : AppStrings.ratePerKg,
                                    prefixText: 'Rs ',
                                  ),
                                  validator: (v) {
                                    final n = parseNumber(v);
                                    return (n == null ||
                                            n <= 0 ||
                                            n > 100000)
                                        ? AppStrings.invalidNumber
                                        : null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Live Line Item Total Preview
                          if (lineTotal != null &&
                              selected != null &&
                              grams != null &&
                              rateNum != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm + 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: AppRadius.brSm,
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selected.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                color:
                                                    AppColors.onPrimaryContainer,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isSeer
                                              ? '${formatKg(grams)} → ${formatSeer(grams)} × ${formatRate(rateNum)}'
                                              : '${formatKg(grams)} × ${formatRate(rateNum)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppColors
                                                    .onPrimaryContainer
                                                    .withValues(alpha: 0.85),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    formatRs(lineTotal),
                                    style: AppTextStyles.statNumber.copyWith(
                                      color: AppColors.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: AppSpacing.md),

                          // Add / Update Item Button
                          OutlinedButton.icon(
                            onPressed: _addItem,
                            icon: Icon(
                              _editing != null
                                  ? Icons.check_rounded
                                  : Icons.add,
                            ),
                            label: Text(
                              _editing != null
                                  ? AppStrings.updateItem
                                  : AppStrings.addItem,
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(
                                AppSpacing.primaryButtonHeight,
                              ),
                              backgroundColor: AppColors.secondaryContainer,
                              foregroundColor: AppColors.onSecondaryContainer,
                              side: const BorderSide(
                                color: AppColors.secondary,
                                width: 1.2,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ----- 2. Items Already on This Slip -----
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _items.isEmpty
                                ? AppStrings.slipItems
                                : '${AppStrings.slipItems} (${_items.length})',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (_items.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm + 2,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              borderRadius: AppRadius.brSm,
                            ),
                            child: Text(
                              formatKg(_slipGrams),
                              style: AppTextStyles.badge.copyWith(
                                color: AppColors.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_items.isEmpty)
                      AppCard(
                        backgroundColor: AppColors.surfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.playlist_add_rounded,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                AppStrings.noItemsYet,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (var i = 0; i < _items.length; i++)
                        AppCard(
                          onTap: () => _startEditItem(i, active),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.xs,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: AppTextStyles.badge.copyWith(
                                    color: AppColors.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _items[i].materialName,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _items[i].detail,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                formatRs(_items[i].amount),
                                style: AppTextStyles.cardAmount,
                              ),
                              IconButton(
                                tooltip: AppStrings.editItem,
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: AppColors.secondary,
                                ),
                                onPressed: () => _startEditItem(i, active),
                              ),
                              IconButton(
                                tooltip: AppStrings.cancel,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _removeItemWithUndo(i),
                              ),
                            ],
                          ),
                        ),

                    const SizedBox(height: AppSpacing.xl),

                    // ----- 3. Optional Seller Name -----
                    TextField(
                      controller: _seller,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: AppStrings.sellerOptional,
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),

            // ----- 4. Sticky Footer (Always visible, even with keyboard open) -----
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border(
                  top: BorderSide(color: AppColors.outline, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    keyboardOpen ? AppSpacing.sm : AppSpacing.md,
                    AppSpacing.lg,
                    keyboardOpen ? AppSpacing.sm : AppSpacing.md,
                  ),
                  child: keyboardOpen
                      ? Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.slipTotal,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  Text(
                                    formatRs(_slipTotal),
                                    style: AppTextStyles.statNumber,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            PrimaryButton(
                              label: AppStrings.saveSlip,
                              icon: Icons.check_rounded,
                              expand: false,
                              isLoading: _isSaving,
                              onPressed: canSave ? _saveSlip : null,
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppStrings.slipTotal,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    if (_items.isNotEmpty)
                                      Text(
                                        '${_items.length} ${AppStrings.items} • ${formatKg(_slipGrams)}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                                Text(
                                  formatRs(_slipTotal),
                                  style: AppTextStyles.displayNumber,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            PrimaryButton(
                              label: AppStrings.saveSlip,
                              icon: Icons.check_rounded,
                              isLoading: _isSaving,
                              onPressed: canSave ? _saveSlip : null,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialChip extends StatelessWidget {
  const _MaterialChip({
    required this.material,
    required this.isSelected,
    required this.onTap,
  });

  final ScrapMaterial material;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final defaultRate = material.rate;
    final unitSuffix = material.priceUnit == PriceUnit.pakaSeer ? '/seer' : '';
    final labelText = defaultRate > 0
        ? '${material.name} • ${formatRate(defaultRate)}$unitSuffix'
        : material.name;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
      child: ChoiceChip(
        label: Text(labelText),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
