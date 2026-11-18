import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
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
import '../domain/sale_models.dart';
import '../domain/sale_strings.dart';

/// Sell stock to a bigger dealer / factory. Only materials that are in stock can
/// be picked, and a line can never be heavier than what is left in stock
/// (counting lines already on this slip).
class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  final _form = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _rate = TextEditingController();
  final _buyer = TextEditingController();
  final _weightFocus = FocusNode();
  final _rateFocus = FocusNode();
  final List<SaleItem> _items = [];
  String? _materialId;
  bool _showMaterialError = false;
  bool _isSaving = false;

  /// Holds an item currently pulled into the editor so it can never be lost
  /// silently; restored at its original index on cancel or when switching edit.
  ({int index, SaleItem item})? _editing;

  @override
  void dispose() {
    _weight.dispose();
    _rate.dispose();
    _buyer.dispose();
    _weightFocus.dispose();
    _rateFocus.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v > 0 ? v.toString().replaceFirst(RegExp(r'\.0$'), '') : '';

  int get _total => _items.fold(0, (s, i) => s + i.amount);

  int get _totalGrams => _items.fold(0, (s, i) => s + i.weightGrams);

  int? get _grams {
    final kg = parseNumber(_weight.text);
    if (kg == null || kg <= 0) return null;
    return (kg * 1000).round();
  }

  int? get _lineTotal {
    final g = _grams;
    final r = parseNumber(_rate.text);
    if (_materialId == null || g == null || r == null || g <= 0 || r <= 0) {
      return null;
    }
    return computeAmount(g, r);
  }

  bool get _hasUnsavedWork =>
      _items.isNotEmpty ||
      _editing != null ||
      _weight.text.trim().isNotEmpty ||
      _rate.text.trim().isNotEmpty ||
      _buyer.text.trim().isNotEmpty;

  void _selectMaterial(String materialId) {
    setState(() {
      _materialId = materialId;
      _showMaterialError = false;
    });
    // Re-check remainingToSell cap immediately when switching materials.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_weight.text.trim().isNotEmpty || _rate.text.trim().isNotEmpty) {
        _form.currentState?.validate();
      }
    });
    _weightFocus.requestFocus();
  }

  void _startEditItem(int index) {
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

    setState(() {
      _editing = (index: targetIndex, item: item);
      _materialId = item.materialId;
      _showMaterialError = false;
      _weight.text = _fmt(item.weightGrams / 1000);
      _rate.text = _fmt(item.ratePerKg);
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
      _materialId = null;
      _showMaterialError = false;
    });
    _form.currentState?.reset();
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

  void _addItem(StockItem? material, int remainingGrams) {
    if (material == null) {
      setState(() => _showMaterialError = true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    final grams = _grams!;
    if (grams > remainingGrams) return; // validator already shows the message
    final rate = parseNumber(_rate.text)!;
    final newItem = SaleItem(
      materialId: material.materialId,
      materialName: material.materialName,
      weightGrams: grams,
      ratePerKg: rate,
      amount: computeAmount(grams, rate),
    );
    setState(() {
      final currentEdit = _editing;
      if (currentEdit != null) {
        final insertAt = currentEdit.index.clamp(0, _items.length);
        _items.insert(insertAt, newItem);
        _editing = null;
      } else {
        _items.add(newItem);
      }
      _materialId = null;
      _showMaterialError = false;
    });
    _form.currentState?.reset();
    _weight.clear();
    _rate.clear();
    FocusScope.of(context).unfocus();
  }

  void _save() {
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

    ref
        .read(inventoryActionsProvider)
        .addSale(items: List.of(_items), buyerName: _buyer.text);

    final messenger = ScaffoldMessenger.of(context);
    final total = _total;
    context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${SaleStrings.sale}: ${formatRs(total)}')),
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
    final theme = Theme.of(context);
    final isOwner = ref.watch(isOwnerProvider);
    final stockAsync = ref.watch(stockProvider);

    if (stockAsync.isLoading && !stockAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text(SaleStrings.newSale)),
        body: const LoadingState(),
      );
    }

    if (stockAsync.hasError && !stockAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text(SaleStrings.newSale)),
        body: const ErrorState(message: AppStrings.errGeneric),
      );
    }

    final stock = stockAsync.value ?? const <StockItem>[];
    final sellable = stock
        .where((s) => remainingToSell(stock, _items, s.materialId) > 0)
        .toList();

    if (sellable.isEmpty && _items.isEmpty && _editing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(SaleStrings.newSale)),
        body: const EmptyState(
          icon: Icons.local_shipping_outlined,
          message: SaleStrings.noStockToSell,
        ),
      );
    }

    final selected = stock
        .where((s) => s.materialId == _materialId)
        .firstOrNull;
    final remaining = selected == null
        ? 0
        : remainingToSell(stock, _items, selected.materialId);
    final grams = _grams;
    final rateNum = parseNumber(_rate.text);
    final lineTotal = _lineTotal;
    final notEnough = selected != null && grams != null && grams > remaining;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final canSave = _items.isNotEmpty && _editing == null && !_isSaving;

    return PopScope(
      canPop: _isSaving || !_hasUnsavedWork,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmDiscardAndPop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text(SaleStrings.newSale)),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ----- 1. Item Builder Card -----
                    if (sellable.isNotEmpty || _editing != null)
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
                                      : Icons.local_shipping_outlined,
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
                                        : SaleStrings.chooseMaterial,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
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
                                for (final s in sellable)
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: AppSpacing.minTapTarget,
                                    ),
                                    child: ChoiceChip(
                                      label: Text(
                                        isOwner
                                            ? '${s.materialName} • ${formatKg(remainingToSell(stock, _items, s.materialId))}'
                                            : s.materialName,
                                      ),
                                      selected: _materialId == s.materialId,
                                      onSelected: (_) =>
                                          _selectMaterial(s.materialId),
                                    ),
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

                            if (selected != null) ...[
                              const SizedBox(height: AppSpacing.lg),

                              // Owner-only Stock & Remaining Preview Banner
                              if (isOwner) ...[
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
                                          : AppColors.secondary.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              SaleStrings.inStock,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: notEnough
                                                        ? AppColors
                                                              .onErrorContainer
                                                        : AppColors
                                                              .onSecondaryContainer,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            formatKg(remaining),
                                            style: AppTextStyles.cardAmount
                                                .copyWith(
                                                  color: notEnough
                                                      ? AppColors
                                                            .onErrorContainer
                                                      : AppColors
                                                            .onSecondaryContainer,
                                                ),
                                          ),
                                        ],
                                      ),
                                      if (grams != null) ...[
                                        const SizedBox(height: AppSpacing.xs),
                                        const Divider(height: AppSpacing.sm),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                SaleStrings.remainingStock,
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      color: notEnough
                                                          ? AppColors.error
                                                          : AppColors
                                                                .onSecondaryContainer,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            Text(
                                              formatKg(remaining - grams),
                                              style: AppTextStyles.cardAmount
                                                  .copyWith(
                                                    color: notEnough
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

                              Form(
                                key: _form,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                      onChanged: (_) {
                                        setState(() {});
                                        _form.currentState?.validate();
                                      },
                                      onFieldSubmitted: (_) =>
                                          _rateFocus.requestFocus(),
                                      decoration: InputDecoration(
                                        labelText: SaleStrings.sellWeightKg,
                                        suffixText: 'kg',
                                        helperText: isOwner
                                            ? '${SaleStrings.inStock}: ${formatKg(remaining)}'
                                            : null,
                                      ),
                                      validator: (v) {
                                        final kg = parseNumber(v);
                                        if (kg == null ||
                                            kg <= 0 ||
                                            kg > 1000000) {
                                          return AppStrings.invalidNumber;
                                        }
                                        if ((kg * 1000).round() > remaining) {
                                          return SaleStrings.notEnoughStock;
                                        }
                                        return null;
                                      },
                                    ),
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
                                      onFieldSubmitted: (_) =>
                                          _addItem(selected, remaining),
                                      decoration: const InputDecoration(
                                        labelText: SaleStrings.sellRatePerKg,
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

                              // Live Line Total Preview
                              if (lineTotal != null &&
                                  grams != null &&
                                  rateNum != null &&
                                  !notEnough) ...[
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
                                              selected.materialName,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    color: AppColors
                                                        .onPrimaryContainer,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${formatKg(grams)} × ${formatRate(rateNum)}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: AppColors
                                                        .onPrimaryContainer
                                                        .withValues(
                                                          alpha: 0.85,
                                                        ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        formatRs(lineTotal),
                                        style: AppTextStyles.statNumber
                                            .copyWith(
                                              color:
                                                  AppColors.onPrimaryContainer,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: AppSpacing.md),
                              OutlinedButton.icon(
                                onPressed: () => _addItem(selected, remaining),
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
                                  foregroundColor:
                                      AppColors.onSecondaryContainer,
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
                          ],
                        ),
                      ),

                    const SizedBox(height: AppSpacing.xl),

                    // ----- 2. Items Already on This Sale Slip -----
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
                              formatKg(_totalGrams),
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
                      for (var n = 0; n < _items.length; n++)
                        AppCard(
                          onTap: () => _startEditItem(n),
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
                                  '${n + 1}',
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
                                      _items[n].materialName,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _items[n].detail,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                formatRs(_items[n].amount),
                                style: AppTextStyles.cardAmount,
                              ),
                              IconButton(
                                tooltip: AppStrings.editItem,
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: AppColors.secondary,
                                ),
                                onPressed: () => _startEditItem(n),
                              ),
                              IconButton(
                                tooltip: AppStrings.cancel,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _removeItemWithUndo(n),
                              ),
                            ],
                          ),
                        ),

                    const SizedBox(height: AppSpacing.xl),

                    // ----- 3. Buyer Name (Optional) -----
                    TextField(
                      controller: _buyer,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 60,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: SaleStrings.buyerField,
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
                                    AppStrings.total,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  Text(
                                    formatRs(_total),
                                    style: AppTextStyles.statNumber,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            PrimaryButton(
                              label: SaleStrings.saveSale,
                              icon: Icons.check_rounded,
                              expand: false,
                              isLoading: _isSaving,
                              onPressed: canSave ? _save : null,
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppStrings.total,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      if (_items.isNotEmpty)
                                        Text(
                                          '${_items.length} ${AppStrings.items} • ${formatKg(_totalGrams)}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatRs(_total),
                                  style: AppTextStyles.displayNumber,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            PrimaryButton(
                              label: _items.isEmpty
                                  ? SaleStrings.saveSale
                                  : '${SaleStrings.saveSale}  •  ${formatRs(_total)}',
                              icon: Icons.check_rounded,
                              isLoading: _isSaving,
                              onPressed: canSave ? _save : null,
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
