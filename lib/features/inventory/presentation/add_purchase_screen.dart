import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/format.dart';
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
  final List<PurchaseItem> _items = [];
  ScrapMaterial? _selected;
  PriceUnit _unit = PriceUnit.kg;
  bool _showMaterialError = false;

  @override
  void dispose() {
    _weight.dispose();
    _rate.dispose();
    _seller.dispose();
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
      _items.add(item);
      _selected = null;
    });
    _itemFormKey.currentState!.reset(); // clears weight + rate fields
  }

  void _saveSlip() {
    if (_weight.text.trim().isNotEmpty) {
      // A half-typed item would be silently lost, so stop and tell the user.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(AppStrings.tapAddItemFirst)));
      return;
    }
    if (_items.isEmpty) return;

    ref.read(inventoryActionsProvider).addSlip(
          items: List.of(_items),
          sellerName: _seller.text,
        );

    final messenger = ScaffoldMessenger.of(context);
    final total = _slipTotal;
    context.pop();
    messenger.showSnackBar(SnackBar(content: Text('${AppStrings.slip}: ${formatRs(total)}')));
  }

  @override
  Widget build(BuildContext context) {
    final active = (ref.watch(materialsProvider).value ?? const <ScrapMaterial>[])
        .where((m) => m.isActive)
        .toList();
    final theme = Theme.of(context);

    if (active.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.newSlip)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(AppStrings.addMaterialsFirst, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.pushReplacement(Routes.materials),
                  child: const Text(AppStrings.materials),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selected = _selected;
    final isSeer = selected != null && _unit == PriceUnit.pakaSeer;
    final lineTotal = _lineTotal;
    final grams = _grams;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.newSlip)),
      bottomNavigationBar: keyboardOpen
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppStrings.slipTotal, style: theme.textTheme.titleMedium),
                        Text(
                          formatRs(_slipTotal),
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _items.isEmpty ? null : _saveSlip,
                      child: const Text(AppStrings.saveSlip),
                    ),
                  ],
                ),
              ),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _seller,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: AppStrings.sellerOptional),
            ),
            const SizedBox(height: 20),

            // ----- lines already on the slip -----
            Text(AppStrings.slipItems, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(AppStrings.noItemsYet),
              )
            else
              for (var i = 0; i < _items.length; i++)
                Card(
                  child: ListTile(
                    title: Text(_items[i].materialName),
                    subtitle: Text(_items[i].detail),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatRs(_items[i].amount),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          tooltip: AppStrings.cancel,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _items.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ),
            const Divider(height: 32),

            // ----- add another item -----
            Text(AppStrings.selectMaterial, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in active)
                  ChoiceChip(
                    label: Text(m.name),
                    selected: selected?.id == m.id,
                    onSelected: (_) => _select(m),
                  ),
              ],
            ),
            if (_showMaterialError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(AppStrings.materialRequired, style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (selected != null) ...[
              const SizedBox(height: 16),
              Text(AppStrings.priceBy, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<PriceUnit>(
                segments: [
                  ButtonSegment(
                    value: PriceUnit.kg,
                    label: Text(selected.rateKg > 0
                        ? '${AppStrings.perKg} (${formatRate(selected.rateKg)})'
                        : AppStrings.perKg),
                  ),
                  ButtonSegment(
                    value: PriceUnit.pakaSeer,
                    label: Text(selected.ratePakaSeer > 0
                        ? '${AppStrings.perPakaSeer} (${formatRate(selected.ratePakaSeer)})'
                        : AppStrings.perPakaSeer),
                  ),
                ],
                selected: {_unit},
                onSelectionChanged: (s) => _setUnit(s.first),
              ),
            ],
            const SizedBox(height: 16),
            Form(
              key: _itemFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: AppStrings.scaleWeight),
                    validator: (v) {
                      final n = parseNumber(v);
                      return (n == null || n <= 0 || n > 100000) ? AppStrings.invalidNumber : null;
                    },
                  ),
                  if (isSeer && grams != null && grams > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${formatKg(grams)} → ${formatSeer(grams)}',
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: isSeer ? AppStrings.ratePerPakaSeer : AppStrings.ratePerKg,
                    ),
                    validator: (v) {
                      final n = parseNumber(v);
                      return (n == null || n <= 0 || n > 100000) ? AppStrings.invalidNumber : null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (lineTotal != null)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${selected!.name}: ${formatRs(lineTotal)}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.addItem),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
