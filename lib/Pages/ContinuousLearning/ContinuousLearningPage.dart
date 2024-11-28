import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telecom_smsecure/Pages/ContinuousLearning/CompareVersion.dart';
import 'package:telecom_smsecure/Pages/ContinuousLearning/LearnNewPatternPageOne%20.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class ContinuousLearningPage extends StatefulWidget {
  const ContinuousLearningPage({super.key});

  @override
  State<ContinuousLearningPage> createState() => _ContinuousLearningPageState();
}

class _ContinuousLearningPageState extends State<ContinuousLearningPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = "Message Pattern"; // Default selected dropdown value
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _filteredData = [];

  final List<String> _filterOptions = [
    "Message Pattern",
    "Label",
    "Learned By",
    "Trained By",
    "Date-Time Learn",
    "Status",
  ];

  // Map to convert display names to data field names
  final Map<String, String> _filterToField = {
    "Message Pattern": "pattern",
    "Label": "label",
    "Learned By": "learnedBy",
    "Trained By": "trainedBy",
    "Date-Time Learn": "dateTime",
    "Status": "status",
  };



  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('messagePattern')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> tempData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] != null
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now();

        // Handle the `learnedBy` field as a List<dynamic>
        String learnedBy = data['learnedBy'] is List
            ? (data['learnedBy'] as List<dynamic>).join(', ')
            : data['learnedBy'] ?? 'Unknown';

        return {
          "id": doc.id, // Add document ID to the map
          "pattern": data['message'] ?? 'No Pattern',
          "label": data['label'] ?? 'No Label',
          "learnedBy": learnedBy, // Updated to handle lists
          "trainedBy": data['trainedBy'] ?? 'Unknown',
          "dateTime":
              "${timestamp.day}-${timestamp.month}-${timestamp.year} ${timestamp.hour}:${timestamp.minute}",
          "status": data['status'] ?? 'Unknown',
        };
      }).toList();

      setState(() {
        _data = tempData;
        _filteredData = tempData;
        _applyFilters(_searchController.text); // Apply initial filtering
      });
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  void _applyFilters(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        _filteredData = _data;
      } else {
        String fieldToSearch = _filterToField[_selectedFilter] ?? 'pattern';
        _filteredData = _data.where((item) {
          final valueToSearch = item[fieldToSearch]?.toString().toLowerCase() ?? '';
          return valueToSearch.contains(searchText.toLowerCase());
        }).toList();
      }
    });
  }


  void _filterData(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        _filteredData = _data; // Reset to all data when search text is empty
      } else {
        _filteredData = _data.where((item) {
          final valueToSearch = item[_selectedFilter.toLowerCase()] ?? '';
          return valueToSearch
              .toString()
              .toLowerCase()
              .contains(searchText.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Continuous Learning",
            style: TextStyle(color: Colors.black)),
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
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton2<String>(
                        value: _selectedFilter,
                        items: _filterOptions.map((filter) {
                          return DropdownMenuItem<String>(
                            value: filter,
                            child: Text(
                              filter,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedFilter = value;
                              _applyFilters(_searchController.text);
                            });
                          }
                        },
                        buttonStyleData: ButtonStyleData(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                        ),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 200,
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
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _applyFilters,
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
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LearnNewPatternPageOne(),
                      ),
                    );
                    fetchData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A991),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    "Learn New Pattern",
                    style: TextStyle(color: Colors.white, fontSize: 14),
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
                              flex: 3,
                              child: Text("Message Pattern",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 1,
                              child: Text("Label",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 3,
                              child: Text("Learned By",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 1,
                              child: Text("Trained By",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 1,
                              child: Text("Date - Time Learn",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 1,
                              child: Text("Status",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text("")),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Data Rows
                    ..._filteredData.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                                flex: 3, child: Text(item["pattern"] ?? "")),
                            Expanded(flex: 1, child: Text(item["label"] ?? "")),
                            Expanded(
                                flex: 3, child: Text(item["learnedBy"] ?? "")),
                            Expanded(
                                flex: 1, child: Text(item["trainedBy"] ?? "")),
                            Expanded(
                                flex: 1, child: Text(item["dateTime"] ?? "")),
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: item["status"] == "Complete"
                                      ? Colors.green
                                      : item["status"] == "Learning in Progress"
                                          ? Colors.yellow
                                          : Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item["status"] ?? "",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: IconButton(
                                  icon: const Icon(Icons.more_vert,
                                      color: Colors.grey),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CompareVersion(
                                          messagePatternId: item[
                                              "id"], // Pass the document ID
                                        ),
                                      ),
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
