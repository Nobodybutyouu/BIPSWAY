import 'package:cloud_firestore/cloud_firestore.dart';

class AccountAdminService {
  AccountAdminService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> setAccountStatus({
    required String uid,
    required bool disabled,
  }) {
    return _firestore.collection('users').doc(uid).update({
      'status': disabled ? 'disabled' : 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveDeletion({
    required String requestId,
    required String uid,
    required String adminUid,
  }) async {
    final history = await _firestore
        .collection('users')
        .doc(uid)
        .collection('searchHistory')
        .get();
    final reports = await _firestore
        .collection('reports')
        .where('userId', isEqualTo: uid)
        .get();
    final batch = _firestore.batch();
    for (final document in history.docs) {
      batch.delete(document.reference);
    }
    for (final report in reports.docs) {
      batch.update(report.reference, {
        'userId': FieldValue.delete(),
        'username': FieldValue.delete(),
      });
    }
    batch.delete(_firestore.collection('users').doc(uid));
    batch.update(_firestore.collection('deleteRequests').doc(requestId), {
      'status': 'approved',
      'decidedAt': FieldValue.serverTimestamp(),
      'decidedBy': adminUid,
    });
    await batch.commit();
  }

  Future<void> declineDeletion({
    required String requestId,
    required String adminUid,
  }) {
    return _firestore.collection('deleteRequests').doc(requestId).update({
      'status': 'declined',
      'decidedAt': FieldValue.serverTimestamp(),
      'decidedBy': adminUid,
    });
  }
}
