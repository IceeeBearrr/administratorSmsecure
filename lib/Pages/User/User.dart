import 'dart:convert';
import 'dart:typed_data';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telecom_smsecure/Pages/User/AddUser.dart';
import 'package:telecom_smsecure/Pages/User/UserShowDetail.dart';
import 'dart:html' as html; // Needed for web download
import 'package:excel/excel.dart' as excel;
import 'package:telecom_smsecure/main.dart'; // Alias the excel package to 'excel'
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import secure storage

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<List<Map<String, dynamic>>> fetchUserData() async {
    List<Map<String, dynamic>> userList = [];
    Map<String, Map<String, dynamic>> userMap = {};

    try {
      // First fetch all smsUser entries as base data
      QuerySnapshot smsUserSnapshot =
          await _firestore.collection('smsUser').get();

      for (var smsUserDoc in smsUserSnapshot.docs) {
        String phoneNo = smsUserDoc['phoneNo'] ?? '';
        String docId = smsUserDoc.id;

        if (phoneNo.isNotEmpty) {
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

          // Get the data with a null check for isBanned
          Map<String, dynamic> userData =
              smsUserDoc.data() as Map<String, dynamic>;
          bool? isBanned;
          if (userData.containsKey('isBanned')) {
            isBanned = userData['isBanned'] as bool?;
          }

          userMap[phoneNo] = {
            'id': docId,
            'phoneNo': phoneNo,
            'spamConversations': 0,
            'spamMessagesCount': 0,
            'majorDetectedBy': 'None',
            'isActive': isActive,
            'isBanned': isBanned ?? false, // Use null coalescing operator
            'maliciousStatus': 'Low'
          };
        }
      }

      // Then fetch and merge spamContact data
      QuerySnapshot spamContactSnapshot = await _firestore
          .collection('spamContact')
          .where('isRemoved', isEqualTo: false)
          .get();

      for (var spamDoc in spamContactSnapshot.docs) {
        String phoneNo = spamDoc['phoneNo'] ?? '';
        String docId = spamDoc.id;

        if (phoneNo.isNotEmpty) {
          // Count spam conversations and messages
          QuerySnapshot spamMessagesSnapshot = await spamDoc.reference
              .collection('spamMessages')
              .where('isRemoved', isEqualTo: false)
              .get();

          int spamMessagesCount = spamMessagesSnapshot.docs.length;
          int spamConversations = spamMessagesCount > 0 ? 1 : 0;

          // Calculate major detected by
          Map<String, int> detectedByCount = {};
          for (var messageDoc in spamMessagesSnapshot.docs) {
            String detectedBy = messageDoc['detectedDue'] ?? 'None';
            detectedByCount[detectedBy] =
                (detectedByCount[detectedBy] ?? 0) + 1;
          }
          String majorDetectedBy = detectedByCount.isEmpty
              ? 'None'
              : detectedByCount.entries
                  .reduce((a, b) => a.value > b.value ? a : b)
                  .key;

          // If user exists in userMap, update their data
          if (userMap.containsKey(phoneNo)) {
            userMap[phoneNo]!
                .update('spamConversations', (value) => spamConversations);
            userMap[phoneNo]!
                .update('spamMessagesCount', (value) => spamMessagesCount);
            userMap[phoneNo]!
                .update('majorDetectedBy', (value) => majorDetectedBy);
            userMap[phoneNo]!.update(
                'maliciousStatus',
                (value) => (spamConversations > 0 || spamMessagesCount > 0)
                    ? 'High'
                    : 'Low');
          } else {
            // Check active status for new entry
            QuerySnapshot conversationSnapshot = await _firestore
                .collection('conversations')
                .where('participants', arrayContains: phoneNo)
                .get();

            bool isActive = false;
            if (conversationSnapshot.docs.length > 3) {
              for (var convoDoc in conversationSnapshot.docs) {
                Timestamp lastMessageTimeStamp =
                    convoDoc['lastMessageTimeStamp'];
                DateTime lastMessageDate = lastMessageTimeStamp.toDate();
                if (DateTime.now().difference(lastMessageDate).inDays <= 3) {
                  isActive = true;
                  break;
                }
              }
            }

            userMap[phoneNo] = {
              'id': docId,
              'phoneNo': phoneNo,
              'spamConversations': spamConversations,
              'spamMessagesCount': spamMessagesCount,
              'majorDetectedBy': majorDetectedBy,
              'isActive': isActive,
              'isBanned': false, // Default value for new entries
              'maliciousStatus':
                  (spamConversations > 0 || spamMessagesCount > 0)
                      ? 'High'
                      : 'Low'
            };
          }
        }
      }

      // Convert map to list and sort by spam message count
      userList = userMap.values.toList();
      userList.sort(
          (a, b) => b['spamMessagesCount'].compareTo(a['spamMessagesCount']));
    } catch (e) {
      print('Error fetching user data: $e');
    }

    return userList;
  }

  Future<void> _refreshData() async {
    print("Refreshing data...");

    if (!mounted) return; // Ensure widget is still active

    final data = await fetchUserData();
    if (mounted) {
      setState(() {
        _data = data;
        _filteredData = data;
      });
      print("Data refreshed: ${_data.length} user loaded.");
    }
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
              // Filter by active, inactive, or banned status
              if (searchText.toLowerCase() == 'active') {
                return user['isActive'] == true && user['isBanned'] != true;
              } else if (searchText.toLowerCase() == 'inactive') {
                return user['isActive'] == false && user['isBanned'] != true;
              } else if (searchText.toLowerCase() == 'banned') {
                return user['isBanned'] == true;
              }
              return false;

            case 'Detection':
              String detection =
                  (user['majorDetectedBy']?.toString() ?? 'None').toLowerCase();
              return detection.contains(searchText.toLowerCase());

            case 'Status':
              String status =
                  (user['maliciousStatus']?.toString() ?? 'Low').toLowerCase();
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

  Future<void> _downloadExcel({bool onlyHighMalicious = false}) async {
    final telecomID = await _secureStorage.read(key: 'telecomID');
    if (telecomID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telecom ID not found in secure storage')),
      );
      return;
    }
    try {
      final List<Map<String, dynamic>> downloadData = onlyHighMalicious
          ? _data.where((user) => user['maliciousStatus'] == 'High').toList()
          : _data;

      if (downloadData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data available')),
        );
        return;
      }

      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Sheet1'];

      // Headers
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = excel.TextCellValue("ID");
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
          .value = excel.TextCellValue("Phone Number");
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
          .value = excel.TextCellValue("Detected as Spam");
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
          .value = excel.TextCellValue("Number of Spam Messages");
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0))
          .value = excel.TextCellValue("Major Detected By");
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0))
          .value = excel.TextCellValue("Active Status");
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0))
          .value = excel.TextCellValue("Malicious Status");

      // Data rows
      int rowIndex = 1;
      for (var user in downloadData) {
        sheet
            .cell(excel.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: rowIndex))
            .value = excel.TextCellValue(user['id']?.toString() ?? '');
        sheet
            .cell(excel.CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: rowIndex))
            .value = excel.TextCellValue(user['phoneNo']?.toString() ?? '');
        sheet
                .cell(excel.CellIndex.indexByColumnRow(
                    columnIndex: 2, rowIndex: rowIndex))
                .value =
            excel.TextCellValue(user['spamConversations']?.toString() ?? '0');
        sheet
                .cell(excel.CellIndex.indexByColumnRow(
                    columnIndex: 3, rowIndex: rowIndex))
                .value =
            excel.TextCellValue(user['spamMessagesCount']?.toString() ?? '0');
        sheet
                .cell(excel.CellIndex.indexByColumnRow(
                    columnIndex: 4, rowIndex: rowIndex))
                .value =
            excel.TextCellValue(user['majorDetectedBy']?.toString() ?? 'None');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value =
            excel.TextCellValue(user['isBanned'] == true
                ? "Banned" // Display "Banned" if the user is banned
                : (user['isActive'] == true ? "Active" : "Inactive"));
        sheet
                .cell(excel.CellIndex.indexByColumnRow(
                    columnIndex: 6, rowIndex: rowIndex))
                .value =
            excel.TextCellValue(user['maliciousStatus']?.toString() ?? '');
        rowIndex++;
      }

      final List<int>? excelBytes = excelFile.encode();
      if (excelBytes != null) {
        final blob = html.Blob([
          Uint8List.fromList(excelBytes)
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fileName =
            onlyHighMalicious ? "high_malicious_users.xlsx" : "all_users.xlsx";

        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        // Log success to Firestore
        await _firestore
            .collection('telecommunicationsAdmin')
            .doc(telecomID)
            .collection('log')
            .add({
          'action': onlyHighMalicious
              ? "Malicious User downloaded successfully in Excel"
              : "All User downloaded successfully in Excel",
          'timestamp': Timestamp.now(),
          'status': 'success', // Green for success
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${onlyHighMalicious ? 'High Malicious Users' : 'All Users'} downloaded successfully')),
        );
      }
    } catch (e) {
      print('Excel error: $e');

      // Log failure to Firestore
      await _firestore
          .collection('telecommunicationsAdmin')
          .doc(telecomID)
          .collection('log')
          .add({
        'action': onlyHighMalicious
            ? "Malicious User download failed"
            : "All User download failed",
        'timestamp': Timestamp.now(),
        'status': 'failed', // Red for failure
      });
    }
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
        actions: [
          // Download Icon Button
          IconButton(
            icon: const Icon(Icons.download, color: Colors.black),
            tooltip: 'Download User Data',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Download User Data"),
                    content: const Text("Choose the type of data to download:"),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadExcel(onlyHighMalicious: false);
                        },
                        child: const Text(
                          "All Users",
                          style: TextStyle(color: Color(0xFF00A991)),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadExcel(onlyHighMalicious: true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A991),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "High Malicious Users",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(width: 10), // Add some spacing
        ],
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
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    // Navigate to AddAdminPage and wait for the result
                    final shouldRefresh = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddUserPage()),
                    );

                    // Refresh the data if needed
                    if (shouldRefresh == true) {
                      _refreshData();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A991),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Add New Users",
                    style: TextStyle(color: Colors.white),
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
                                  user["isBanned"] == true
                                      ? "Banned"
                                      : (user["isActive"]
                                          ? "Active"
                                          : "Inactive"),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: user["isBanned"] == true
                                        ? Colors.red
                                        : Colors.black,
                                  ),
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
                                              leading: Icon(
                                                Icons.block,
                                                color: user["isBanned"] == true
                                                    ? Colors.red
                                                    : Colors.grey,
                                              ),
                                              title: Text(
                                                user["isBanned"] == true
                                                    ? 'Unban User'
                                                    : 'Ban User',
                                                style: TextStyle(
                                                  color:
                                                      user["isBanned"] == true
                                                          ? Colors.red
                                                          : Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onTap: () {
                                                Navigator.pop(
                                                    context); // Close the bottom sheet
                                                // Show confirmation dialog
                                                showDialog(
                                                  context: context,
                                                  builder: (BuildContext
                                                      dialogContext) {
                                                    return AlertDialog(
                                                      title: Text(
                                                        user["isBanned"] == true
                                                            ? 'Unban User'
                                                            : 'Ban User',
                                                        style: TextStyle(
                                                          color:
                                                              user["isBanned"] ==
                                                                      true
                                                                  ? Colors.red
                                                                  : Colors
                                                                      .black,
                                                        ),
                                                      ),
                                                      content: Text(
                                                          'Are you sure you want to ${user["isBanned"] == true ? 'unban' : 'ban'} ${user["phoneNo"]}?'),
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
                                                          child: Text(
                                                            user["isBanned"] ==
                                                                    true
                                                                ? 'Unban'
                                                                : 'Ban',
                                                            style: TextStyle(
                                                              color:
                                                                  user["isBanned"] ==
                                                                          true
                                                                      ? Colors
                                                                          .red
                                                                      : Colors
                                                                          .black,
                                                            ),
                                                          ),
                                                          onPressed: () async {
                                                            Navigator.pop(
                                                                dialogContext); // Close the dialog
                                                            try {
                                                              final String?
                                                                  docId =
                                                                  user["id"];
                                                              if (docId ==
                                                                  null) {
                                                                scaffoldMessengerKey
                                                                    .currentState
                                                                    ?.showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                        'Error: Document ID is missing.'),
                                                                  ),
                                                                );
                                                                return;
                                                              }
                                                              final telecomID =
                                                                  await const FlutterSecureStorage()
                                                                      .read(
                                                                          key:
                                                                              'telecomID');
                                                              if (telecomID ==
                                                                  null) {
                                                                scaffoldMessengerKey
                                                                    .currentState
                                                                    ?.showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                        'Telecom ID not found in secure storage'),
                                                                  ),
                                                                );
                                                                return;
                                                              }
                                                              // Update the user's "isBanned" status in Firestore
                                                              await _firestore
                                                                  .collection(
                                                                      'smsUser')
                                                                  .doc(docId)
                                                                  .update({
                                                                'isBanned':
                                                                    user["isBanned"] !=
                                                                        true,
                                                              });

                                                              final action =
                                                                  user["isBanned"] ==
                                                                          true
                                                                      ? 'unbanned'
                                                                      : 'banned';
                                                              final logMessage =
                                                                  user["isBanned"] ==
                                                                          true
                                                                      ? 'User ${user["phoneNo"]} unbanned successfully'
                                                                      : 'User ${user["phoneNo"]} banned successfully';

                                                              // Log the successful action to Firestore
                                                              await _firestore
                                                                  .collection(
                                                                      'telecommunicationsAdmin')
                                                                  .doc(
                                                                      telecomID)
                                                                  .collection(
                                                                      'log')
                                                                  .add({
                                                                'action':
                                                                    logMessage,
                                                                'timestamp':
                                                                    Timestamp
                                                                        .now(),
                                                                'status':
                                                                    'success',
                                                              });

                                                              scaffoldMessengerKey
                                                                  .currentState
                                                                  ?.showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      'User successfully ${user["isBanned"] == true ? 'unbanned' : 'banned'}!'),
                                                                ),
                                                              );

                                                              // Refresh the data
                                                              if (mounted) {
                                                                _refreshData();
                                                              }
                                                            } catch (e) {
                                                              final telecomID =
                                                                  await const FlutterSecureStorage()
                                                                      .read(
                                                                          key:
                                                                              'telecomID');
                                                              if (telecomID !=
                                                                  null) {
                                                                // Log the failed action to Firestore
                                                                final failedAction =
                                                                    user["isBanned"] ==
                                                                            true
                                                                        ? 'User ${user["phoneNo"]} unban failed'
                                                                        : 'User ${user["phoneNo"]} ban failed';
                                                                await _firestore
                                                                    .collection(
                                                                        'telecommunicationsAdmin')
                                                                    .doc(
                                                                        telecomID)
                                                                    .collection(
                                                                        'log')
                                                                    .add({
                                                                  'action':
                                                                      failedAction,
                                                                  'timestamp':
                                                                      Timestamp
                                                                          .now(),
                                                                  'status':
                                                                      'failed',
                                                                });
                                                              }

                                                              scaffoldMessengerKey
                                                                  .currentState
                                                                  ?.showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      'Error updating user status: $e'),
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
