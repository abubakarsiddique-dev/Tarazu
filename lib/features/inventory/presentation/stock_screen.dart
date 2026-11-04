import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/format.dart';
import '../application/inventory_providers.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(stockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.stock)),
      body: stock.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.errGeneric)),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text(AppStrings.noStockYet));
          }
          final totalGrams = items.fold<int>(0, (sum, i) => sum + i.weightGrams);
          return ListView(
            children: [
              ListTile(
                title: const Text(AppStrings.totalStock),
                trailing: Text(
                  formatKg(totalGrams),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              for (final i in items)
                ListTile(
                  title: Text(i.materialName),
                  trailing: Text(formatKg(i.weightGrams), style: Theme.of(context).textTheme.titleMedium),
                ),
            ],
          );
        },
      ),
    );
  }
}
