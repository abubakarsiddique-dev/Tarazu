import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/format.dart';
import '../application/inventory_providers.dart';
import '../domain/models.dart';

class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, {ScrapMaterial? existing}) async {
    final result = await showDialog<({String name, double rate, PriceUnit unit})>(
      context: context,
      builder: (_) => _MaterialDialog(existing: existing),
    );
    if (result == null) return;
    final actions = ref.read(inventoryActionsProvider);
    if (existing == null) {
      actions.addMaterial(result.name, result.rate, result.unit);
    } else {
      actions.updateMaterial(existing.id,
          name: result.name, rate: result.rate, priceUnit: result.unit);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.materials)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addMaterial),
      ),
      body: materials.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.errGeneric)),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(AppStrings.noMaterialsYet, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: ref.read(inventoryActionsProvider).seedCommonMaterials,
                      child: const Text(AppStrings.addCommonMaterials),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = list[i];
              final unitLabel = m.priceUnit == PriceUnit.pakaSeer ? 'paka seer' : 'kg';
              return ListTile(
                title: Text(m.name),
                subtitle: Text(m.rate > 0 ? '${formatRate(m.rate)} / $unitLabel' : AppStrings.rateNotSet),
                trailing: Switch(
                  value: m.isActive,
                  onChanged: (v) =>
                      ref.read(inventoryActionsProvider).updateMaterial(m.id, isActive: v),
                ),
                onTap: () => _edit(context, ref, existing: m),
              );
            },
          );
        },
      ),
    );
  }
}

class _MaterialDialog extends StatefulWidget {
  const _MaterialDialog({this.existing});

  final ScrapMaterial? existing;

  @override
  State<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<_MaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _rate;
  late PriceUnit _unit;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _rate = TextEditingController(
      text: (e != null && e.rate > 0) ? e.rate.toString().replaceFirst(RegExp(r'\.0$'), '') : '',
    );
    _unit = e?.priceUnit ?? PriceUnit.kg;
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      name: _name.text.trim(),
      rate: parseNumber(_rate.text) ?? 0,
      unit: _unit,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? AppStrings.addMaterial : AppStrings.editMaterial),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: AppStrings.materialName),
                validator: (v) =>
                    (v == null || v.trim().isEmpty || v.trim().length > 60) ? AppStrings.fieldRequired : null,
              ),
              const SizedBox(height: 16),
              const Text(AppStrings.rateIs),
              const SizedBox(height: 8),
              SegmentedButton<PriceUnit>(
                segments: const [
                  ButtonSegment(value: PriceUnit.kg, label: Text(AppStrings.perKg)),
                  ButtonSegment(value: PriceUnit.pakaSeer, label: Text(AppStrings.perPakaSeer)),
                ],
                selected: {_unit},
                onSelectionChanged: (s) => setState(() => _unit = s.first),
              ),
              if (_unit == PriceUnit.pakaSeer)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(AppStrings.kachaToPaka, style: TextStyle(fontSize: 12)),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _unit == PriceUnit.pakaSeer ? AppStrings.ratePerPakaSeer : AppStrings.ratePerKg,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // rate can be set later
                  final n = parseNumber(v);
                  return (n == null || n < 0 || n > 100000) ? AppStrings.invalidNumber : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(AppStrings.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _submit,
          child: const Text(AppStrings.save),
        ),
      ],
    );
  }
}
