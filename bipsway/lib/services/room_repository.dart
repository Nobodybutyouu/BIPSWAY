import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room.dart';

class RoomRepository {
  RoomRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('rooms');

  Stream<List<Room>> watchRooms({
    required String buildingId,
    required int floorNumber,
  }) {
    return _collection
        .where('buildingId', isEqualTo: buildingId)
        .snapshots()
        .map((snapshot) {
          final rooms = snapshot.docs
              .map(Room.fromFirestore)
              .where((room) => room.floorNumber == floorNumber.toString())
              .toList();
          rooms.sort((a, b) => a.nameLower.compareTo(b.nameLower));
          return rooms;
        });
  }

  Stream<List<Room>> watchRoomsForBuilding(String buildingId) => _collection
      .where('buildingId', isEqualTo: buildingId)
      .snapshots()
      .map((snapshot) {
        final rooms = snapshot.docs.map(Room.fromFirestore).toList();
        rooms.sort((a, b) => a.nameLower.compareTo(b.nameLower));
        return rooms;
      });

  Stream<Room?> watchRoom(String roomId) => _collection.doc(roomId).snapshots().map(
        (snapshot) => snapshot.exists ? Room.fromFirestore(snapshot) : null,
      );

  Future<int> countRooms() async => (await _collection.count().get()).count ?? 0;

  Future<bool> codeExists({
    required String buildingId,
    required String code,
    String? excludingRoomId,
  }) async {
    final snapshot = await _collection
        .where('buildingId', isEqualTo: buildingId)
        .where('codeLower', isEqualTo: code.trim().toLowerCase())
        .limit(2)
        .get();
    return snapshot.docs.any((doc) => doc.id != excludingRoomId);
  }

  Future<String> save(Room room) async {
    if (await codeExists(
      buildingId: room.buildingId,
      code: room.code,
      excludingRoomId: room.id,
    )) {
      throw const RoomRepositoryException('That room code is already in use.');
    }
    final reference = room.id.isEmpty ? _collection.doc() : _collection.doc(room.id);
    await reference.set(room.toFirestore(), SetOptions(merge: true));
    return reference.id;
  }

  Future<void> delete(Room room) => _collection.doc(room.id).delete();
}

class RoomRepositoryException implements Exception {
  const RoomRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => RoomRepository(),
);

final roomsProvider = StreamProvider.family<List<Room>, RoomQuery>(
  (ref, query) async* {
    yield* ref.watch(roomRepositoryProvider).watchRooms(
          buildingId: query.buildingId,
          floorNumber: query.floorNumber,
        );
  },
);

final buildingRoomsProvider = StreamProvider.family<List<Room>, String>(
  (ref, buildingId) => ref.watch(roomRepositoryProvider).watchRoomsForBuilding(buildingId),
);

final roomProvider = StreamProvider.family<Room?, String>(
  (ref, roomId) => ref.watch(roomRepositoryProvider).watchRoom(roomId),
);

class RoomQuery {
  const RoomQuery({required this.buildingId, required this.floorNumber});

  final String buildingId;
  final int floorNumber;

  @override
  bool operator ==(Object other) =>
      other is RoomQuery &&
      other.buildingId == buildingId &&
      other.floorNumber == floorNumber;

  @override
  int get hashCode => Object.hash(buildingId, floorNumber);
}

final roomCountProvider = FutureProvider<int>(
  (ref) => ref.watch(roomRepositoryProvider).countRooms(),
);
