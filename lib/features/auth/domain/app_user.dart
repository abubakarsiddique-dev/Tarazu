import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  owner,
  staff;

  /// Unknown or missing role falls back to the least-privileged one.
  static UserRole fromString(String? value) => UserRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => UserRole.staff,
      );
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.ownerName,
    required this.shopName,
    required this.email,
    required this.role,
    required this.shopId,
    required this.isActive,
    this.createdAt,
  });

  final String uid;
  final String ownerName;
  final String shopName;
  final String email;
  final UserRole role;
  final String shopId;
  final bool isActive;
  final DateTime? createdAt;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        ownerName: m['ownerName'] as String? ?? '',
        shopName: m['shopName'] as String? ?? '',
        email: m['email'] as String? ?? '',
        role: UserRole.fromString(m['role'] as String?),
        shopId: m['shopId'] as String? ?? '',
        // Missing flag = treated as inactive (fail closed).
        isActive: m['isActive'] as bool? ?? false,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}
