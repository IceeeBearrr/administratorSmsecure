import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telecom_smsecure/Pages/User/UserSpamMessage.dart';

class UserShowDetail extends StatefulWidget {
  final String phoneNo;

  const UserShowDetail({Key? key, required this.phoneNo}) : super(key: key);

  @override
  _UserShowDetailState createState() => _UserShowDetailState();
}

class _UserShowDetailState extends State<UserShowDetail> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> userData = {};
  List<Map<String, dynamic>> conversations = [];
  List<Map<String, dynamic>> _filteredData = []; // Define _filteredData
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    print("Fetching details for phoneNo: ${widget.phoneNo}");
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      // Get user profile data
      QuerySnapshot userSnapshot = await _firestore
          .collection('smsUser')
          .where('phoneNo', isEqualTo: widget.phoneNo)
          .get();

      Map<String, dynamic> userInfo = {
        'name': widget.phoneNo,
        'phoneNo': widget.phoneNo,
        'emailAddress': 'N/A',
        'profileImage': null,
        'totalSpamMessages': 0,
        'majorDetectedBy': 'None',
        'totalConversations': 0,
      };

      if (userSnapshot.docs.isNotEmpty) {
        final userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
        userInfo.update('name', (_) => userData['name'] ?? widget.phoneNo);
        userInfo.update(
            'phoneNo', (_) => userData['phoneNo'] ?? widget.phoneNo);
        userInfo.update(
            'emailAddress', (_) => userData['emailAddress'] ?? 'N/A');
        if (userData['profileImageUrl'] != null &&
            userData['profileImageUrl'].isNotEmpty) {
          userInfo.update('profileImage',
              (_) => MemoryImage(base64Decode(userData['profileImageUrl'])));
        }
      }

      QuerySnapshot spamContactSnapshot = await _firestore
          .collection('spamContact')
          .where('phoneNo', isEqualTo: widget.phoneNo)
          .get();

      if (spamContactSnapshot.docs.isEmpty) {
        setState(() {
          userData = {
            ...userInfo,
            'totalSpamMessages': 0,
            'majorDetectedBy': 'None',
            'totalConversations': 0,
          };
          isLoading = false;
        });
        return;
      }

      // Step 1: Count spamMessages and find majorDetectedBy
      int totalSpamMessages = 0;
      Map<String, int> detectedDueCount = {};

      for (var spamDoc in spamContactSnapshot.docs) {
        QuerySnapshot spamMessagesSnapshot =
            await spamDoc.reference.collection('spamMessages').get();

        totalSpamMessages += spamMessagesSnapshot.docs.length;

        for (var message in spamMessagesSnapshot.docs) {
          String detectedDue = message['detectedDue'];
          detectedDueCount[detectedDue] =
              (detectedDueCount[detectedDue] ?? 0) + 1;
        }
      }

      String majorDetectedBy = detectedDueCount.isNotEmpty
          ? detectedDueCount.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key
          : 'None';

      // Step 2: Find conversations using smsUserID and count messages
      List<Map<String, dynamic>> conversationsList = [];

      for (var spamDoc in spamContactSnapshot.docs) {
        String smsUserID = spamDoc['smsUserID'];
        String spamContactID = spamDoc.id; // Fetch spamContactID

        QuerySnapshot smsUserSnapshot = await _firestore
            .collection('smsUser')
            .where('smsUserID', isEqualTo: smsUserID)
            .get();

        if (smsUserSnapshot.docs.isEmpty) continue;

        String participantPhoneNo = smsUserSnapshot.docs.first['phoneNo'];

        QuerySnapshot conversationsSnapshot = await _firestore
            .collection('conversations')
            .where('participants', arrayContains: widget.phoneNo)
            .get();

        // Filter the results to include only conversations where both participants exist
        List<QueryDocumentSnapshot> validConversations =
            conversationsSnapshot.docs.where((doc) {
          List<dynamic> participants = doc['participants'];
          return participants.contains(participantPhoneNo) &&
              participants.contains(widget.phoneNo);
        }).toList();

        for (var convo in validConversations) {
          var convoData = convo.data() as Map<String, dynamic>;
          String conversationID = convo.id; // Extract conversationID

          QuerySnapshot messagesSnapshot =
              await convo.reference.collection('messages').get();

          int totalMessages = messagesSnapshot.docs.length;
          int outgoingMessages = 0;
          DateTime now = DateTime.now();
          DateTime threeDaysAgo = now.subtract(const Duration(days: 3));

          for (var message in messagesSnapshot.docs) {
            if (message['isIncoming'] == false) {
              Timestamp timestamp = message['timestamp'];
              if (timestamp.toDate().isAfter(threeDaysAgo)) {
                outgoingMessages++;
              }
            }
          }

          bool isActive = convoData['lastMessageTimeStamp'] != null &&
              (convoData['lastMessageTimeStamp'] as Timestamp)
                  .toDate()
                  .isAfter(threeDaysAgo);

          String maliciousStatus = (outgoingMessages > 5) ? 'High' : 'Low';

          conversationsList.add({
            'conversationID': conversationID, // Add conversationID
            'spamContactID': spamContactID, // Include spamContactID
            'conversationWith': participantPhoneNo,
            'totalMessages': totalMessages,
            'spamMessages': totalSpamMessages,
            'majorDetectedBy': majorDetectedBy,
            'isActive': isActive,
            'maliciousStatus': maliciousStatus,
          });
        }
      }

      // Step 3: Update state
      setState(() {
        userData = {
          'name': widget.phoneNo,
          'phoneNo': widget.phoneNo,
          'totalSpamMessages': totalSpamMessages,
          'majorDetectedBy': majorDetectedBy,
          'totalConversations': conversationsList.length,
        };
        _filteredData = conversationsList;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title:
            const Text("User Details", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Profile Section
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: userData['profileImage'],
                    child: userData['profileImage'] == null
                        ? const Icon(Icons.person,
                            size: 50, color: Colors.white)
                        : null,
                  ),

                  const SizedBox(height: 10),
                  Text(userData['name'] ?? userData['phoneNo'],
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text("Mobile: ${userData['phoneNo'] ?? 'Unknown Phone'}"),
                  Text("Email Address: ${userData['emailAddress'] ?? 'N/A'}"),

                  const SizedBox(height: 10),
                  Text(
                      "Total Conversations: ${userData['totalConversations'] ?? 0}"),
                  Text(
                      "Total Spam Messages: ${userData['totalSpamMessages'] ?? 0}"),
                  const SizedBox(height: 20),

                  // Ban User Button
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _firestore
                            .collection('smsUser')
                            .doc(widget.phoneNo)
                            .update({'isBanned': true});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('User successfully banned!')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error banning user: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Ban User"),
                  ),
                  const SizedBox(height: 20),

                  // Conversations List
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Table Headers
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Phone No",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Total Messages",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Spam Messages",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Major Detected By",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Active Status",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Malicious Status",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                      flex: 1,
                                      child: SizedBox()), // For actions column
                                ],
                              ),
                            ),
                            const Divider(),

                            // Table Rows
                            ..._filteredData.map((user) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        user["conversationWith"]?.toString() ??
                                            "N/A",
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          user["totalMessages"]?.toString() ??
                                              "0",
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          user["spamMessages"]?.toString() ??
                                              "0",
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          user["majorDetectedBy"]?.toString() ??
                                              "N/A",
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          user["isActive"] == true
                                              ? "Active"
                                              : "Inactive",
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: user['maliciousStatus'] ==
                                                    'High'
                                                ? Colors.red
                                                : user['maliciousStatus'] ==
                                                        'Moderate'
                                                    ? Colors.orange
                                                    : Colors.green,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            user['maliciousStatus'] ?? "Low",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // More actions column
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(Icons.more_vert,
                                              color: Colors.grey),
                                          onPressed: () {
                                            showModalBottomSheet(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return Wrap(
                                                  children: [
                                                    ListTile(
                                                      leading: const Icon(
                                                          Icons.info),
                                                      title: const Text(
                                                          'Show Details'),
                                                      onTap: () {
                                                        Navigator.pop(
                                                            context); // Close bottom sheet
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                SpamMessagePage(
                                                              conversationWith:
                                                                  user["conversationWith"]
                                                                          ?.toString() ??
                                                                      "N/A",
                                                              conversationID:
                                                                  user["conversationID"] ??
                                                                      "",
                                                              spamContactID:
                                                                  user["spamContactID"] ??
                                                                      "",
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    ListTile(
                                                      leading: const Icon(
                                                          Icons.block),
                                                      title: const Text(
                                                          'Ban User'),
                                                      onTap: () {
                                                        Navigator.pop(
                                                            context); // Close bottom sheet
                                                        showDialog(
                                                          context: context,
                                                          builder: (BuildContext
                                                              dialogContext) {
                                                            return AlertDialog(
                                                              title: const Text(
                                                                  'Ban User'),
                                                              content: Text(
                                                                'Are you sure you want to ban ${user["phoneNo"] ?? "this user"}?',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  child: const Text(
                                                                      'Cancel'),
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.pop(
                                                                        dialogContext);
                                                                  },
                                                                ),
                                                                TextButton(
                                                                  child:
                                                                      const Text(
                                                                          'Yes'),
                                                                  onPressed:
                                                                      () async {
                                                                    Navigator.pop(
                                                                        dialogContext);
                                                                    try {
                                                                      await _firestore
                                                                          .collection(
                                                                              'smsUser')
                                                                          .doc(user[
                                                                              "phoneNo"])
                                                                          .update({
                                                                        'isBanned':
                                                                            true
                                                                      });
                                                                      ScaffoldMessenger.of(
                                                                              context)
                                                                          .showSnackBar(
                                                                        const SnackBar(
                                                                          content:
                                                                              Text(
                                                                            'User successfully banned!',
                                                                          ),
                                                                        ),
                                                                      );
                                                                    } catch (e) {
                                                                      ScaffoldMessenger.of(
                                                                              context)
                                                                          .showSnackBar(
                                                                        SnackBar(
                                                                          content:
                                                                              Text(
                                                                            'Error banning user: $e',
                                                                          ),
                                                                        ),
                                                                      );
                                                                    }
                                                                  },
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
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
                ],
              ),
            ),
    );
  }
}
