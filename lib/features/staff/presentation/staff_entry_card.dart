import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/staff_lookup.dart';

const _lightBg = Color(0xFFFFF3E0);
const _lightAccent = Color(0xFFE65100);
const _darkBg = Color(0xFF4E342E);
const _darkAccent = Color(0xFFFFB74D);

/// Drop-in replacement for `Card(child: ...)` in the OWNER's lists.
/// If the entry was made by a munshi it turns orange and shows "Munshi: <name>".
/// Owner's own entries look exactly like a normal Card.
class StaffEntryCard extends ConsumerWidget {
  const StaffEntryCard({super.key, required this.createdBy, required this.child});

  final String createdBy;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(staffNameProvider(createdBy));
    if (name == null) return Card(child: child);

    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? _darkBg : _lightBg;
    final accent = dark ? _darkAccent : _lightAccent;

    return Card(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(Icons.badge_outlined, size: 16, color: accent),
                const SizedBox(width: 6),
                Text(
                  'Munshi: $name',
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Small legend for the owner's home screen. Hidden when there are no munshis.
class StaffLegend extends ConsumerWidget {
  const StaffLegend({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(staffNamesProvider).isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? _darkAccent : _lightAccent;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: dark ? _darkBg : _lightBg,
              border: Border.all(color: accent),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Orange = munshi ki entry (buy ya sell)')),
        ],
      ),
    );
  }
}
