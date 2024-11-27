import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:telecom_smsecure/Pages/Profile/EditProfilePage.dart'; // Add this import for formatting timestamps

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _secureStorage = const FlutterSecureStorage();
  final _firestore = FirebaseFirestore.instance;

  String telecomID = "";
  Map<String, dynamic>? profileData;
  int predictionModelCount = 0;
  int downloadCount = 0;
  int bannedUserCount = 0;
  List<Map<String, dynamic>> logs = []; // Add this line to initialize logs

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // Retrieve telecomID from secure storage
      final storedTelecomID = await _secureStorage.read(key: 'telecomID');
      if (storedTelecomID != null) {
        telecomID = storedTelecomID;

        // Fetch profile data from Firestore
        final docSnapshot = await _firestore
            .collection('telecommunicationsAdmin')
            .doc(telecomID)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            profileData = docSnapshot.data();
          });

          // Fetch contribution counts from the log sub-collection
          _loadContributionCounts(telecomID);
          _loadLogs(telecomID); // Load logs
        }
      }
    } catch (e) {
      print("Error loading profile: $e");
    }
  }

  Future<void> _loadContributionCounts(String telecomID) async {
    try {
      final querySnapshot = await _firestore
          .collection('telecommunicationsAdmin')
          .doc(telecomID)
          .collection('log')
          .get();

      int predictionCount = 0;
      int downloadCount = 0;
      int bannedCount = 0;

      for (var doc in querySnapshot.docs) {
        final action = doc.data()['action'] ?? '';
        if (action.startsWith("Added and learned new message pattern")) {
          predictionCount++;
        } else if (action.startsWith("Download")) {
          downloadCount++;
        } else if (action.startsWith("Banned")) {
          bannedCount++;
        }
      }

      setState(() {
        predictionModelCount = predictionCount;
        this.downloadCount = downloadCount;
        bannedUserCount = bannedCount;
      });
    } catch (e) {
      print("Error loading contributions: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: profileData == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Profile and Contribution Section
                Container(
                  padding:
                      const EdgeInsets.only(top: 30.0, right: 70.0, left: 70.0),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Profile Info Card
                        Expanded(
                          flex: 3,
                          child: Card(
                            color: Colors.white, // Ensures white background

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundColor: Colors.grey.shade300,
                                        backgroundImage:
                                            profileData?['profileImageUrl'] !=
                                                    null
                                                ? MemoryImage(base64Decode(
                                                    profileData![
                                                        'profileImageUrl']))
                                                : null,
                                        child:
                                            profileData?['profileImageUrl'] ==
                                                    null
                                                ? const Icon(
                                                    Icons.person,
                                                    size: 50,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              profileData?['name'] ?? "N/A",
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              "ID: $telecomID",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            _buildProfileDetail(
                                                "Mobile",
                                                profileData?['phoneNo'] ??
                                                    "N/A"),
                                            _buildProfileDetail("Email",
                                                profileData?['email'] ?? "N/A"),
                                            _buildProfileDetail(
                                                "Gender",
                                                profileData?['gender'] ??
                                                    "N/A"),
                                            _buildProfileDetail(
                                                "Birthday",
                                                profileData?['birthday'] ??
                                                    "N/A"),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () async {
                                      // Added async
                                      if (telecomID.isNotEmpty) {
                                        final result = await Navigator.push(
                                          // Added await and store result
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditProfilePage(
                                                    telecomID: telecomID),
                                          ),
                                        );

                                        // If edit was successful, refresh the profile data
                                        if (result == true) {
                                          setState(() {
                                            _loadProfile(); // Or whatever your method is to fetch profile data
                                          });
                                        }
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Telecom ID is not available')),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                    ),
                                    child: const Text(
                                      "Edit",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Contribution Metrics Card
                        Expanded(
                          flex: 2,
                          child: Card(
                            color: Colors.white, // Ensures white background

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Contribution on Prediction Model",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildContributionMetric(
                                      "Prediction Model", predictionModelCount),
                                  _buildContributionMetric(
                                      "Number of Downloads", downloadCount),
                                  _buildContributionMetric(
                                      "Number of Banned Users",
                                      bannedUserCount),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Logs Section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: 30.0, right: 70.0, left: 70.0),
                    child: Card(
                      color: Colors.white, // Ensures white background
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: logs.isEmpty
                          ? const Center(
                              child: Text(
                                "No logs available",
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10.0, vertical: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            "Action",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            "Timestamp",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(),
                                  ...logs.map((log) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0,
                                        vertical: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: RichText(
                                              text: TextSpan(
                                                children: _highlightKeywords(
                                                    log["action"]),
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                log["timestamp"],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<TextSpan> _highlightKeywords(String text) {
    final words = text.split(' '); // Split text into words
    return words.map((word) {
      if (word.toLowerCase().contains("successfully")) {
        return TextSpan(
          text: "$word ",
          style:
              const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        );
      } else if (word.toLowerCase().contains("failed")) {
        return TextSpan(
          text: "$word ",
          style:
              const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        );
      } else {
        return TextSpan(
          text: "$word ",
        );
      }
    }).toList();
  }

  Widget _buildProfileDetail(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(
            "$title: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLogs(String telecomID) async {
    try {
      final querySnapshot = await _firestore
          .collection('telecommunicationsAdmin')
          .doc(telecomID)
          .collection('log')
          .orderBy('timestamp', descending: true) // Orders by timestamp
          .get();

      final fetchedLogs = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        final formattedTimestamp = timestamp != null
            ? DateFormat('dd-MM-yyyy HH:mm').format(timestamp.toDate())
            : 'Unknown Date';

        return {
          "action": data['action'] ?? 'Unknown Action',
          "timestamp": formattedTimestamp, // Apply formatted timestamp here
        };
      }).toList();

      setState(() {
        logs = fetchedLogs;
      });
    } catch (e) {
      print("Error loading logs: $e");
    }
  }

  Widget _buildContributionMetric(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            "$title:",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            "$count",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
