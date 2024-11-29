import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart'; // For timestamp formatting
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:telecom_smsecure/Pages/NavigationBar/WebNotificationService.dart';
import 'package:telecom_smsecure/Pages/Profile/ProfilePage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class CustomNavigationBar extends StatefulWidget
    implements PreferredSizeWidget {
  const CustomNavigationBar({
    super.key,
  });

  @override
  State<CustomNavigationBar> createState() => _CustomNavigationBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CustomNavigationBarState extends State<CustomNavigationBar> {
  String _userName = "Unknown";
  String? _profileImageUrl;
  // Initialize secure storage instance
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _notifications = [];
  int _unreadNotificationsCount = 0;
  bool _doNotDisturb = false;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final webNotificationService = WebNotificationService();
  StreamSubscription? _notificationStreamSubscription;

  @override
  void initState() {
    super.initState();
    webNotificationService.initialize();
    webNotificationService.startNotificationListener();
    _initializeFirebaseMessaging();
    _fetchUserData();
    _fetchDoNotDisturbStatus(); // Add this line
    _setupNotificationListener(); // Add this instead of _fetchNotifications()
  }

  @override
  void dispose() {
    _notificationStreamSubscription?.cancel();
    super.dispose();
  }

  void _setupNotificationListener() {
    // Cancel any existing subscription
    _notificationStreamSubscription?.cancel();

    // Set up real-time listener
    _notificationStreamSubscription = FirebaseFirestore.instance
        .collection('notification')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) async {
      final telecomID = await _secureStorage.read(key: 'telecomID');
      if (telecomID == null) return;

      final notifications = snapshot.docs
          .map((doc) => {
                'adminName': doc['adminName'],
                'content': doc['content'],
                'timestamp': doc['timestamp'],
                'seenBy': List<dynamic>.from(doc['seenBy'] ?? []),
              })
          .toList();

      int unreadCount = notifications
          .where((notification) =>
              !(notification['seenBy'] as List<dynamic>).contains(telecomID))
          .length;

      setState(() {
        _notifications = notifications;
        _unreadNotificationsCount = unreadCount;
      });
    });
  }

Future<void> _fetchDoNotDisturbStatus() async {
  try {
    final telecomID = await _secureStorage.read(key: 'telecomID');
    if (telecomID == null) {
      debugPrint("telecomID is null");
      return;
    }

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('telecommunicationsAdmin')
        .where('telecomID', isEqualTo: telecomID)
        .get();

    if (snapshot.docs.isNotEmpty) {
      bool doNotDisturb = snapshot.docs.first.get('doNotDisturb') ?? false;
      setState(() {
        _doNotDisturb = doNotDisturb;
      });
    }
  } catch (e) {
    debugPrint('Error fetching do not disturb status: $e');
  }
}

  Future<void> _fetchUserData() async {
    try {
      // Read telecomID from secure storage
      final telecomID = await _secureStorage.read(key: 'telecomID');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('telecommunicationsAdmin')
          .where('telecomID', isEqualTo: telecomID)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        setState(() {
          _userName = userData['name'] ?? "Unknown";
          _profileImageUrl = userData['profileImageUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      setState(() {
        _userName = "Unknown";
      });
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Always fetch notifications to update the UI, but only show if DND is off
        if (!_doNotDisturb) {
          _handleNewNotification(message);
        } else {
          debugPrint(
              'Do Not Disturb is enabled - skipping notification handling');
        }
      });
    }
  }

  void _handleNewNotification(RemoteMessage message) {
    // No need to manually fetch notifications anymore
    // The stream listener will handle updates automatically
  }

  Future<void> _markAllAsRead() async {
    try {
      final telecomID = await _secureStorage.read(key: 'telecomID');
      if (telecomID == null) {
        debugPrint("telecomID is null");
        return;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Fetch all notifications
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('notification').get();

      for (DocumentSnapshot doc in querySnapshot.docs) {
        List<dynamic> seenBy = List<dynamic>.from(doc['seenBy'] ?? []);

        // Debug print before updating
        debugPrint("Notification ID: ${doc.id}, SeenBy: $seenBy");

        if (!seenBy.contains(telecomID)) {
          seenBy.add(telecomID); // Add telecomID to seenBy
          batch.update(doc.reference, {'seenBy': seenBy});

          // Debug print after modifying the list
          debugPrint("Updated SeenBy: $seenBy");
        }
      }

      await batch.commit();

      // Force UI update
      setState(() {
        _unreadNotificationsCount = 0;
      });

      debugPrint("All notifications marked as read.");
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  void _showNotificationDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return AlertDialog(
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                content: SizedBox(
                  width: 320,
                  height: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Notifications",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                const Text(
                                  "Do not disturb",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Switch(
                                  value: _doNotDisturb,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _doNotDisturb = value;
                                    });
                                    setState(() {
                                      _doNotDisturb = value;
                                    });
                                    _updateDoNotDisturbStatus(value);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFEDF6FF),
                                    radius: 16,
                                    child: Icon(Icons.notifications,
                                        size: 15, color: Colors.blue),
                                  ),
                                  title: Text(
                                    notification['content'],
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    _formatTimestamp(notification['timestamp']),
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ),
                                if (index < _notifications.length - 1)
                                  const Divider(height: 1),
                              ],
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: TextButton(
                            onPressed: _markAllAsRead,
                            child: const Text("Mark all as read"),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
  }

  Future<void> _updateDoNotDisturbStatus(bool value) async {
    try {
      final telecomID = await _secureStorage.read(key: 'telecomID');

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('telecommunicationsAdmin')
          .where('telecomID', isEqualTo: telecomID)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({'doNotDisturb': value});

        // Reinitialize notification service
        await webNotificationService.dispose();
        if (!value) {
          await webNotificationService.initialize();
        }
      }
    } catch (e) {
      debugPrint('Error updating do not disturb status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Color(0xFF113953)),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Color(0xFF113953)),
              onPressed: _showNotificationDialog,
            ),
            if (_unreadNotificationsCount > 0)
              Positioned(
                right: 11,
                top: 11,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '$_unreadNotificationsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 50),
        GestureDetector(
          onTap: () async {
            final shouldRefresh = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ProfilePage()), // Removed const
            );
            if (shouldRefresh == true) {
              _fetchUserData();
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                // Updated image handling
                backgroundImage:
                    _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? MemoryImage(base64Decode(_profileImageUrl!))
                        : null,
                child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF113953),
                    ),
                  ),
                  const Text(
                    "Admin",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 80),
      ],
    );
  }
}
