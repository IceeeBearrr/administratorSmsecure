import 'dart:convert';
import 'package:intl/intl.dart'; // For timestamp formatting
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeFirebaseMessaging();
    _fetchUserData();
    _fetchNotifications();
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
        if (!_doNotDisturb) {
          _handleNewNotification(message);
        }
      });
    }
  }

  void _handleNewNotification(RemoteMessage message) {
    _fetchNotifications(); // Refresh notifications
  }

  Future<void> _markAllAsRead() async {
    try {
      final telecomID = await _secureStorage.read(key: 'telecomID');

      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('notification').get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (DocumentSnapshot doc in querySnapshot.docs) {
        List<dynamic> seenBy = List<dynamic>.from(doc['seenBy'] ?? []);
        if (!seenBy.contains(telecomID)) {
          seenBy.add(telecomID!);
          batch.update(doc.reference, {'seenBy': seenBy});
        }
      }

      await batch.commit();
      await _fetchNotifications();
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final telecomID = await _secureStorage.read(key: 'telecomID');
      final querySnapshot = await FirebaseFirestore.instance
          .collection('notification')
          .orderBy('timestamp', descending: true)
          .get();

      final notifications = querySnapshot.docs
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
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
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
                content: Container(
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
                                  trailing: IconButton(
                                    icon: const Icon(Icons.more_horiz,
                                        color: Colors.grey),
                                    onPressed: () {},
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
      await FirebaseFirestore.instance
          .collection('telecommunicationsAdmin')
          .where('telecomID', isEqualTo: telecomID)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          snapshot.docs.first.reference.update({'doNotDisturb': value});
        }
      });
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
                  builder: (context) => ProfilePage()), // Removed const
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
