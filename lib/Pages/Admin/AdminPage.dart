import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telecom_smsecure/Pages/Admin/AddAdmin.dart';
import 'package:telecom_smsecure/Pages/Admin/AdminDetail.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class AdministratorPage extends StatefulWidget {
  const AdministratorPage({super.key});

  @override
  _AdministratorPageState createState() => _AdministratorPageState();
}

class _AdministratorPageState extends State<AdministratorPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = "ID"; // Default selected dropdown value
  List<Map<String, dynamic>> _filteredData = [];
  List<Map<String, dynamic>> _data = [];
  final List<String> _filterOptions = ["ID", "Name", "Email", "Active Status"];

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

  @override
  void dispose() {
    _searchController.dispose(); // Dispose of controllers
    super.dispose();
  }

  Future<void> _refreshData() async {
    print("Refreshing data...");

    if (!mounted) return; // Ensure widget is still active

    final data = await fetchAdministratorData();
    if (mounted) {
      setState(() {
        _data = data;
        _filteredData = data;
      });
      print("Data refreshed: ${_data.length} administrators loaded.");
    }
  }

// Modify the _filterData method to handle ID filtering
  void _filterData(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        _filteredData = _data;
      } else {
        _filteredData = _data.where((admin) {
          String valueToSearch;

          switch (_selectedFilter.toLowerCase()) {
            case 'id':
              valueToSearch = admin['id']?.toString().toLowerCase() ?? '';
              break;
            case 'name':
              valueToSearch = admin['name']?.toString().toLowerCase() ?? '';
              break;
            case 'email':
              valueToSearch = admin['email']?.toString().toLowerCase() ?? '';
              break;
            case 'active status':
              valueToSearch = admin['status']?.toString().toLowerCase() ?? '';
              break;
            default:
              valueToSearch = '';
          }

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
    _refreshData();
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
                            _searchController
                                .clear(); // Clear search when filter changes
                            _filteredData = _data; // Reset filtered data
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
                    // Navigate to AddAdminPage and wait for the result
                    final shouldRefresh = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddAdminPage()),
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
                  Expanded(flex: 2, child: Text("ID",
                                      style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Name",
                                      style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Email Address",
                                      style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 2,
                      child:
                          Text("No. of Actions", textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 4, child: Text("Latest Action",
                                      style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 1,
                      child:
                          Text("Active Status", textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold))),
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
                              Expanded(flex: 2, child: Text(admin['id'])),
                              Expanded(flex: 2, child: Text(admin['name'])),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  admin['email'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
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
                                                title:
                                                    const Text('Show Details'),
                                                onTap: () {
                                                  Navigator.pop(
                                                      context); // Close the bottom sheet
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          AdminDetailPage(
                                                        adminData:
                                                            admin, // Pass the admin's data to details page
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              ListTile(
                                                leading:
                                                    const Icon(Icons.delete),
                                                title:
                                                    const Text('Delete Admin'),
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
                                                            'Delete Admin'),
                                                        content: Text(
                                                            'Are you sure you want to delete ${admin["name"]}?'),
                                                        actions: [
                                                          TextButton(
                                                            child: const Text(
                                                                'Cancel'),
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                  dialogContext); // Close the dialog
                                                            },
                                                          ),
                                                          TextButton(
                                                            child: const Text(
                                                                'Delete'),
                                                            onPressed:
                                                                () async {
                                                              final adminId =
                                                                  admin['id'];
                                                              if (adminId !=
                                                                  null) {
                                                                try {
                                                                  // Delete the admin document
                                                                  await _firestore
                                                                      .collection(
                                                                          'telecommunicationsAdmin')
                                                                      .doc(
                                                                          adminId)
                                                                      .delete();

                                                                  // Close the dialog using dialogContext instead of context
                                                                  Navigator.of(
                                                                          dialogContext)
                                                                      .pop();

                                                                  // Refresh the data if widget is still mounted
                                                                  if (mounted) {
                                                                    await _refreshData();
                                                                  }
                                                                } catch (e) {
                                                                  Navigator.of(
                                                                          dialogContext)
                                                                      .pop(); // Close dialog in case of error
                                                                }
                                                              } else {
                                                                Navigator.of(
                                                                        dialogContext)
                                                                    .pop(); // Close dialog
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
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
