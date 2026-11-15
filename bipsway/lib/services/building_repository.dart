import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/building.dart';

class BuildingRepository {
  BuildingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('buildings');

  Stream<List<Building>> watchBuildings() => _collection
      .orderBy('nameLower')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Building.fromFirestore).toList());

  Stream<Building?> watchBuilding(String buildingId) => _collection
      .doc(buildingId)
      .snapshots()
      .map((snapshot) => snapshot.exists ? Building.fromFirestore(snapshot) : null);

  Future<int> countBuildings() async =>
      (await _collection.count().get()).count ?? 0;

  Future<BuildingCounts> countForBuilding(String buildingId) async {
    final floors = await _collection.doc(buildingId).collection('floors').count().get();
    final rooms = await _firestore
        .collection('rooms')
        .where('buildingId', isEqualTo: buildingId)
        .count()
        .get();
    return BuildingCounts(floors: floors.count ?? 0, rooms: rooms.count ?? 0);
  }

  Future<String> save(Building building) async {
    final reference = building.id.isEmpty ? _collection.doc() : _collection.doc(building.id);
    final data = building.toFirestore(includeUpdatedAt: true)
      ..['nameLower'] = building.name.trim().toLowerCase();
    await reference.set(data, SetOptions(merge: true));
    return reference.id;
  }

  Future<void> deleteBuilding(String buildingId) async {
    final floors = await _collection.doc(buildingId).collection('floors').get();
    final rooms = await _firestore
        .collection('rooms')
        .where('buildingId', isEqualTo: buildingId)
        .get();
    final events = await _firestore
        .collection('events')
        .where('buildingId', isEqualTo: buildingId)
        .get();
    final references = <DocumentReference<Map<String, dynamic>>>[
      ...floors.docs.map((doc) => doc.reference),
      ...rooms.docs.map((doc) => doc.reference),
      ...events.docs.map((doc) => doc.reference),
      _collection.doc(buildingId),
    ];
    await _deleteInBatches(references);
  }

  Future<void> _deleteInBatches(
    List<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    for (var index = 0; index < references.length; index += 400) {
      final batch = _firestore.batch();
      for (final reference in references.skip(index).take(400)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }
}

final buildingRepositoryProvider = Provider<BuildingRepository>(
  (ref) => BuildingRepository(),
);

final buildingsProvider = StreamProvider<List<Building>>(
  (ref) => ref.watch(buildingRepositoryProvider).watchBuildings(),
);

final buildingProvider = StreamProvider.family<Building?, String>(
  (ref, buildingId) => ref.watch(buildingRepositoryProvider).watchBuilding(buildingId),
);

final buildingCountProvider = FutureProvider<int>(
  (ref) => ref.watch(buildingRepositoryProvider).countBuildings(),
);

final buildingCountsProvider = FutureProvider.family<BuildingCounts, String>(
  (ref, buildingId) =>
      ref.watch(buildingRepositoryProvider).countForBuilding(buildingId),
);

class BuildingCounts {
  const BuildingCounts({required this.floors, required this.rooms});

  final int floors;
  final int rooms;
}
