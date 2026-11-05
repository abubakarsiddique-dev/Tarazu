import '../../inventory/domain/models.dart';
import '../../inventory/domain/sale_models.dart';

/// Purchases and sales of ONE person (a munshi, or the owner) for a period.
class StaffTotals {
  const StaffTotals({
    required this.uid,
    required this.name,
    required this.isOwner,
    required this.boughtSlips,
    required this.boughtAmount,
    required this.boughtGrams,
    required this.soldSlips,
    required this.soldAmount,
    required this.soldGrams,
  });

  /// Empty string for the owner row.
  final String uid;
  final String name;
  final bool isOwner;
  final int boughtSlips;
  final int boughtAmount;
  final int boughtGrams;
  final int soldSlips;
  final int soldAmount;
  final int soldGrams;

  bool get isEmpty => boughtSlips == 0 && soldSlips == 0;
}

class _Acc {
  int bs = 0, ba = 0, bg = 0, ss = 0, sa = 0, sg = 0;
}

/// Pure function (no Firebase). Every munshi in [staffNames] gets a row (even
/// with zero entries). Everything else (owner's own entries, old entries
/// without `createdBy`) goes to one "Owner" row at the end.
/// Pass only non-voided slips (the repository already filters voided ones).
List<StaffTotals> summarizeByStaff({
  required List<Purchase> purchases,
  required List<Sale> sales,
  required Map<String, String> staffNames,
  String ownerLabel = 'Owner',
}) {
  final acc = <String, _Acc>{for (final uid in staffNames.keys) uid: _Acc()};
  final owner = _Acc();

  _Acc pick(String createdBy) => acc[createdBy] ?? owner;

  for (final p in purchases) {
    final a = pick(p.createdBy);
    a.bs += 1;
    a.ba += p.totalAmount;
    a.bg += p.totalWeightGrams;
  }
  for (final s in sales) {
    final a = pick(s.createdBy);
    a.ss += 1;
    a.sa += s.totalAmount;
    a.sg += s.totalWeightGrams;
  }

  StaffTotals build(String uid, String name, bool isOwner, _Acc a) => StaffTotals(
        uid: uid,
        name: name,
        isOwner: isOwner,
        boughtSlips: a.bs,
        boughtAmount: a.ba,
        boughtGrams: a.bg,
        soldSlips: a.ss,
        soldAmount: a.sa,
        soldGrams: a.sg,
      );

  final rows = [
    for (final e in staffNames.entries) build(e.key, e.value, false, acc[e.key]!),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  rows.add(build('', ownerLabel, true, owner));
  return rows;
}
