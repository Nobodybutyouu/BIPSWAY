import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/org_position.dart';

class OrgPositionRepository {
  OrgPositionRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('orgChart');

  Stream<List<OrgPosition>> watchPositions(String department) => _collection.where('department', isEqualTo: department).orderBy('positionTitle').snapshots().map(
        (snapshot) => snapshot.docs.map(OrgPosition.fromFirestore).toList(),
      );

  Stream<OrgPosition?> watchPosition(String id) => _collection.doc(id).snapshots().map((snapshot) => snapshot.exists ? OrgPosition.fromFirestore(snapshot) : null);

  Future<String> save(OrgPosition position) async {
    final reference = position.id.isEmpty ? _collection.doc() : _collection.doc(position.id);
    await reference.set(position.toFirestore(), SetOptions(merge: true));
    return reference.id;
  }

  Future<void> delete(String id) => _collection.doc(id).delete();
}

final orgPositionRepositoryProvider = Provider<OrgPositionRepository>((ref) => OrgPositionRepository());
final orgPositionsProvider = StreamProvider.family<List<OrgPosition>, String>((ref, department) => ref.watch(orgPositionRepositoryProvider).watchPositions(department));
final positionProvider = StreamProvider.family<OrgPosition?, String>((ref, id) => ref.watch(orgPositionRepositoryProvider).watchPosition(id));
