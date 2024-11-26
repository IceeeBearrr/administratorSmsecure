import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telecom_smsecure/Pages/Admin/AdminDetail.dart';

class AdministratorPage extends StatefulWidget {
  const AdministratorPage({super.key});

  @override
  _AdministratorPageState createState() => _AdministratorPageState();
}

class _AdministratorPageState extends State<AdministratorPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = "Name"; // Default selected dropdown value
  List<Map<String, dynamic>> _filteredData = [];
  List<Map<String, dynamic>> _data = [];

  final List<String> _filterOptions = ["Name", "Email", "Active Status"];

  Future<List<Map<String, dynamic>>> fetchAdministratorData() async {
    List<Map<String, dynamic>> adminList = [];
    try {
      // Fetch all administrators
      QuerySnapshot adminSnapshot =
          await _firestore.collection('telecommunicationsAdmin').get();

      for (var doc in adminSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String adminId = doc.id;

        // Fetch log sub-collection for the current admin
        QuerySnapshot logSnapshot = await _firestore
            .collection('telecommunicationsAdmin')
            .doc(adminId)
            .collection('log')
            .orderBy('timestamp', descending: true)
            .get();

        // Calculate actions, latest action, and status
        final int actions = logSnapshot.docs.length;
        String latestAction = 'None';
        String status = 'Inactive';

        if (actions > 0) {
          final latestLog =
              logSnapshot.docs.first.data() as Map<String, dynamic>;
          latestAction = latestLog['action'] ?? 'None';

          final DateTime latestTimestamp =
              (latestLog['timestamp'] as Timestamp).toDate();
          final DateTime now = DateTime.now();

          // Check if the latest action is within 3 days
          if (now.difference(latestTimestamp).inDays <= 3) {
            status = 'Active';
          }
        }

        adminList.add({
          'id': adminId,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? 'No Email',
          'actions': actions,
          'latestAction': latestAction,
          'status': status,
        });
      }
    } catch (e) {
      print('Error fetching administrator data: $e');
    }
    return adminList;
  }

  void _filterData(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        _filteredData = _data;
      } else {
        _filteredData = _data.where((admin) {
          final filterKey = _selectedFilter.toLowerCase();
          final valueToSearch =
              admin[filterKey]?.toString().toLowerCase() ?? '';
          return valueToSearch.contains(searchText.toLowerCase());
        }).toList();
      }
    });
  }

  void _onSearchChanged(String value) {
    _filterData(value.toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    fetchAdministratorData().then((data) {
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
        title:
            const Text("Administrators", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar, dropdown, and "Add New Administrator" button
            Row(
              children: [
                // Dropdown for filters
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
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    // Add new administrator action
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
                    "Add New Administrators",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Table headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              color: const Color(0xFFF5F5F5),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text("Name")),
                  Expanded(flex: 2, child: Text("Email Address")),
                  Expanded(
                      flex: 1,
                      child:
                          Text("No. of Actions", textAlign: TextAlign.center)),
                  Expanded(flex: 4, child: Text("Latest Action")),
                  Expanded(
                      flex: 1,
                      child:
                          Text("Active Status", textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text("")),
                ],
              ),
            ),
            const Divider(height: 1),
            // Data rows
            Expanded(
              child: _filteredData.isEmpty
                  ? const Center(child: Text("No administrators found"))
                  : ListView.builder(
                      itemCount: _filteredData.length,
                      itemBuilder: (context, index) {
                        final admin = _filteredData[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 15),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: Colors.grey.shade200, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(admin['name'])),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  admin['email'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  admin['actions'].toString(),
                                  textAlign:
                                      TextAlign.center, // Center-align the text
                                ),
                              ),
                              Expanded(
                                  flex: 4, child: Text(admin['latestAction'])),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: admin['status'] == 'Active'
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    admin['status'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: IconButton(
                                  icon: const Icon(Icons.more_vert,
                                      color: Colors.grey),
                                  onPressed: () {
                                    // Navigate to adminDetail.dart and pass admin data
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AdminDetailPage(
                                          adminData:
                                              admin, // Pass the admin's data to AdminDetailPage
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
