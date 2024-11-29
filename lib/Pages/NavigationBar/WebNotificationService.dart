import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';

class WebNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final WebNotificationService _instance =
      WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();
  // Store listeners so we can cancel them

  StreamSubscription? _adminStreamSubscription;
  StreamSubscription? _notificationStreamSubscription;
  StreamSubscription? _messageStreamSubscription;
  Timestamp? _lastNotificationTime;

Future<void> initialize() async {
  // Cancel any existing listeners
  await dispose();

  if (kIsWeb) {
    try {
      final permission = await html.Notification.requestPermission();
      debugPrint('Notification permission status: $permission');

      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        try {
          String? token = await _firebaseMessaging.getToken(
            vapidKey: 'BDlwNgXhcR3MoWCErPq9Vltih9vRT_CtUGfTfk2_qCeTaY--V1d0eNB8Cv_Al0fTyEtHnVKRORvXEfUEEeFNzN4',
          );

          if (token != null) {
            await _saveDeviceToken(token);
          }
        } catch (e) {
          debugPrint('Error getting FCM token: $e');
        }

        // Set up message handler
        _messageStreamSubscription = FirebaseMessaging.onMessage.listen(
          _handleForegroundMessage,
          onError: (error) => debugPrint('Error in message stream: $error'),
        );

        // Start notification listener
        await startNotificationListener();
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }
}

  Future<void> dispose() async {
    debugPrint('Disposing notification listeners');
    await _adminStreamSubscription?.cancel();
    await _notificationStreamSubscription?.cancel();
    await _messageStreamSubscription?.cancel();
    _adminStreamSubscription = null;
    _notificationStreamSubscription = null;
    _messageStreamSubscription = null;
  }

  Future<void> _saveDeviceToken(String token) async {
    final telecomID = await _secureStorage.read(key: 'telecomID');
    if (telecomID == null) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('telecommunicationsAdmin')
          .where('telecomID', isEqualTo: telecomID)
          .get();

      if (snapshot.docs.isNotEmpty) {
        DocumentReference docRef = snapshot.docs.first.reference;
        await docRef.update({'webDeviceToken': token});
      }
    } catch (e) {
      debugPrint('Error saving web device token: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final telecomID = await _secureStorage.read(key: 'telecomID');
    if (telecomID == null) return;

    // Check Do Not Disturb status
    final adminSnapshot = await _firestore
        .collection('telecommunicationsAdmin')
        .where('telecomID', isEqualTo: telecomID)
        .get();

    if (adminSnapshot.docs.isEmpty) return;

    bool doNotDisturb = adminSnapshot.docs.first.get('doNotDisturb') ?? false;

    // Always store the notification
    await _firestore.collection('notification').add({
      'adminName': message.notification?.title ?? 'System Notification',
      'content': message.notification?.body ?? '',
      'timestamp': Timestamp.now(),
      'seenBy': [],
    });

    // Only show notification if DND is off
    if (!doNotDisturb && message.notification != null) {
      await _showWebNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
      );
    }
  }

  Future<void> _showWebNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      try {
        debugPrint('Attempting to show web notification');
        if (html.Notification.supported) {
          debugPrint('Notifications are supported');
          final String notificationPermission =
              html.Notification.permission.toString();
          debugPrint('Current permission status: $notificationPermission');

          if (notificationPermission == 'granted') {
            debugPrint(
                'Showing notification with title: $title and body: $body');
            js_util.callConstructor(
                js_util.getProperty(html.window, 'Notification'), [
              title,
              js_util.jsify({'body': body, 'icon': 'images/smsecureIcon.jpg'})
            ]);
            debugPrint('Notification should be shown now');
          } else if (notificationPermission != 'denied') {
            debugPrint('Requesting notification permission');
            final result = await html.Notification.requestPermission();
            debugPrint('Permission request result: $result');
          }
        } else {
          debugPrint('Notifications are not supported in this browser');
        }
      } catch (e) {
        debugPrint('Error showing web notification: $e');
      }
    }
  }

  // Add Firestore listener for real-time updates
Future<void> startNotificationListener() async {
  final String? telecomID = await _secureStorage.read(key: 'telecomID');
  if (telecomID == null) return;

  // Cancel existing listeners first
  await dispose();

  // Listen to admin status changes
  _adminStreamSubscription = _firestore
      .collection('telecommunicationsAdmin')
      .where('telecomID', isEqualTo: telecomID)
      .snapshots()
      .listen((adminSnapshot) async {
    if (adminSnapshot.docs.isEmpty) return;

    bool doNotDisturb = adminSnapshot.docs.first.get('doNotDisturb') ?? false;
    debugPrint('DND Status: $doNotDisturb');

    // Cancel existing notification listener
    await _notificationStreamSubscription?.cancel();

    if (!doNotDisturb) {
      _notificationStreamSubscription = _firestore
          .collection('notification')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>?;
            if (data != null) {
              try {
                // Safely handle timestamp
                final dynamic timestampData = data['timestamp'];
                final Timestamp notificationTime = timestampData is Timestamp 
                    ? timestampData 
                    : Timestamp.now();
                
                final List<dynamic> seenBy = data['seenBy'] ?? [];
                
                // Show notification if not seen
                if (!seenBy.contains(telecomID)) {
                  debugPrint('Showing notification from time: ${notificationTime.toString()}');
                  _showWebNotification(
                    title: data['adminName']?.toString() ?? 'New Notification',
                    body: data['content']?.toString() ?? '',
                  );
                }
              } catch (e) {
                debugPrint('Error processing notification: $e');
              }
            }
          }
        }
      });
    }
  });
}

  Future<void> sendNotificationToUser({
    required String telecomID,
    required String message,
    String? title,
  }) async {
    try {
      // Get admin's device token
      final adminDoc = await _firestore
          .collection('telecommunicationsAdmin')
          .where('telecomID', isEqualTo: telecomID)
          .get();

      if (adminDoc.docs.isEmpty) return;

      final String? webDeviceToken = adminDoc.docs.first.get('webDeviceToken');
      if (webDeviceToken == null) return;

      // Send FCM message
      await _firestore.collection('fcm_messages').add({
        'token': webDeviceToken,
        'notification': {
          'title': title ?? 'New Notification',
          'body': message,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }
}

Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  // Handle background messages
  print('Handling background message: ${message.messageId}');
}

void _handleMessageClick(RemoteMessage message) {
  // Handle notification clicks
  print('Notification clicked: ${message.messageId}');
}
