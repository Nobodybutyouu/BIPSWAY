import 'package:cloud_firestore/cloud_firestore.dart';

enum AppRole { navigator, admin }

enum AccountStatus { active, disabled }

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.username,
    required this.fullName,
    required this.email,
    required this.affiliation,
    required this.purpose,
    required this.status,
    required this.notificationPrefs,
    required this.saveSearchHistory,
    required this.createdAt,
  });

  final String id;
  final AppRole role;
  final String username;
  final String fullName;
  final String email;
  final String affiliation;
  final String? purpose;
  final AccountStatus status;
  final Map<String, bool> notificationPrefs;
  final bool saveSearchHistory;
  final DateTime? createdAt;

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return AppUser.fromMap(snapshot.id, data);
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    final notificationPrefs = data['notificationPrefs'];
    final createdAt = data['createdAt'];
    return AppUser(
      id: id,
      role: _roleFrom(data['role']),
      username: data['username'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      affiliation: data['affiliation'] as String? ?? '',
      purpose: data['purpose'] as String?,
      status: _statusFrom(data['status']),
      notificationPrefs: {
        'mapUpdates': notificationPrefs?['mapUpdates'] as bool? ?? false,
        'campusAnnouncements':
            notificationPrefs?['campusAnnouncements'] as bool? ?? false,
      },
      saveSearchHistory: data['saveSearchHistory'] as bool? ?? true,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'role': role.name,
      'username': username,
      'usernameLower': username.toLowerCase(),
      'fullName': fullName,
      'email': email,
      'affiliation': affiliation,
      if (purpose != null) 'purpose': purpose,
      'status': status.name,
      'notificationPrefs': notificationPrefs,
      'saveSearchHistory': saveSearchHistory,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  static AppRole _roleFrom(Object? value) {
    return value == AppRole.admin.name ? AppRole.admin : AppRole.navigator;
  }

  static AccountStatus _statusFrom(Object? value) {
    return value == AccountStatus.disabled.name
        ? AccountStatus.disabled
        : AccountStatus.active;
  }
}
