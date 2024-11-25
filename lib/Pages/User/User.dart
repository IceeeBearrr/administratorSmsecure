import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:telecom_smsecure/Pages/User/UserShowDetail.dart';

class Userpage extends StatefulWidget {
  const Userpage({super.key});

  @override
  _UserpageState createState() => _UserpageState();
}

class _UserpageState extends State<Userpage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = "Phone no"; // Default selected dropdown value
  List<Map<String, dynamic>> _filteredData = [];
  List<Map<String, dynamic>> _data = [];

  Future<List<Map<String, dynamic>>> fetchUserData() async {
    List<Map<String, dynamic>> userList = [];
    Set<String> processedPhoneNumbers = {}; // To avoid duplicates

    try {
      // Fetch all phone numbers from spamContact (prioritized)
      QuerySnapshot spamContactSnapshot = await _firestore
          .collection('spamContact')
          .where('isRemoved', isEqualTo: false)
          .get();

      for (var spamDoc in spamContactSnapshot.docs) {
        String phoneNo = spamDoc['phoneNo'];

        // Avoid duplicates by checking if the phone number is already processed
        if (processedPhoneNumbers.contains(phoneNo)) continue;

        processedPhoneNumbers.add(phoneNo);

        // Count spam conversations (based on spamMessages where isRemoved = false)
        int spamConversations = 0;
        QuerySnapshot spamMessagesSnapshot = await spamDoc.reference
            .collection('spamMessages')
            .where('isRemoved', isEqualTo: false)
            .get();
        if (spamMessagesSnapshot.docs.isNotEmpty) {
          spamConversations =
              1; // At least one spam message indicates one spam conversation
        }

        // Count the number of spam messages where isRemoved = false
        int spamMessagesCount = spamMessagesSnapshot.docs.length;

        // Calculate major detected by
        Map<String, int> detectedByCount = {};
        for (var messageDoc in spamMessagesSnapshot.docs) {
          String detectedBy = messageDoc['detectedDue'];
          detectedByCount[detectedBy] = (detectedByCount[detectedBy] ?? 0) + 1;
        }
        String majorDetectedBy = detectedByCount.isNotEmpty
            ? detectedByCount.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key
            : 'None';

        // Check active status
        QuerySnapshot conversationSnapshot = await _firestore
            .collection('Conversations')
            .where('participants', arrayContains: phoneNo)
            .get();

        bool isActive = false;
        if (conversationSnapshot.docs.length > 3) {
          for (var convoDoc in conversationSnapshot.docs) {
            Timestamp lastMessageTimeStamp = convoDoc['lastMessageTimeStamp'];
            DateTime lastMessageDate = lastMessageTimeStamp.toDate();
            if (DateTime.now().difference(lastMessageDate).inDays <= 3) {
              isActive = true;
              break;
            }
          }
        }

        // Update malicious status based on spam data
        String maliciousStatus;
        if (spamConversations == 0 && spamMessagesCount == 0) {
          maliciousStatus = 'Low';
        } else {
          maliciousStatus = 'High';
        }

        // Add to user list
        userList.add({
          'phoneNo': phoneNo,
          'spamConversations': spamConversations,
          'spamMessagesCount': spamMessagesCount,
          'majorDetectedBy': majorDetectedBy,
          'isActive': isActive,
          'maliciousStatus': maliciousStatus,
        });
      }

      // Fetch all phone numbers from smsUser (secondary)
      QuerySnapshot smsUserSnapshot =
          await _firestore.collection('smsUser').get();

      for (var smsUserDoc in smsUserSnapshot.docs) {
        String phoneNo = smsUserDoc['phoneNo'];

        // Skip if the phone number is already processed
        if (processedPhoneNumbers.contains(phoneNo)) continue;

        processedPhoneNumbers.add(phoneNo);

        // Check active status
        QuerySnapshot conversationSnapshot = await _firestore
            .collection('Conversations')
            .where('participants', arrayContains: phoneNo)
            .get();

        bool isActive = false;
        if (conversationSnapshot.docs.length > 3) {
          for (var convoDoc in conversationSnapshot.docs) {
            Timestamp lastMessageTimeStamp = convoDoc['lastMessageTimeStamp'];
            DateTime lastMessageDate = lastMessageTimeStamp.toDate();
            if (DateTime.now().difference(lastMessageDate).inDays <= 3) {
              isActive = true;
              break;
            }
          }
        }

        // Malicious status: Set to "Low" since there are no spam data
        String maliciousStatus = 'Low';

        // Add to user list
        userList.add({
          'phoneNo': phoneNo,
          'spamConversations': 0,
          'spamMessagesCount': 0,
          'majorDetectedBy': 'None',
          'isActive': isActive,
          'maliciousStatus': maliciousStatus,
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    return userList;
  }

  final List<String> _filterOptions = [
    "Phone no",
    "Detected as Spam in Conversations",
    "Number of Spam Messages",
    "Major Detected By",
    "Active Status",
    "Malicious Status",
  ];

  void _filterData(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        _filteredData = _data; // Reset to all data when search text is empty
      } else {
        _filteredData = _data.where((item) {
          final valueToSearch = (item[_selectedFilter.toLowerCase()] ?? '')
              .toString()
              .toLowerCase();
          return valueToSearch.contains(searchText.toLowerCase());
        }).toList();
      }
    });
  }

  void _onSearchChanged(String value) {
    _filterData(value);
  }

  @override
  void initState() {
    super.initState();
    fetchUserData().then((data) {
      setState(() {
        _data = data;
        _filteredData = data;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Users", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search and Dropdown List
            Row(
              children: [
                // Dropdown with enhanced style
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      icon:
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                      items: _filterOptions.map((option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedFilter = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Search bar
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: "Search by $_selectedFilter",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Data Table
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
                child: ListView(
                  children: [
                    // Table Headers
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text("Phone no",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text("Detected as Spam",
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text("Number of Spam Messages",
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text("Major Detected By",
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text("Active Status",
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text("Malicious Status",
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text("")),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Data Rows
                    ..._filteredData.map((user) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                user["phoneNo"],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  user["spamConversations"].toString(),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  user["spamMessagesCount"].toString(),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  user["majorDetectedBy"] ?? "None",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  user["isActive"] ? "Active" : "Inactive",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: user['maliciousStatus'] == 'High'
                                        ? Colors.red
                                        : user['maliciousStatus'] == 'Moderate'
                                            ? Colors.orange
                                            : Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    user['maliciousStatus'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Add the "More" icon here
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
                                              leading: const Icon(Icons.info),
                                              title: const Text('Show Details'),
                                              onTap: () {
                                                Navigator.pop(
                                                    context); // Close the bottom sheet
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        UserShowDetail(
                                                      phoneNo: user[
                                                          "phoneNo"], // Pass the phone number directly
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.block),
                                              title: const Text('Ban User'),
                                              onTap: () {
                                                Navigator.pop(
                                                    context); // Close the bottom sheet
                                                // Show confirmation dialog
                                                showDialog(
                                                  context: context,
                                                  builder: (BuildContext
                                                      dialogContext) {
                                                    return AlertDialog(
                                                      title: const Text(
                                                          'Ban User'),
                                                      content: Text(
                                                          'Are you sure you want to ban ${user["phoneNo"]}?'),
                                                      actions: [
                                                        TextButton(
                                                          child: const Text(
                                                              'Cancel'),
                                                          onPressed: () {
                                                            Navigator.pop(
                                                                dialogContext);
                                                          },
                                                        ),
                                                        TextButton(
                                                          child:
                                                              const Text('Yes'),
                                                          onPressed: () async {
                                                            Navigator.pop(
                                                                dialogContext);
                                                            try {
                                                              await _firestore
                                                                  .collection(
                                                                      'smsUser')
                                                                  .doc(user[
                                                                      "phoneNo"])
                                                                  .update({
                                                                'isBanned': true
                                                              });
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                      'User successfully banned!'),
                                                                ),
                                                              );
                                                            } catch (e) {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      'Error banning user: $e'),
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
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
