import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/format.dart';
import '../application/inventory_providers.dart';
import '../domain/models.dart';
import '../domain/sale_models.dart';
import '../domain/sale_strings.dart';
import '../../auth/application/auth_providers.dart';

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
  final List<SaleItem> _items = [];
  String? _materialId;

  @override
  void dispose() {
    _weight.dispose();
    _rate.dispose();
    _buyer.dispose();
    super.dispose();
  }

  int get _total => _items.fold(0, (s, i) => s + i.amount);

  int? get _grams {
    final kg = parseNumber(_weight.text);
    if (kg == null || kg <= 0) return null;
    return (kg * 1000).round();
  }

  void _addItem(StockItem material, int remainingGrams) {
    if (!_form.currentState!.validate()) return;
    final grams = _grams!;
    if (grams > remainingGrams) return; // validator already shows the message
    final rate = parseNumber(_rate.text)!;
    setState(() {
      _items.add(
        SaleItem(
          materialId: material.materialId,
          materialName: material.materialName,
          weightGrams: grams,
          ratePerKg: rate,
          amount: computeAmount(grams, rate),
        ),
      );
      _materialId = null;
    });
    _weight.clear();
    _rate.clear();
  }

  void _save() {
    if (_weight.text.trim().isNotEmpty) {
      // A half-typed item would be silently lost, so stop and tell the user.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.tapAddItemFirst)),
        );
      return;
    }
    if (_items.isEmpty) return;

    ref
        .read(inventoryActionsProvider)
        .addSale(items: List.of(_items), buyerName: _buyer.text);

    final messenger = ScaffoldMessenger.of(context);
    final total = _total;
    context.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('${SaleStrings.sale}: ${formatRs(total)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = ref.watch(isOwnerProvider);
    final stock = ref.watch(stockProvider).value ?? const <StockItem>[];
    final sellable = stock
        .where((s) => remainingToSell(stock, _items, s.materialId) > 0)
        .toList();

    if (sellable.isEmpty && _items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(SaleStrings.newSale)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(SaleStrings.noStockToSell, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final selected = stock
        .where((s) => s.materialId == _materialId)
        .firstOrNull;
    final remaining = selected == null
        ? 0
        : remainingToSell(stock, _items, selected.materialId);

    return Scaffold(
      appBar: AppBar(title: const Text(SaleStrings.newSale)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _items.isEmpty ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(
              _items.isEmpty
                  ? SaleStrings.saveSale
                  : '${SaleStrings.saveSale}  •  ${formatRs(_total)}',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var n = 0; n < _items.length; n++)
            Card(
              child: ListTile(
                title: Text(_items[n].materialName),
                subtitle: Text(_items[n].detail),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatRs(_items[n].amount),
                      style: theme.textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _items.removeAt(n)),
                    ),
                  ],
                ),
              ),
            ),
          if (sellable.isNotEmpty) ...[
            Text(SaleStrings.chooseMaterial, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in sellable)
                  ChoiceChip(
                    label: Text(
                      isOwner
                          ? '${s.materialName} • ${formatKg(remainingToSell(stock, _items, s.materialId))}'
                          : s.materialName,
                    ),
                    selected: _materialId == s.materialId,
                    onSelected: (_) {
                      setState(() => _materialId = s.materialId);
                      _weight.clear();
                      _rate.clear();
                    },
                  ),
              ],
            ),
          ],
          if (selected != null) ...[
            const SizedBox(height: 16),
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: SaleStrings.sellWeightKg,
                      helperText: isOwner
                          ? '${SaleStrings.inStock}: ${formatKg(remaining)}'
                          : null,
                    ),
                    validator: (v) {
                      final kg = parseNumber(v);
                      if (kg == null || kg <= 0 || kg > 1000000)
                        return AppStrings.invalidNumber;
                      if ((kg * 1000).round() > remaining)
                        return SaleStrings.notEnoughStock;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: SaleStrings.sellRatePerKg,
                    ),
                    validator: (v) {
                      final n = parseNumber(v);
                      return (n == null || n <= 0 || n > 100000)
                          ? AppStrings.invalidNumber
                          : null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _addItem(selected, remaining),
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.addItem),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _buyer,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: SaleStrings.buyerField,
            ),
          ),
        ],
      ),
    );
  }
}
