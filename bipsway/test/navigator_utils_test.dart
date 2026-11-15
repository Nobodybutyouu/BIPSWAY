import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bipsway/core/utils/navigator_utils.dart';
import 'package:bipsway/models/building.dart';
import 'package:bipsway/models/room.dart';

void main() {
  const building = Building(
    id: 'stcs',
    code: 'STCS',
    name: 'STCS Building',
    description: '',
    location: GeoPoint(11.56285, 124.40055),
    mapImageUrl: null,
    status: BuildingStatus.published,
    updatedAt: null,
  );

  test('room search matches name and code case-insensitively', () {
    const rooms = [
      Room(id: '1', buildingId: 'stcs', floorNumber: '1', name: 'Computer Lab', code: 'T-101', info: '', pin: RoomPin(x: 0.2, y: 0.3), nameLower: 'computer lab', codeLower: 't-101'),
      Room(id: '2', buildingId: 'stcs', floorNumber: '1', name: 'Faculty Room', code: 'T-102', info: '', pin: RoomPin(x: 0.4, y: 0.5), nameLower: 'faculty room', codeLower: 't-102'),
    ];
    expect(filterRooms(rooms, 'COMPUTER').single.id, '1');
    expect(filterRooms(rooms, 't-102').single.id, '2');
    expect(filterRooms(rooms, '').length, 2);
    expect(filterRooms(rooms, 'missing'), isEmpty);
  });

  test('only published buildings with floors open', () {
    expect(shouldOpenNavigatorBuilding(building, true), isTrue);
    expect(shouldOpenNavigatorBuilding(building, false), isFalse);
    expect(shouldOpenNavigatorBuilding(building.copyWithStatus(BuildingStatus.draft), true), isFalse);
  });
}

extension on Building {
  Building copyWithStatus(BuildingStatus status) => Building(
        id: id,
        code: code,
        name: name,
        description: description,
        location: location,
        mapImageUrl: mapImageUrl,
        status: status,
        updatedAt: updatedAt,
      );
}
