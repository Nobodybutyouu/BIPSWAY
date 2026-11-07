import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

const mapUpdatesTopic = 'map_updates';
const campusAnnouncementsTopic = 'campus_announcements';

@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  // The platform displays notification payloads. Data-only processing can be
  // added here later without requiring Cloud Functions.
}

class NotificationService {
  NotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
  }

  Future<void> setTopicSubscription({
    required String topic,
    required bool enabled,
  }) async {
    if (enabled) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _messaging.subscribeToTopic(topic);
    } else {
      await _messaging.unsubscribeFromTopic(topic);
    }
  }

  Future<void> setPreference({
    required String uid,
    required String preferenceKey,
    required String topic,
    required bool enabled,
  }) async {
    await setTopicSubscription(topic: topic, enabled: enabled);
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'notificationPrefs.$preferenceKey': enabled,
    });
  }
}

class AnnouncementService {
  AnnouncementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> publish({
    required String type,
    required String title,
    required String message,
    String? buildingId,
    required String adminUid,
  }) async {
    final reference = await _firestore.collection('announcements').add({
      'type': type,
      'title': title,
      'message': message,
      ...?(buildingId == null ? null : {'buildingId': buildingId}),
      'publishedAt': FieldValue.serverTimestamp(),
      'publishedBy': adminUid,
    });
    return reference.id;
  }
}
