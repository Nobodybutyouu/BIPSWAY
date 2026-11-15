import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/floor.dart';

class FloorRepository {
  FloorRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String buildingId) =>
      _firestore.collection('buildings').doc(buildingId).collection('floors');

  Stream<List<Floor>> watchFloors(String buildingId) => _collection(buildingId)
      .orderBy('number')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Floor.fromFirestore(buildingId, doc))
          .toList());

  Stream<Floor?> watchFloor(String buildingId, String floorId) =>
      _collection(buildingId).doc(floorId).snapshots().map(
            (snapshot) => snapshot.exists
                ? Floor.fromFirestore(buildingId, snapshot)
                : null,
          );

  Future<String> save(Floor floor) async {
    final reference = floor.id.isEmpty
        ? _collection(floor.buildingId).doc()
        : _collection(floor.buildingId).doc(floor.id);
    await reference.set(floor.toFirestore(), SetOptions(merge: true));
    return reference.id;
  }

  Future<void> deleteFloor(Floor floor) async {
    final rooms = await _firestore
        .collection('rooms')
        .where('buildingId', isEqualTo: floor.buildingId)
        .where('floorNumber', isEqualTo: floor.number.toString())
        .get();
    final references = <DocumentReference<Map<String, dynamic>>>[
      ...rooms.docs.map((room) => room.reference),
      _collection(floor.buildingId).doc(floor.id),
    ];
    for (var index = 0; index < references.length; index += 400) {
      final batch = _firestore.batch();
      for (final reference in references.skip(index).take(400)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }
}

final floorRepositoryProvider = Provider<FloorRepository>(
  (ref) => FloorRepository(),
);

final floorsProvider = StreamProvider.family<List<Floor>, String>(
  (ref, buildingId) => ref.watch(floorRepositoryProvider).watchFloors(buildingId),
);

final floorProvider = StreamProvider.family<Floor?, FloorQuery>(
  (ref, query) => ref.watch(floorRepositoryProvider).watchFloor(query.buildingId, query.floorId),
);

class FloorQuery {
  const FloorQuery({required this.buildingId, required this.floorId});

  final String buildingId;
  final String floorId;

  @override
  bool operator ==(Object other) =>
      other is FloorQuery &&
      other.buildingId == buildingId &&
      other.floorId == floorId;

  @override
  int get hashCode => Object.hash(buildingId, floorId);
}
