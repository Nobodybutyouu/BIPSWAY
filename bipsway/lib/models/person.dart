import 'package:cloud_firestore/cloud_firestore.dart';

class Person {
  const Person({
    required this.id,
    required this.fullName,
    required this.nameLower,
    required this.position,
    required this.department,
    required this.details,
    required this.photoUrl,
  });

  final String id;
  final String fullName;
  final String nameLower;
  final String position;
  final String department;
  final String? details;
  final String? photoUrl;

  factory Person.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final name = data['fullName'] as String? ?? '';
    return Person(
      id: doc.id,
      fullName: name,
      nameLower: (data['nameLower'] as String? ?? name).toLowerCase(),
      position: data['position'] as String? ?? 'Others',
      department: data['department'] as String? ?? '',
      details: data['details'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'fullName': fullName.trim(),
        'nameLower': fullName.trim().toLowerCase(),
        'position': position.trim(),
        'department': department.trim(),
        if (details != null && details!.trim().isNotEmpty) 'details': details,
        if (photoUrl != null && photoUrl!.trim().isNotEmpty) 'photoUrl': photoUrl,
      };
}
