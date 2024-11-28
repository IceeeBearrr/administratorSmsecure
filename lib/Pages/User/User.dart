import 'package:dropdown_button2/dropdown_button2.dart';
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
  String _selectedFilter = "ID"; // Default selected dropdown value
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
        String phoneNo = spamDoc['phoneNo'] ?? '';
        String docId = spamDoc.id; // Get the document ID

        // Avoid duplicates by checking if the phone number is already processed
        if (phoneNo.isEmpty || processedPhoneNumbers.contains(phoneNo)) {
          continue;
        }

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
          String detectedBy = messageDoc['detectedDue'] ?? 'None';
          detectedByCount[detectedBy] = (detectedByCount[detectedBy] ?? 0) + 1;
        }
        String majorDetectedBy = detectedByCount.isEmpty
            ? 'None'
            : detectedByCount.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;

        // Check active status
        QuerySnapshot conversationSnapshot = await _firestore
            .collection('conversations')
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
        String maliciousStatus =
            (spamConversations == 0 && spamMessagesCount == 0) ? 'Low' : 'High';

        // Add to user list
        userList.add({
          'id': docId, // Add the document ID
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
        String phoneNo = smsUserDoc['phoneNo'] ?? '';
        String docId = smsUserDoc.id; // Get the document ID

        // Skip if the phone number is already processed
        if (phoneNo.isEmpty || processedPhoneNumbers.contains(phoneNo)) {
          continue;
        }
        processedPhoneNumbers.add(phoneNo);

        // Check active status
        QuerySnapshot conversationSnapshot = await _firestore
            .collection('conversations')
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
          'id': docId, // Add document ID
          'phoneNo': phoneNo,
          'spamConversations': 0,
          'spamMessagesCount': 0,
          'majorDetectedBy': 'None',
          'isActive': isActive,
          'maliciousStatus': maliciousStatus,
        });
      }
      userList.sort(
          (a, b) => b['spamMessagesCount'].compareTo(a['spamMessagesCount']));
    } catch (e) {
      print('Error fetching user data: $e');
    }

    return userList;
  }

  final List<String> _filterOptions = [
    "ID",
    "Phone", // Shortened from "Phone no"
    "Status", // Changed from "Malicious Status"
    "Active", // Shortened from "Active Status"
    "Detection" // Shortened from "Detected By"
  ];

void _filterData(String searchText) {
  setState(() {
    if (searchText.isEmpty) {
      _filteredData = _data;
    } else {
      _filteredData = _data.where((user) {
        switch (_selectedFilter) {
          case 'ID':
            return (user['id']?.toString().toLowerCase() ?? '')
                .contains(searchText.toLowerCase());
            
          case 'Phone':
            return (user['phoneNo']?.toString().toLowerCase() ?? '')
                .contains(searchText.toLowerCase());
            
          case 'Active':
            // Convert boolean to string and check for active/inactive
            if (searchText.toLowerCase() == 'active') {
              return user['isActive'] == true;
            } else if (searchText.toLowerCase() == 'inactive') {
              return user['isActive'] == false;
            }
            return (user['isActive'] == true ? 'active' : 'inactive')
                .contains(searchText.toLowerCase());
            
          case 'Detection':
            String detection = (user['majorDetectedBy']?.toString() ?? 'None').toLowerCase();
            return detection.contains(searchText.toLowerCase());
            
          case 'Status':
            String status = (user['maliciousStatus']?.toString() ?? 'Low').toLowerCase();
            return status.contains(searchText.toLowerCase());
            
          default:
            return false;
        }
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
    child: DropdownButton2<String>(
      value: _selectedFilter,
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
            _searchController.clear();
            _filteredData = _data;
          });
        }
      },
      buttonStyleData: ButtonStyleData(
        height: 40,
        width: 140,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
      ),
      dropdownStyleData: DropdownStyleData(
        maxHeight: 200,
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        scrollbarTheme: ScrollbarThemeData(
          radius: const Radius.circular(40),
          thickness: WidgetStateProperty.all(6),
          thumbVisibility: WidgetStateProperty.all(true),
        ),
      ),
      menuItemStyleData: const MenuItemStyleData(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: 8),
      ),
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
                      hintText: "Search by ${_selectedFilter.toLowerCase()}",
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
                              child: Text("ID",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
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
                              child: Text(user["id"]),
                            ),
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
