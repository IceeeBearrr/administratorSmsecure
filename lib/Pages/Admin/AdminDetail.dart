import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDetailPage extends StatefulWidget {
  final Map<String, dynamic> adminData;

  const AdminDetailPage({super.key, required this.adminData});

  @override
  _AdminDetailPageState createState() => _AdminDetailPageState();
}

class _AdminDetailPageState extends State<AdminDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> filteredLogs = [];
  bool isLoading = true;
  String? selectedFilter = 'Prediction Model'; // Default filter
  String searchQuery = '';
  Map<String, dynamic>? adminDetails;

  final List<String> filters = [
    'Prediction Model',
    'Download',
    'Ban User',
    'Add Admin'
  ];

  @override
  void initState() {
    super.initState();
    fetchAdminDetails();
    fetchLogs();
  }

  Future<void> fetchAdminDetails() async {
    try {
      final adminId = widget.adminData['id'];
      final adminDoc = await _firestore
          .collection('telecommunicationsAdmin')
          .doc(adminId)
          .get();

      if (adminDoc.exists) {
        setState(() {
          adminDetails = adminDoc.data();
        });
      }
    } catch (e) {
      print("Error fetching admin details: $e");
    }
  }

  Future<void> fetchLogs() async {
    try {
      final adminId = widget.adminData['id']; // Ensure admin ID is passed
      final logSnapshot = await _firestore
          .collection('telecommunicationsAdmin')
          .doc(adminId)
          .collection('log')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        logs = logSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'action': data['action'] ?? 'No action',
            'timestamp': (data['timestamp'] as Timestamp).toDate(),
          };
        }).toList();
        filteredLogs = logs;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching logs: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void applyFilters() {
    setState(() {
      filteredLogs = logs.where((log) {
        final action = log['action'].toLowerCase();
        bool matchesFilter = false;

        // Convert the filter logic to lowercase to handle case insensitivity
        if (selectedFilter?.toLowerCase() == 'prediction model') {
          matchesFilter = action.contains('and learn');
        } else if (selectedFilter?.toLowerCase() == 'download') {
          matchesFilter = action.contains('download');
        } else if (selectedFilter?.toLowerCase() == 'ban user') {
          matchesFilter = action.contains('ban');
        } else if (selectedFilter?.toLowerCase() == 'add admin') {
          matchesFilter = action.contains('admin');
        }

        // Ensure search query matching is case-insensitive
        bool matchesSearch = searchQuery.isEmpty ||
            action.contains(searchQuery.toLowerCase());

        return matchesFilter && matchesSearch;
      }).toList();
    });
  }

  List<TextSpan> _highlightKeywords(String text) {
    final words = text.split(' '); // Split the action text into words
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(widget.adminData['name'] ?? "Admin Details",
              style: const TextStyle(color: Colors.black)),
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
                padding:
                    const EdgeInsets.only(top: 30.0, right: 70.0, left: 70.0),
                child: Column(
                  children: [
                    // Profile Section
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: (adminDetails?['profileImageUrl'] != null &&
                              adminDetails!['profileImageUrl'] != "")
                          ? MemoryImage(
                              base64Decode(adminDetails!['profileImageUrl']))
                          : null,
                      child: (adminDetails?['profileImageUrl'] == null ||
                              adminDetails!['profileImageUrl'] == "")
                          ? const Icon(Icons.person,
                              size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.adminData['name'] ?? 'Unknown Name',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text("Telecom ID: ${widget.adminData['id'] ?? 'No ID'}"),
                    if (adminDetails != null) ...[
                      Text("Gender: ${adminDetails!['gender'] ?? 'N/A'}"),
                      Text("Phone No: ${adminDetails!['phoneNo'] ?? 'N/A'}"),
                      Text("Email: ${adminDetails!['email'] ?? 'N/A'}"),
                      Text("Birthday: ${adminDetails!['birthday'] ?? 'N/A'}"),
                    ],
                    Text("Total Actions: ${widget.adminData['actions'] ?? 0}"),
                    const SizedBox(height: 20),

                    // Dropdown and Search Bar
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
                        child: Column(children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Dropdown for filters
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton2<String>(
                                      value: selectedFilter,
                                      items: filters.map((filter) {
                                        return DropdownMenuItem<String>(
                                          value: filter,
                                          child: Text(filter,
                                              style: const TextStyle(
                                                  fontSize: 14)),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            selectedFilter = value;
                                            searchQuery =
                                                ''; // Clear search query when filter changes
                                            applyFilters();
                                          });
                                        }
                                      },
                                      buttonStyleData: ButtonStyleData(
                                        height: 40,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          color: Colors.white,
                                        ),
                                      ),
                                      dropdownStyleData: DropdownStyleData(
                                        maxHeight: 200,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          color: Colors.white,
                                        ),
                                        scrollbarTheme: ScrollbarThemeData(
                                          radius: const Radius.circular(40),
                                          thickness:
                                              WidgetStateProperty.all(6),
                                          thumbVisibility:
                                              WidgetStateProperty.all(true),
                                        ),
                                      ),
                                      menuItemStyleData:
                                          const MenuItemStyleData(
                                        height: 40,
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Search bar
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      searchQuery = value;
                                      applyFilters();
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: "Search by $selectedFilter",
                                    prefixIcon: const Icon(Icons.search,
                                        color: Colors.grey),
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

                          // Logs Section
                          const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    "Action",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Timestamp",
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          Expanded(
                            child: filteredLogs.isEmpty
                                ? const Center(
                                    child: Text(
                                      "No logs available",
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.grey),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    child: Column(
                                      children: filteredLogs.map((log) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10.0,
                                            vertical: 8.0,
                                          ),
                                          child: Row(
                                            children: [
                                              // Highlighted Action
                                              Expanded(
                                                flex: 3,
                                                child: RichText(
                                                  text: TextSpan(
                                                    children:
                                                        _highlightKeywords(
                                                            log["action"] ??
                                                                ""),
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Timestamp
                                              Expanded(
                                                flex: 2,
                                                child: Center(
                                                  child: Text(
                                                    DateFormat(
                                                            'dd-MM-yyyy HH:mm')
                                                        .format(
                                                      log["timestamp"] ??
                                                          DateTime.now(),
                                                    ),
                                                    textAlign: TextAlign.center,
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
                                    ),
                                  ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ));
  }
}
