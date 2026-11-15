import 'package:cloud_firestore/cloud_firestore.dart';

class Speaker {
  const Speaker({
    required this.name,
    required this.photoUrl,
    required this.arrivalAt,
    required this.locationFrom,
  });

  final String name;
  final String? photoUrl;
  final DateTime arrivalAt;
  final String locationFrom;

  factory Speaker.fromMap(Object? value) {
    final data = value is Map ? value : const <String, dynamic>{};
    final arrival = data['arrivalAt'];
    return Speaker(
      name: data['name'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      arrivalAt: arrival is Timestamp ? arrival.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
      locationFrom: data['locationFrom'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        if (photoUrl != null && photoUrl!.trim().isNotEmpty) 'photoUrl': photoUrl,
        'arrivalAt': Timestamp.fromDate(arrivalAt),
        'locationFrom': locationFrom.trim(),
      };
}

class Event {
  const Event({
    required this.id,
    required this.title,
    required this.coverImageUrl,
    required this.startAt,
    required this.endAt,
    required this.buildingId,
    required this.roomId,
    required this.locationLabel,
    required this.speakers,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? coverImageUrl;
  final DateTime startAt;
  final DateTime endAt;
  final String buildingId;
  final String? roomId;
  final String locationLabel;
  final List<Speaker> speakers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Event.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    DateTime readDate(String key) {
      final value = data[key];
      return value is Timestamp ? value.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
    }
    return Event(
      id: doc.id,
      title: data['title'] as String? ?? '',
      coverImageUrl: data['coverImageUrl'] as String?,
      startAt: readDate('startAt'),
      endAt: readDate('endAt'),
      buildingId: data['buildingId'] as String? ?? '',
      roomId: data['roomId'] as String?,
      locationLabel: data['locationLabel'] as String? ?? '',
      speakers: (data['speakers'] as List? ?? const []).map(Speaker.fromMap).toList(),
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] is Timestamp ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore({bool includeCreatedAt = false}) => {
        'title': title.trim(),
        if (coverImageUrl != null && coverImageUrl!.trim().isNotEmpty) 'coverImageUrl': coverImageUrl,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'buildingId': buildingId,
        if (roomId != null && roomId!.isNotEmpty) 'roomId': roomId,
        'locationLabel': locationLabel.trim(),
        'speakers': speakers.map((speaker) => speaker.toMap()).toList(),
        if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Event copyWith({
    String? title,
    String? coverImageUrl,
    DateTime? startAt,
    DateTime? endAt,
    String? buildingId,
    String? roomId,
    String? locationLabel,
    List<Speaker>? speakers,
  }) => Event(
        id: id,
        title: title ?? this.title,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        buildingId: buildingId ?? this.buildingId,
        roomId: roomId ?? this.roomId,
        locationLabel: locationLabel ?? this.locationLabel,
        speakers: speakers ?? this.speakers,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
