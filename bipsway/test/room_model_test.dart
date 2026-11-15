import 'package:flutter_test/flutter_test.dart';

import 'package:bipsway/models/room.dart';

void main() {
  test('Room writes lowercase name and code lookup fields', () {
    const room = Room(
      id: '',
      buildingId: 'stcs',
      floorNumber: '1',
      name: 'Room T-203',
      code: 'T-203',
      info: 'Ground Floor',
      pin: RoomPin(x: 0.3, y: 0.7),
      nameLower: '',
      codeLower: '',
    );

    final data = room.toFirestore();
    expect(data['nameLower'], 'room t-203');
    expect(data['codeLower'], 't-203');
  });
}
