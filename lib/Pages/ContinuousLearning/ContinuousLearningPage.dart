import 'package:flutter/material.dart';
import 'package:telecom_smsecure/Pages/ContinuousLearning/LearnNewPatternPageOne%20.dart';

class ContinuousLearningPage extends StatefulWidget {
  const ContinuousLearningPage({Key? key}) : super(key: key);

  @override
  State<ContinuousLearningPage> createState() => _ContinuousLearningPageState();
}

class _ContinuousLearningPageState extends State<ContinuousLearningPage> {
  final List<Map<String, String>> _data = [
    {
      "pattern":
          "ALERT: Your account has been suspended due to suspicious activity...",
      "label": "Spam",
      "learnedBy": "BiLSTM",
      "trainedBy": "Ali",
      "dateTime": "12.09.2019 - 12.53 PM",
      "status": "Complete"
    },
    {
      "pattern":
          "CONGRATULATIONS! You've won 1,000,000 in the Global Sweepstakes...",
      "label": "Spam",
      "learnedBy": "All",
      "trainedBy": "Ali",
      "dateTime": "12.09.2019 - 12.53 PM",
      "status": "Learning in Progress"
    },
    {
      "pattern": "Hurry! Get a 90% discount on the latest gadgets...",
      "label": "Spam",
      "learnedBy": "Multinomial NB",
      "trainedBy": "Ali",
      "dateTime": "12.09.2019 - 12.53 PM",
      "status": "Exception Found"
    },
  ];

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = "Message Pattern"; // Default selected dropdown value
  List<Map<String, String>> _filteredData = [];

  final List<String> _filterOptions = [
    "Message Pattern",
    "Label",
    "Learned By",
    "Trained By",
    "Date-Time Learn",
    "Status",
  ];

  @override
  void initState() {
    super.initState();
    _filteredData = _data; // Initially, display all data
  }

  void _filterData(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        _filteredData = _data; // Reset to all data when search text is empty
      } else {
        _filteredData = _data.where((item) {
          final valueToSearch = item[_selectedFilter.toLowerCase()] ?? '';
          return valueToSearch.toLowerCase().contains(searchText.toLowerCase());
        }).toList();
      }
    });
  }

  void _onSearchChanged(String value) {
    // Add logic to filter data
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
                SizedBox(
                  width: 700,
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
                const Spacer(),
                // Learn New Pattern button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LearnNewPatternPageOne()),
                    );
                    print("Learn New Pattern button clicked");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A991),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 8.0),
                      child: Row(
                        children: const [
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
                              flex: 1,
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
                            Expanded(
                                flex: 1,
                                child: Text(item["label"] ?? "",
                                    style: const TextStyle(color: Colors.red))),
                            Expanded(
                                flex: 1, child: Text(item["learnedBy"] ?? "")),
                            Expanded(
                                flex: 1, child: Text(item["trainedBy"] ?? "")),
                            Expanded(
                                flex: 1, child: Text(item["dateTime"] ?? "")),
                            Expanded(
                              flex: 1,
                              child: Row(
                                children: [
                                  Text(
                                    item["status"] ?? "",
                                    style: TextStyle(
                                      color: item["status"] == "Complete"
                                          ? Colors.green
                                          : item["status"] ==
                                                  "Learning in Progress"
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert,
                                        color: Colors.grey),
                                    onPressed: () {
                                      print(
                                          "Options clicked for ${item["pattern"]}");
                                    },
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }
}
