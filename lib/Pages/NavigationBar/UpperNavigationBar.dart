import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchUserData();
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
        const Icon(Icons.notifications, color: Color(0xFF113953)),
        const SizedBox(width: 50),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              child: _profileImageUrl == null
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
        const SizedBox(width: 80),
      ],
    );
  }
}
