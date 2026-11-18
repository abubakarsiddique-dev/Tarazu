import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/application/auth_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/models.dart';

class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    ScrapMaterial? existing,
  }) async {
    final result = await showDialog<
      ({
        String name,
        double rateKg,
        double ratePakaSeer,
        double ratePiece,
        PriceUnit unit,
      })
    >(
      context: context,
      builder: (_) => _MaterialDialog(existing: existing),
    );
    if (result == null) return;
    final actions = ref.read(inventoryActionsProvider);
    if (existing == null) {
      actions.addMaterial(
        result.name,
        result.rateKg,
        result.ratePakaSeer,
        result.unit,
        ratePiece: result.ratePiece,
      );
    } else {
      actions.updateMaterial(
        existing.id,
        name: result.name,
        rateKg: result.rateKg,
        ratePakaSeer: result.ratePakaSeer,
        ratePiece: result.ratePiece,
        priceUnit: result.unit,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsProvider);
    final isOwner = ref.watch(isOwnerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.materials)),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text(AppStrings.addMaterial),
            )
          : null,
      body: materials.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      AppStrings.noMaterialsYet,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (isOwner)
                      OutlinedButton(
                        onPressed: ref
                            .read(inventoryActionsProvider)
                            .seedCommonMaterials,
                        child: const Text(AppStrings.addCommonMaterials),
                      ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.fabClearance,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final m = list[i];
              final parts = <String>[
                if (m.rateKg > 0) '${formatRate(m.rateKg)} / kg',
                if (m.ratePakaSeer > 0)
                  '${formatRate(m.ratePakaSeer)} / paka seer',
                if (m.ratePiece > 0) '${formatRate(m.ratePiece)} / piece',
              ];
              return AppCard(
                padding: EdgeInsets.zero,
                onTap: isOwner ? () => _edit(context, ref, existing: m) : null,
                child: ListTile(
                  title: Text(
                    m.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: m.isActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    parts.isEmpty ? AppStrings.rateNotSet : parts.join('  •  '),
                  ),
                  trailing: isOwner
                      ? Switch(
                          value: m.isActive,
                          onChanged: (v) => ref
                              .read(inventoryActionsProvider)
                              .updateMaterial(m.id, isActive: v),
                        )
                      : null,
                ),
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
  late final TextEditingController _rateKg;
  late final TextEditingController _rateSeer;
  late final TextEditingController _ratePiece;
  late PriceUnit _unit;

  static String _fmt(double v) =>
      v > 0 ? v.toString().replaceFirst(RegExp(r'\.0$'), '') : '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _rateKg = TextEditingController(text: _fmt(e?.rateKg ?? 0));
    _rateSeer = TextEditingController(text: _fmt(e?.ratePakaSeer ?? 0));
    _ratePiece = TextEditingController(text: _fmt(e?.ratePiece ?? 0));
    _unit = e?.priceUnit ?? PriceUnit.kg;
  }

  @override
  void dispose() {
    _name.dispose();
    _rateKg.dispose();
    _rateSeer.dispose();
    _ratePiece.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      name: _name.text.trim(),
      rateKg: parseNumber(_rateKg.text) ?? 0,
      ratePakaSeer: parseNumber(_rateSeer.text) ?? 0,
      ratePiece: parseNumber(_ratePiece.text) ?? 0,
      unit: _unit,
    ));
  }

  String? _rateValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null; // rate can be set later
    final n = parseNumber(v);
    return (n == null || n < 0 || n > 100000) ? AppStrings.invalidNumber : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? AppStrings.addMaterial
            : AppStrings.editMaterial,
      ),
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
                decoration: const InputDecoration(
                  labelText: AppStrings.materialName,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty || v.trim().length > 60)
                    ? AppStrings.fieldRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.fixedRates, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _rateKg,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: AppStrings.ratePerKg,
                ),
                validator: _rateValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _rateSeer,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: AppStrings.ratePerPakaSeer,
                ),
                validator: _rateValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _ratePiece,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: AppStrings.ratePerPiece,
                ),
                validator: _rateValidator,
              ),
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  AppStrings.kachaToPaka,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.defaultUnit, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<PriceUnit>(
                segments: const [
                  ButtonSegment(
                    value: PriceUnit.kg,
                    label: Text(AppStrings.perKg),
                  ),
                  ButtonSegment(
                    value: PriceUnit.pakaSeer,
                    label: Text(AppStrings.perPakaSeer),
                  ),
                  ButtonSegment(
                    value: PriceUnit.piece,
                    label: Text(AppStrings.perPiece),
                  ),
                ],
                selected: {_unit},
                onSelectionChanged: (s) => setState(() => _unit = s.first),
              ),
            ],
          ),
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
