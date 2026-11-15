import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event.dart';

class EventRepository {
  EventRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('events');

  Stream<List<Event>> watchEvents() => _collection.orderBy('startAt').snapshots().map(
        (snapshot) => snapshot.docs.map(Event.fromFirestore).toList(),
      );

  Stream<Event?> watchEvent(String id) => _collection.doc(id).snapshots().map(
        (snapshot) => snapshot.exists ? Event.fromFirestore(snapshot) : null,
      );

  Future<String> save(Event event) async {
    final reference = event.id.isEmpty ? _collection.doc() : _collection.doc(event.id);
    await reference.set(event.toFirestore(includeCreatedAt: event.id.isEmpty), SetOptions(merge: true));
    return reference.id;
  }

  Future<void> delete(String id) => _collection.doc(id).delete();
  Future<int> count() async => (await _collection.count().get()).count ?? 0;
}

final eventRepositoryProvider = Provider<EventRepository>((ref) => EventRepository());
final eventsProvider = StreamProvider<List<Event>>((ref) => ref.watch(eventRepositoryProvider).watchEvents());
final eventProvider = StreamProvider.family<Event?, String>((ref, id) => ref.watch(eventRepositoryProvider).watchEvent(id));
final eventCountProvider = FutureProvider<int>((ref) => ref.watch(eventRepositoryProvider).count());
