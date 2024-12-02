import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';

class LearnNewPatternPageOne extends StatefulWidget {
  const LearnNewPatternPageOne({super.key});

  @override
  State<LearnNewPatternPageOne> createState() => _LearnNewPatternPageOneState();
}

class _LearnNewPatternPageOneState extends State<LearnNewPatternPageOne> {
  final List<String> models = [
    "Bidirectional LSTM",
    "Linear SVM",
    "Multinomial NB"
  ];
  final Set<String> selectedModels = {}; // To store multiple selections
  int currentStep = 1;

  // Controllers and Variables for Step 2
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messagePatternController =
      TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String? selectedLabel;
  bool isLoading = false; // For Step 3 loading state
  bool isSuccess = false; // To track success/failure
  String errorMessage = ""; // To store error message for failure
  bool _showError = false;
  String _errorMessage = '';

  // Secure storage instance
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> _tableData = [];
  String _selectedFilter = "False Positive";
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedRows = {};
  bool _isLoading = false;

  // Shared Data to Pass
  final Map<String, dynamic> sharedData = {
    "selectedModels": [],
    "messagePattern": "",
    "label": "",
    "reason": ""
  };

  final List<String> _filterOptions = ['False Positive', 'False Negative'];

  List<Map<String, dynamic>> messageRows = [
    {"messagePattern": TextEditingController(), "label": null}
  ];

  @override
  void initState() {
    super.initState();
    _clearError();
    if (currentStep == 3) {
      _fetchData();
    }
  }

// Add this method
  void _onStepChanged() {
    if (currentStep == 3) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _tableData.clear();
      final querySnapshot =
          await FirebaseFirestore.instance.collection('spamContact').get();

      for (var doc in querySnapshot.docs) {
        final spamMessages =
            await doc.reference.collection('spamMessages').get();

        for (var message in spamMessages.docs) {
          final data = message.data();

          // Format the timestamp
          String formattedDate = '';
          if (data['detectedAt'] != null) {
            if (data['detectedAt'] is Timestamp) {
              DateTime dateTime = (data['detectedAt'] as Timestamp).toDate();
              formattedDate =
                  "${dateTime.day} ${_getMonth(dateTime.month)} ${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')} UTC+8";
            } else if (data['detectedAt'] is String) {
              formattedDate = data['detectedAt'];
            }
          }

          // For False Positives
          if (_selectedFilter == "False Positive" &&
              data['isRemoved'] == true) {
            _tableData.add({
              'messages': data['messages'] ?? '',
              'detectedDue': data['detectedDue'] ?? '',
              'detectedAt': formattedDate,
            });
          }
          // For False Negatives
          else if (_selectedFilter == "False Negative" &&
              data['detectedDue'] == 'Reported by User') {
            _tableData.add({
              'messages': data['messages'] ?? '',
              'detectedDue': data['detectedDue'] ?? '',
              'detectedAt': formattedDate,
            });
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

// Helper function to get month name
  String _getMonth(int month) {
    switch (month) {
      case 1:
        return 'January';
      case 2:
        return 'February';
      case 3:
        return 'March';
      case 4:
        return 'April';
      case 5:
        return 'May';
      case 6:
        return 'June';
      case 7:
        return 'July';
      case 8:
        return 'August';
      case 9:
        return 'September';
      case 10:
        return 'October';
      case 11:
        return 'November';
      case 12:
        return 'December';
      default:
        return '';
    }
  }

  bool _validateInputs() {
    // First check if any rows are selected
    if (_selectedRows.isEmpty) {
      setState(() {
        _showError = true;
        _errorMessage = 'Please select at least one message to include.';
      });
      return false;
    }

    // Validate selected messages have all required fields
    for (int index in _selectedRows) {
      if (index >= _tableData.length) continue;

      final row = _tableData[index];
      // Check if messages or detectedDue is null or empty
      if ((row['messages']?.toString() ?? '').trim().isEmpty ||
          (row['detectedDue']?.toString() ?? '').trim().isEmpty) {
        setState(() {
          _showError = true;
          _errorMessage =
              'Selected messages must have both message content and detection reason.';
        });
        return false;
      }
    }

    return true;
  }

  void _clearError() {
    setState(() {
      _showError = false;
      _errorMessage = '';
    });
  }

  void _filterData(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        _fetchData(); // Reload all data if search is empty
        return;
      }

      _tableData.removeWhere((element) =>
          !element['messages']
              .toString()
              .toLowerCase()
              .contains(searchText.toLowerCase()) &&
          !element['detectedDue']
              .toString()
              .toLowerCase()
              .contains(searchText.toLowerCase()) &&
          !element['detectedAt']
              .toString()
              .toLowerCase()
              .contains(searchText.toLowerCase()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF113953)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Back to Continuous Learning List",
          style: TextStyle(color: Color(0xFF113953), fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(100.0),
        child: currentStep == 1
            ? _buildStepOne()
            : currentStep == 2
                ? _buildStepTwo()
                : currentStep == 3
                    ? _buildStepThree() // New step for False Positives and Negatives
                    : _buildStepFour(), // Original Step 3 is now Step 4
      ),
    );
  }

  // Step 1: Choose Prediction Models
  Widget _buildStepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Progress Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildProgressCircle(isActive: true),
            _buildProgressLine(),
            _buildProgressCircle(isActive: false),
            _buildProgressLine(),
            _buildProgressCircle(isActive: false),
            _buildProgressLine(),
            _buildProgressCircle(isActive: false),
          ],
        ),
        const SizedBox(height: 20),

        // Header Title
        const Text(
          "Choose Prediction Models to Learn",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF113953),
          ),
        ),
        const SizedBox(height: 10),

        // Description
        const Text(
          "Select one or multiple prediction models (or all) to analyze and learn new message patterns. Right-click on any model to view detailed information about its functionality, benefits, and use cases before proceeding.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 40),

        // Prediction Models
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 2,
            ),
            itemCount: models.length,
            itemBuilder: (context, index) {
              final model = models[index];
              final isSelected = selectedModels.contains(model);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedModels.remove(model); // Deselect
                    } else {
                      selectedModels.add(model); // Select
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFD9EFFF) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0066CC)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    models[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFF113953)
                          : Colors.grey[700],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Next Step Button
        Container(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            onPressed: selectedModels.isNotEmpty
                ? () {
                    setState(() {
                      sharedData["selectedModels"] = selectedModels.toList();
                      currentStep = 2; // Move to step 2
                    });
                  }
                : null, // Disable if no model is selected
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066CC),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Next step",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  void addNewRow() {
    setState(() {
      messageRows
          .add({"messagePattern": TextEditingController(), "label": null});
    });
  }

// Step 2: Define Message Pattern and Details
  Widget _buildStepTwo() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Add padding for better spacing
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Progress Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressCircle(isActive: true),
                  _buildProgressLine(),
                  _buildProgressCircle(isActive: true),
                  _buildProgressLine(),
                  _buildProgressCircle(isActive: false),
                  _buildProgressLine(),
                  _buildProgressCircle(isActive: false),
                ],
              ),
              const SizedBox(height: 20),

              // Header Title
              const Text(
                "Define Message Pattern and Details",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF113953),
                ),
              ),
              const SizedBox(height: 10),

              // Description
              const Text(
                "Provide the message pattern you want to analyze, assign a label (e.g., Spam or Ham) for categorization, and optionally include a reason or note to explain your choice. This information will help the system better understand and learn the context of your data.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Form Inputs
              // Dynamic List of Rows
              Column(
                children: messageRows.map((row) {
                  int index = messageRows.indexOf(row);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      children: [
                        // Message Pattern Input
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: row["messagePattern"],
                            decoration: InputDecoration(
                              labelText: "Message Pattern ${index + 1}",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Message Pattern cannot be empty";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Label Dropdown
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField2<String>(
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            isExpanded: true,
                            hint: const Text(
                              'Label',
                              style: TextStyle(fontSize: 16),
                            ),
                            items: ["Spam", "Ham"]
                                .map((label) => DropdownMenuItem<String>(
                                      value: label,
                                      child: Text(label),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                row["label"] = value;
                              });
                            },
                            value: row["label"],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Label cannot be empty";
                              }
                              return null;
                            },
                            buttonStyleData: ButtonStyleData(
                              height: 50,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color.fromARGB(255, 121, 116,
                                      126), // Updated border color
                                ),
                                color: Colors.white,
                              ),
                            ),
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Remove Button
                        IconButton(
                          onPressed: () {
                            setState(() {
                              messageRows.removeAt(index);
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.red),
                          tooltip: "Remove this row",
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              // Add Button
              const SizedBox(height: 10),

              // Add Button
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: addNewRow,
                  icon: const Icon(Icons.add, color: Color(0xFF0066CC)),
                  tooltip: "Add a new row",
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: "Reason (Optional)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Navigation Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        currentStep = 2; // Move back to step 2
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Previous step",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          sharedData["messagePatterns"] = messageRows
                              .map((row) => {
                                    "pattern": row["messagePattern"].text,
                                    "label": row["label"]
                                  })
                              .toList();
                          sharedData["reason"] = _reasonController.text;
                          currentStep = 3;
                          _onStepChanged();
                          isLoading =
                              true; // Ensure loading is the default state
                          isSuccess = false;
                          errorMessage = ""; // Reset error message
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066CC),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Next step",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// Step 3: False Positives and False Negatives
  Widget _buildStepThree() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Indicator with fixed width
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressCircle(isActive: true),
                  _buildProgressLine(),
                  _buildProgressCircle(isActive: true),
                  _buildProgressLine(),
                  _buildProgressCircle(isActive: true),
                  _buildProgressLine(),
                  _buildProgressCircle(isActive: false),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Title and Description
            const Text(
              "Do you want to include these in the learning?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF113953),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "These messages are gathered from user feedback. False Positive: Messages that are ham but predicted as spam. False Negative: Messages that are spam but predicted as ham.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Filter and Search Row
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Filter Dropdown
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
                            });
                            _fetchData(); // Fetch new data when filter changes
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
                            thickness: MaterialStateProperty.all(6),
                            thumbVisibility: MaterialStateProperty.all(true),
                          ),
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          height: 40,
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Search Box
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterData,
                      decoration: InputDecoration(
                        hintText: "Search messages...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Table Container
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 5,
                            child: Text("Message",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 2,
                            child: Text("Detected Due",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 3,
                            child: Text("Detected At",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(
                            width: 80,
                            child: Text("Include",
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  // Table Content
                  Container(
                    constraints: const BoxConstraints(
                        maxHeight: 400), // Fixed height for scrollable content
                    child: _isLoading
                        ? const Center(
                            child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ))
                        : _tableData.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text("No data found"),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _tableData.length,
                                itemBuilder: (context, index) {
                                  final item = _tableData[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey.shade200)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: Text(
                                              item['messages'] ?? '',
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              item['detectedDue'] ?? '',
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              item['detectedAt'] ?? '',
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 80,
                                            child: Checkbox(
                                              value:
                                                  _selectedRows.contains(index),
                                              onChanged: (bool? value) {
                                                setState(() {
                                                  if (value == true) {
                                                    _selectedRows.add(index);
                                                  } else {
                                                    _selectedRows.remove(index);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error message (only shows when _showError is true)
                  if (_showError)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),

                  // Navigation Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Validate before going back
                          if (messageRows.isEmpty || !_validateInputs()) {
                            setState(() {
                              _showError = true;
                              _errorMessage =
                                  'Please add at least one message pattern and label before proceeding.';
                            });
                            return;
                          }
                          setState(() {
                            currentStep = 2;
                            _showError = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Previous step",
                            style: TextStyle(color: Colors.black)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Validate before proceeding
                          if (messageRows.isEmpty || !_validateInputs()) {
                            setState(() {
                              _showError = true;
                              _errorMessage =
                                  'Please add at least one message pattern and label before proceeding.';
                            });
                            return;
                          }
                          setState(() {
                            // Update sharedData with selected messages
                            sharedData["messagePatterns"] = messageRows
                                .where((row) => _selectedRows
                                    .contains(messageRows.indexOf(row)))
                                .map((row) => {
                                      "pattern": row["messages"],
                                      "label": row["detectedDue"]
                                    })
                                .toList();

                            currentStep = 4;
                            _showError = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066CC),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Next step",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Progress and Training
  Widget _buildStepFour() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Progress Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildProgressCircle(isActive: true),
            _buildProgressLine(),
            _buildProgressCircle(isActive: true),
            _buildProgressLine(),
            _buildProgressCircle(isActive: true),
            _buildProgressLine(),
            _buildProgressCircle(isActive: true),
          ],
        ),
        const SizedBox(height: 20),

        // Header Title
        const Text(
          "Retraining Models",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF113953),
          ),
        ),
        const SizedBox(height: 10),

        // Description
        const Text(
          "Please wait while the models are being retrained. This might take a few moments depending on the selected models and data provided.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 40),

        // Dynamic Content Based on Training State
        Expanded(
          child: Center(
            child: isLoading
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        "This would take a moment...",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  )
                : isSuccess
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.green.withOpacity(0.2),
                            child: const Icon(Icons.check,
                                color: Colors.green, size: 50),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Training Completed Successfully!",
                            style: TextStyle(fontSize: 18, color: Colors.green),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.red.withOpacity(0.2),
                            child: const Icon(Icons.close,
                                color: Colors.red, size: 50),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Training Failed!",
                            style: TextStyle(fontSize: 18, color: Colors.red),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            errorMessage,
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
          ),
        ),

        // Back or Retry Button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isLoading)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentStep = 1; // Allow the user to restart
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Add More",
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _startRetrainProcess(Map<String, dynamic> sharedData) async {
    setState(() {
      isLoading = true; // Show loading initially
      isSuccess = false;
      errorMessage = "";
    });

    final telecomID = await _secureStorage.read(key: "telecomID");

    // Fetch the telecomAdmin's name using telecomID
    String telecomAdminName = "Unknown";
    try {
      final adminDoc = await _firestore
          .collection("telecommunicationsAdmin")
          .doc(telecomID)
          .get();

      if (adminDoc.exists) {
        telecomAdminName = adminDoc.data()?["name"] ?? "Unknown";
      }
    } catch (e) {
      print("Error fetching telecomAdmin name: $e");
    }

    final docRef = await _firestore.collection("messagePattern").add({
      "message": sharedData["messagePattern"],
      "label": sharedData["label"],
      "telecomID": telecomID,
      "status": "Learning in Progress",
      "learnedBy":
          sharedData["selectedModels"], // The models learning the pattern
      "trainedBy": telecomAdminName, // Admin's name
      "reason": sharedData["reason"],
      "timestamp": FieldValue.serverTimestamp(), // Current timestamp
      "metricsComparisons": {}, // Initialize empty metrics comparisons
    });

    final url = Uri.parse("http://127.0.0.1:5000/train");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(sharedData),
    );

    String actionMessage;
    String actionColor;

    if (response.statusCode == 200) {
      Map<String, dynamic> metricsComparisons = {};
      actionMessage =
          "Added and learned new message pattern: '${sharedData["messagePattern"]}' successfully using '${sharedData["selectedModels"].join(", ")}'.";
      actionColor = "green";
      for (String model in sharedData["selectedModels"]) {
        try {
          final comparison = await getMetricsComparison(model);
          metricsComparisons[model] = comparison;
        } catch (e) {
          print('Error getting metrics for $model: $e');
        }
      }

      await docRef.update({"status": "Complete"});

      // Add a notification entry to Firestore
      await _firestore.collection("notification").add({
        "content":
            "'${sharedData["selectedModels"].join(", ")}' model(s) have been updated.",
        "timestamp": FieldValue.serverTimestamp(),
        "adminName": telecomAdminName, // Admin who made the changes
        "seenBy": [], // Initialize with an empty list
      });

      await _logAction(
          telecomID!,
          "Added and learned new message pattern: '${sharedData["messagePattern"]}' successfully.",
          "green");

      setState(() {
        isLoading = false;
        isSuccess = true;
      });
    } else {
      actionMessage =
          "Failed to add and learn new message pattern: '${sharedData["messagePattern"]}' using '${sharedData["selectedModels"].join(", ")}'.";
      actionColor = "red";

      await docRef.update({
        "status": "Exception Found",
        "errorMessage": response.body,
      });
      setState(() {
        isLoading = false;
        isSuccess = false;
        errorMessage = response.body;
      });
    }
    // Log the action in telecommunicationsAdmin collection
    if (telecomID != null) {
      await _firestore
          .collection("telecommunicationsAdmin")
          .doc(telecomID)
          .collection("log")
          .add({
        "action": actionMessage,
        "timestamp": FieldValue.serverTimestamp(),
        "color": actionColor,
      });
    }
    await _logAction(
        telecomID!,
        "Failed to add and learn new message pattern: '${sharedData["messagePattern"]}'.",
        "red");
  }

  Future<Map<String, dynamic>> getMetricsComparison(String modelName) async {
    try {
      // Get reference to the metrics collection for this model
      final metricsRef = FirebaseFirestore.instance
          .collection('modelMetrics')
          .doc(modelName)
          .collection('versions');

      // Get the last two versions ordered by timestamp
      final querySnapshot = await metricsRef
          .orderBy('timestamp', descending: true)
          .limit(2)
          .get();

      if (querySnapshot.docs.length < 2) {
        throw Exception('Not enough versions available for comparison');
      }

      // Extract the current and previous versions
      final currentVersion = querySnapshot.docs[0].data();
      final previousVersion = querySnapshot.docs[1].data();

      // Validate that both versions have the required metrics
      final requiredMetrics = [
        'testAccuracy',
        'testPrecision',
        'testRecall',
        'testF1Score',
        'trainAccuracy',
        'confusionMatrix',
        'rocCurve',
        'accuracyCurve'
      ];

      for (final metric in requiredMetrics) {
        if (!currentVersion.containsKey(metric) ||
            !previousVersion.containsKey(metric)) {
          throw Exception('Missing required metric: $metric');
        }
      }

      // Build the comparison object
      return {
        'current': {
          'metrics': currentVersion,
          'timestamp': currentVersion['timestamp'],
        },
        'previous': {
          'metrics': previousVersion,
          'timestamp': previousVersion['timestamp'],
        }
      };
    } catch (e) {
      print('Error getting metrics comparison: $e');
      rethrow;
    }
  }

  // Helper to create a progress circle
  Widget _buildProgressCircle({required bool isActive}) {
    return Container(
      height: 20,
      width: 20,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF0066CC) : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
    );
  }

  // Helper to create a progress line
  Widget _buildProgressLine() {
    return Container(
      height: 2,
      width: 40,
      color: Colors.grey.shade300,
    );
  }

  Future<void> _logAction(String telecomID, String action, String color) async {
    await _firestore
        .collection("telecommunicationsAdmin")
        .doc(telecomID)
        .collection("log")
        .add({
      "action": action,
      "timestamp": FieldValue.serverTimestamp(),
      "color": color,
    });
  }
}
