import 'dart:convert';
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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLogs();
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
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching logs: $e");
      setState(() {
        isLoading = false;
      });
    }
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
                    child:
                        const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.adminData['name'] ?? 'Unknown Name',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text("Telecom ID: ${widget.adminData['id'] ?? 'No ID'}"),
                  Text("Total Actions: ${widget.adminData['actions'] ?? 0}"),
                  const SizedBox(height: 20),

                  // Logs Section
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
                                  // Table Headers
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

                                  // Table Rows
                                  ...logs.map((log) {
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
                                                children: _highlightKeywords(
                                                    log["action"] ?? ""),
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
                                                DateFormat('dd-MM-yyyy HH:mm')
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
