import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
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
  final cleanShopName = shopName.trim();
  final cleanShopPhone = shopPhone.trim();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ----- Receipt Header -----
              if (cleanShopName.isNotEmpty || cleanShopPhone.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cleanShopName.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs + 2),
                            Expanded(
                              child: Text(
                                cleanShopName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (cleanShopPhone.isNotEmpty) ...[
                        if (cleanShopName.isNotEmpty)
                          const SizedBox(height: 2),
                        Text(
                          '${AppStrings.tel}: $cleanShopPhone',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 22,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppStrings.slip,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${p.dayKey}  ${formatTime(p.createdAt)}'
                '${p.sellerName.isEmpty ? '' : '  •  ${AppStrings.seller}: ${p.sellerName}'}',
                style: theme.textTheme.bodyMedium,
              ),
              const Divider(height: AppSpacing.xl),

              // ----- Receipt Line Items -----
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: p.items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: AppSpacing.md),
                  itemBuilder: (_, idx) {
                    final i = p.items[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              '${idx + 1}.',
                              style: AppTextStyles.badge.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i.materialName,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  i.detail,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            formatRs(i.amount),
                            style: AppTextStyles.cardAmount,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ----- Receipt Total Banner -----
              AppCard(
                backgroundColor: AppColors.primaryContainer,
                borderColor: AppColors.primary.withValues(alpha: 0.35),
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.total,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            '${p.items.length} ${AppStrings.items} • ${formatKg(p.totalWeightGrams)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.onPrimaryContainer.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatRs(p.totalAmount),
                      style: AppTextStyles.statNumber.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ----- Share (WhatsApp) Button -----
              SecondaryButton(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: slipShareText(
                      p,
                      shopName: shopName,
                      shopPhone: shopPhone,
                    ),
                  ),
                ),
                icon: Icons.share_outlined,
                label: AppStrings.shareSlip,
              ),
              const SizedBox(height: AppSpacing.sm),

              // ----- Bottom Actions (Owner-only Void + Close) -----
              Row(
                children: [
                  if (onVoid != null) ...[
                    Expanded(
                      child: SecondaryButton(
                        isDestructive: true,
                        icon: Icons.cancel_outlined,
                        label: AppStrings.voidAction,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onVoid();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: PrimaryButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      label: AppStrings.close,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
