import 'package:cloud_firestore/cloud_firestore.dart';

class OrgPosition {
  const OrgPosition({
    required this.id,
    required this.department,
    required this.positionTitle,
    required this.fullName,
    required this.reportsTo,
    required this.photoUrl,
  });

  final String id;
  final String department;
  final String positionTitle;
  final String fullName;
  final String? reportsTo;
  final String? photoUrl;

  factory OrgPosition.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return OrgPosition(
      id: doc.id,
      department: data['department'] as String? ?? 'STCS',
      positionTitle: data['positionTitle'] as String? ?? 'Others',
      fullName: data['fullName'] as String? ?? '',
      reportsTo: data['reportsTo'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'department': department,
        'positionTitle': positionTitle.trim(),
        'fullName': fullName.trim(),
        if (reportsTo != null && reportsTo!.isNotEmpty) 'reportsTo': reportsTo,
        if (photoUrl != null && photoUrl!.trim().isNotEmpty) 'photoUrl': photoUrl,
      };
}
