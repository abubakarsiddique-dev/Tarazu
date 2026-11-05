import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/auth_error_mapper.dart';
import '../../../core/utils/validators.dart';
import '../../auth/application/auth_providers.dart';
import '../application/staff_providers.dart';
import '../domain/staff_strings.dart';

/// Owner only: list of munshis, switch each on/off, add a new one.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddStaffDialog(),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(StaffStrings.created)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final staff = ref.watch(staffListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(StaffStrings.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(StaffStrings.addStaff),
      ),
      body: staff.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.errGeneric)),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(StaffStrings.rulesNote, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(StaffStrings.noStaff, textAlign: TextAlign.center),
                ),
              ),
            for (final u in list)
              Card(
                child: ListTile(
                  leading: Icon(
                    u.isActive ? Icons.person : Icons.person_off_outlined,
                    color: u.isActive ? null : theme.colorScheme.error,
                  ),
                  title: Text(u.ownerName),
                  subtitle: Text(
                    '${u.email}\n${u.isActive ? StaffStrings.active : StaffStrings.disabled}',
                  ),
                  isThreeLine: true,
                  trailing: Switch(
                    value: u.isActive,
                    onChanged: (v) =>
                        ref.read(staffRepositoryProvider).setActive(u.uid, v),
                  ),
                ),
              ),
            if (list.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(StaffStrings.switchNote, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddStaffDialog extends ConsumerStatefulWidget {
  const _AddStaffDialog();

  @override
  ConsumerState<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<_AddStaffDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final owner = ref.read(userProfileProvider).value;
    if (owner == null || owner.shopId.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(staffRepositoryProvider).createStaff(
            shopId: owner.shopId,
            shopName: owner.shopName,
            shopPhone: owner.phone,
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = mapAuthError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(StaffStrings.addStaff),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 60,
                decoration: const InputDecoration(labelText: StaffStrings.name),
                validator: Validators.requiredField,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: AppStrings.email),
                validator: Validators.email,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                decoration: InputDecoration(
                  labelText: AppStrings.password,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: Validators.password,
              ),
              const SizedBox(height: 8),
              const Text(StaffStrings.needsInternet, style: TextStyle(fontSize: 12)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text(StaffStrings.create),
        ),
      ],
    );
  }
}
