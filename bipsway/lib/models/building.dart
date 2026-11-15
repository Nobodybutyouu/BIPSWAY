import 'package:cloud_firestore/cloud_firestore.dart';

enum BuildingStatus { published, draft }

class Building {
  const Building({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.location,
    required this.mapImageUrl,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final GeoPoint? location;
  final String? mapImageUrl;
  final BuildingStatus status;
  final DateTime? updatedAt;

  factory Building.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final updated = data['updatedAt'];
    return Building(
      id: doc.id,
      code: data['code'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      location: data['location'] as GeoPoint?,
      mapImageUrl: data['mapImageUrl'] as String?,
      status: data['status'] == 'published'
          ? BuildingStatus.published
          : BuildingStatus.draft,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore({bool includeUpdatedAt = false}) {
    return {
      'code': code.trim(),
      'name': name.trim(),
      'description': description.trim(),
      if (location != null) 'location': location,
      if (mapImageUrl != null) 'mapImageUrl': mapImageUrl,
      'status': status.name,
      if (includeUpdatedAt) 'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
