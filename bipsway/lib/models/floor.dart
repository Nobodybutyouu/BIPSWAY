import 'package:cloud_firestore/cloud_firestore.dart';

class Floor {
  const Floor({
    required this.id,
    required this.buildingId,
    required this.number,
    required this.label,
    required this.planImageUrl,
    required this.imageWidth,
    required this.imageHeight,
  });

  final String id;
  final String buildingId;
  final int number;
  final String label;
  final String? planImageUrl;
  final double? imageWidth;
  final double? imageHeight;

  factory Floor.fromFirestore(
    String buildingId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return Floor(
      id: doc.id,
      buildingId: buildingId,
      number: (data['number'] as num?)?.toInt() ?? 1,
      label: data['label'] as String? ?? 'Floor 1',
      planImageUrl: data['planImageUrl'] as String?,
      imageWidth: (data['imageWidth'] as num?)?.toDouble(),
      imageHeight: (data['imageHeight'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'number': number,
        'label': label.trim(),
        if (planImageUrl != null) 'planImageUrl': planImageUrl,
        if (imageWidth != null) 'imageWidth': imageWidth,
        if (imageHeight != null) 'imageHeight': imageHeight,
      };

  Floor copyWith({
    String? planImageUrl,
    double? imageWidth,
    double? imageHeight,
  }) {
    return Floor(
      id: id,
      buildingId: buildingId,
      number: number,
      label: label,
      planImageUrl: planImageUrl ?? this.planImageUrl,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }
}
