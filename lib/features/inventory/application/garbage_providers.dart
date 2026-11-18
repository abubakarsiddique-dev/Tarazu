import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../finance/application/finance_providers.dart' show ledgerProvider;
import '../domain/garbage_history.dart';
import '../domain/sale_models.dart' show AdjustmentReason;
import 'inventory_providers.dart' show shopIdProvider;

/// Read-only range query on `shops/{shopId}/adjustments` for `[from, to]`.
/// Uses a single-field range filter on `dayKey`, so no composite index is needed.
/// Why this is needed alongside `ledgerProvider`: `_adjustmentEventsProvider` in
/// `finance_providers.dart` is private and `LedgerEvent` does not carry `id`,
/// `note`, `createdBy`, or `pendingSync`, and existing providers must remain
/// unmodified.
final garbageAdjustmentsRangeProvider = StreamProvider.family<
  List<GarbageAdjustmentDoc>,
  ({String from, String to})
>((ref, range) {
  final shopId = ref.watch(shopIdProvider);
  final role = ref.watch(userProfileProvider).value?.role;
  if (shopId == null || role != UserRole.owner) {
    return Stream.value(const <GarbageAdjustmentDoc>[]);
  }
  return ref
      .watch(firestoreProvider)
      .collection('shops')
      .doc(shopId)
      .collection('adjustments')
      .where('dayKey', isGreaterThanOrEqualTo: range.from)
      .where('dayKey', isLessThanOrEqualTo: range.to)
      .snapshots(includeMetadataChanges: true)
      .map((snap) {
        final out = <GarbageAdjustmentDoc>[];
        for (final d in snap.docs) {
          final m = d.data();
          final reasonStr = m['reason'] as String?;
          final delta = (m['deltaGrams'] as num?)?.toInt() ?? 0;
          if (reasonStr != AdjustmentReason.garbage.name || delta >= 0) {
            continue;
          }
          out.add(
            GarbageAdjustmentDoc(
              id: d.id,
              materialId: m['materialId'] as String? ?? '',
              materialName: m['materialName'] as String? ?? '',
              deltaGrams: delta,
              dayKey: m['dayKey'] as String? ?? '',
              createdAt:
                  (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              note: m['note'] as String? ?? '',
              createdBy: m['createdBy'] as String? ?? '',
              pendingSync: d.metadata.hasPendingWrites,
            ),
          );
        }
        return out;
      });
});

/// Read-only provider combining `ledgerProvider` (for moving-average cost
/// replay) with `garbageAdjustmentsRangeProvider` (for `note`, `createdBy`,
/// `pendingSync` metadata in `[from, to]`).
final garbageHistoryProvider =
    Provider.family<AsyncValue<GarbageHistorySummary>, ({String from, String to})>((
      ref,
      range,
    ) {
      final ledgerAsync = ref.watch(ledgerProvider);
      final docsAsync = ref.watch(garbageAdjustmentsRangeProvider(range));

      if (ledgerAsync.hasError) {
        return AsyncError<GarbageHistorySummary>(
          ledgerAsync.error!,
          ledgerAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (docsAsync.hasError) {
        return AsyncError<GarbageHistorySummary>(
          docsAsync.error!,
          docsAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (!ledgerAsync.hasValue || !docsAsync.hasValue) {
        return const AsyncLoading<GarbageHistorySummary>();
      }

      return AsyncData<GarbageHistorySummary>(
        computeGarbageHistory(
          ledgerAsync.requireValue,
          from: range.from,
          to: range.to,
          docs: docsAsync.requireValue,
        ),
      );
    });
