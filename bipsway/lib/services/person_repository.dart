import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/person.dart';

class PersonRepository {
  PersonRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('personnel');

  Stream<List<Person>> watchPeople() => _collection.orderBy('nameLower').snapshots().map((snapshot) => snapshot.docs.map(Person.fromFirestore).toList());
  Stream<Person?> watchPerson(String id) => _collection.doc(id).snapshots().map((snapshot) => snapshot.exists ? Person.fromFirestore(snapshot) : null);

  Future<String> save(Person person) async {
    final reference = person.id.isEmpty ? _collection.doc() : _collection.doc(person.id);
    await reference.set(person.toFirestore(), SetOptions(merge: true));
    return reference.id;
  }

  Future<void> delete(String id) => _collection.doc(id).delete();
  Future<int> count() async => (await _collection.count().get()).count ?? 0;
}

final personRepositoryProvider = Provider<PersonRepository>((ref) => PersonRepository());
final personnelProvider = StreamProvider<List<Person>>((ref) => ref.watch(personRepositoryProvider).watchPeople());
final personProvider = StreamProvider.family<Person?, String>((ref, id) => ref.watch(personRepositoryProvider).watchPerson(id));
final personnelCountProvider = FutureProvider<int>((ref) => ref.watch(personRepositoryProvider).count());
