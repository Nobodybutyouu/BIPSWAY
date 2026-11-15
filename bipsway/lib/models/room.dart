import 'package:cloud_firestore/cloud_firestore.dart';

class RoomPin {
  const RoomPin({required this.x, required this.y});

  final double x;
  final double y;

  factory RoomPin.fromMap(Object? value) {
    final data = value is Map ? value : const <String, dynamic>{};
    return RoomPin(
      x: (((data['x'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0)).toDouble(),
      y: (((data['y'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0)).toDouble(),
    );
  }

  Map<String, double> toMap() => {
        'x': x.clamp(0.0, 1.0).toDouble(),
        'y': y.clamp(0.0, 1.0).toDouble(),
      };
}

class Room {
  const Room({
    required this.id,
    required this.buildingId,
    required this.floorNumber,
    required this.name,
    required this.code,
    required this.info,
    required this.pin,
    required this.nameLower,
    required this.codeLower,
  });

  final String id;
  final String buildingId;
  final String floorNumber;
  final String name;
  final String code;
  final String info;
  final RoomPin pin;
  final String nameLower;
  final String codeLower;

  factory Room.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final name = data['name'] as String? ?? '';
    final code = data['code'] as String? ?? '';
    return Room(
      id: doc.id,
      buildingId: data['buildingId'] as String? ?? '',
      floorNumber: data['floorNumber']?.toString() ?? '1',
      name: name,
      code: code,
      info: data['info'] as String? ?? '',
      pin: RoomPin.fromMap(data['pin']),
      nameLower: (data['nameLower'] as String? ?? name).toLowerCase(),
      codeLower: (data['codeLower'] as String? ?? code).toLowerCase(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'buildingId': buildingId,
        'floorNumber': floorNumber,
        'name': name.trim(),
        'code': code.trim(),
        'info': info.trim(),
        'pin': pin.toMap(),
        'nameLower': name.trim().toLowerCase(),
        'codeLower': code.trim().toLowerCase(),
      };
}
