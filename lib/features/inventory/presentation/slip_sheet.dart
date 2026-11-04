import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/format.dart';
import '../domain/models.dart';
import '../domain/slip_text.dart';

/// The slip, like a printed receipt, with a Share button (opens the phone's
/// share sheet, pick WhatsApp there). The cancel button shows only when
/// [onVoid] is given (Home passes it, History does not).
void showSlipSheet(
  BuildContext context,
  Purchase p, {
  VoidCallback? onVoid,
  String shopName = '',
  String shopPhone = '',
}) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.slip, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${p.dayKey}  ${formatTime(p.createdAt)}'
              '${p.sellerName.isEmpty ? '' : '  •  ${AppStrings.seller}: ${p.sellerName}'}',
            ),
            const Divider(height: 24),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final i in p.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i.materialName),
                      subtitle: Text(i.detail),
                      trailing: Text(formatRs(i.amount), style: theme.textTheme.titleMedium),
                    ),
                ],
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppStrings.total, style: theme.textTheme.titleMedium),
                Text(
                  formatRs(p.totalAmount),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: slipShareText(p, shopName: shopName, shopPhone: shopPhone)),
              ),
              icon: const Icon(Icons.share),
              label: const Text(AppStrings.shareSlip),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (onVoid != null) ...[
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onVoid();
                      },
                      child: Text(AppStrings.voidAction, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(AppStrings.close),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
