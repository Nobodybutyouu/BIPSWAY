import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bipsway/features/admin/buildings/room_form_screen.dart';
import 'package:bipsway/models/floor.dart';
import 'package:bipsway/models/room.dart';
import 'package:bipsway/services/floor_repository.dart';
import 'package:bipsway/services/room_repository.dart';

void main() {
  const floor = Floor(
    id: 'floor-1',
    buildingId: 'building-1',
    number: 1,
    label: 'Floor 1',
    planImageUrl: 'https://example.com/floor.png',
    imageWidth: 1200,
    imageHeight: 800,
  );
  const room = Room(
    id: 'room-1',
    buildingId: 'building-1',
    floorNumber: '1',
    name: 'Room 101',
    code: '101',
    info: 'Ground Floor',
    pin: RoomPin(x: 0.5, y: 0.5),
    nameLower: 'room 101',
    codeLower: '101',
  );

  testWidgets('edit room route resolves using IDs without state.extra', (tester) async {
    const floorQuery = FloorQuery(buildingId: 'building-1', floorId: 'floor-1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          floorProvider(floorQuery).overrideWith((ref) => Stream.value(floor)),
          roomProvider('room-1').overrideWith((ref) => Stream.value(room)),
        ],
        child: const MaterialApp(
          home: RoomFormRouteScreen(
            buildingId: 'building-1',
            floorId: 'floor-1',
            roomId: 'room-1',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Room Pin Placement'), findsOneWidget);
    expect(find.text('Room 101'), findsOneWidget);
    expect(find.text('101'), findsOneWidget);
  });
}
