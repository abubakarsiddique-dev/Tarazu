import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/write_failures.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart' show shopIdProvider;
import '../../inventory/domain/models.dart' show dayKey;
import '../../inventory/domain/sale_models.dart' show AdjustmentReason;
import '../domain/expense.dart';
import '../domain/profit.dart';

typedef _Docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

CollectionReference<Map<String, dynamic>> _col(Ref ref, String shopId, String name) =>
    ref.watch(firestoreProvider).collection('shops').doc(shopId).collection(name);

DateTime _at(Map<String, dynamic> m) => (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

/// One event per item line of every non-voided purchase slip / sale.
List<LedgerEvent> _slipEvents(_Docs docs, LedgerKind kind) {
  final out = <LedgerEvent>[];
  for (final d in docs) {
    final m = d.data();
    if ((m['isVoided'] as bool? ?? false) == true) continue;
    final raw = m['items'];
    if (raw is! List) continue;
    final at = _at(m);
    final day = m['dayKey'] as String? ?? '';
    for (final e in raw.whereType<Map>()) {
      final i = Map<String, dynamic>.from(e);
      final id = i['materialId'] as String? ?? '';
      final grams = (i['weightGrams'] as num?)?.toInt() ?? 0;
      if (id.isEmpty || grams <= 0) continue;
      out.add(LedgerEvent(
        kind: kind,
        at: at,
        dayKey: day,
        materialId: id,
        materialName: i['materialName'] as String? ?? '',
        grams: grams,
        amount: (i['amount'] as num?)?.toInt() ?? 0,
      ));
    }
  }
  return out;
}

List<LedgerEvent> _adjustmentEvents(_Docs docs) {
  final out = <LedgerEvent>[];
  for (final d in docs) {
    final m = d.data();
    final id = m['materialId'] as String? ?? '';
    final delta = (m['deltaGrams'] as num?)?.toInt() ?? 0;
    if (id.isEmpty || delta == 0) continue;
    final reasonStr = m['reason'] as String?;
    final reason = AdjustmentReason.values.where((r) => r.name == reasonStr).firstOrNull;
    final costPerKg = (m['costPerKg'] as num?)?.toDouble() ?? 0.0;
    out.add(LedgerEvent(
      kind: LedgerKind.adjustment,
      at: _at(m),
      dayKey: m['dayKey'] as String? ?? '',
      materialId: id,
      materialName: m['materialName'] as String? ?? '',
      grams: delta,
      reason: reason,
      costPerKg: costPerKg,
    ));
  }
  return out;
}

// The average cost needs the WHOLE history (not just the period), so these
// listen to the full collections. Fine for a pilot; see CHANGES_PHASE4.md.
final _purchaseEventsProvider = StreamProvider<List<LedgerEvent>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const <LedgerEvent>[]);
  return _col(ref, shopId, 'purchases')
      .snapshots()
      .map((s) => _slipEvents(s.docs, LedgerKind.purchase));
});

final _saleEventsProvider = StreamProvider<List<LedgerEvent>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const <LedgerEvent>[]);
  return _col(ref, shopId, 'sales')
      .snapshots()
      .map((s) => _slipEvents(s.docs, LedgerKind.sale));
});

final _adjustmentEventsProvider = StreamProvider<List<LedgerEvent>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const <LedgerEvent>[]);
  return _col(ref, shopId, 'adjustments').snapshots().map((s) => _adjustmentEvents(s.docs));
});

/// Everything that moved stock, all three collections together.
final ledgerProvider = Provider<AsyncValue<List<LedgerEvent>>>((ref) {
  final parts = [
    ref.watch(_purchaseEventsProvider),
    ref.watch(_saleEventsProvider),
    ref.watch(_adjustmentEventsProvider),
  ];
  for (final p in parts) {
    if (p.hasError) {
      return AsyncError<List<LedgerEvent>>(p.error!, p.stackTrace ?? StackTrace.current);
    }
  }
  if (parts.any((p) => !p.hasValue)) return const AsyncLoading<List<LedgerEvent>>();
  return AsyncData<List<LedgerEvent>>([for (final p in parts) ...p.requireValue]);
});

/// Non-voided expenses between two day keys (inclusive). Single-field range
/// filter, so no composite index is needed.
final expensesRangeProvider =
    StreamProvider.family<List<Expense>, ({String from, String to})>((ref, range) {
  final shopId = ref.watch(shopIdProvider);
  if (shopId == null) return Stream.value(const <Expense>[]);
  return _col(ref, shopId, 'expenses')
      .where('dayKey', isGreaterThanOrEqualTo: range.from)
      .where('dayKey', isLessThanOrEqualTo: range.to)
      .snapshots(includeMetadataChanges: true)
      .map((snap) {
    final list = snap.docs
        .where((d) => (d.data()['isVoided'] as bool? ?? false) == false)
        .map(Expense.fromDoc)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

class ExpenseActions {
  ExpenseActions(this._ref);

  final Ref _ref;

  String get _shopId {
    final id = _ref.read(shopIdProvider);
    if (id == null) throw StateError('No shop for the current user');
    return id;
  }

  CollectionReference<Map<String, dynamic>> get _expenses =>
      _ref.read(firestoreProvider).collection('shops').doc(_shopId).collection('expenses');

  // Offline-first, same as the inventory repository: do not await, never swallow.
  void _send(Future<void> write) =>
      sendWrite(write, WriteKind.other, _ref.read(writeFailureProvider.notifier).report);

  void add({required int amount, required ExpenseCategory category, String note = ''}) {
    if (amount <= 0) return;
    final now = DateTime.now();
    _send(_expenses.doc().set({
      'amount': amount,
      'category': category.name,
      'note': note.trim(),
      'dayKey': dayKey(now),
      'createdAt': Timestamp.fromDate(now),
      'createdBy': _ref.read(firebaseAuthProvider).currentUser!.uid,
      'isVoided': false,
    }));
  }

  /// Keeps the record (audit trail); it just stops counting.
  void voidExpense(Expense e) => _send(_expenses.doc(e.id).update({
        'isVoided': true,
        'voidedAt': Timestamp.now(),
      }));
}

final expenseActionsProvider = Provider<ExpenseActions>((ref) => ExpenseActions(ref));
