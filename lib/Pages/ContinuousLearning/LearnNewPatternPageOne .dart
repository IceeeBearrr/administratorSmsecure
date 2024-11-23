import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LearnNewPatternPageOne extends StatefulWidget {
  const LearnNewPatternPageOne({Key? key}) : super(key: key);

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

  // Shared Data to Pass
  final Map<String, dynamic> sharedData = {
    "selectedModels": [],
    "messagePattern": "",
    "label": "",
    "reason": ""
  };

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
            : _buildStepTwo(), // Switch between steps
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

  // Step 2: Define Message Pattern and Details
  Widget _buildStepTwo() {
    return Form(
      key: _formKey,
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
          // Form Inputs
          TextFormField(
            controller: _messagePatternController,
            decoration: InputDecoration(
              labelText: "Message Pattern",
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
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: "Label",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: ["Spam", "Ham"]
                .map((label) => DropdownMenuItem<String>(
                      value: label,
                      child: Text(label),
                    ))
                .toList(),
            onChanged: (value) {
              selectedLabel = value;
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Label cannot be empty";
              }
              return null;
            },
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
                    currentStep = 1; // Move back to step 1
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
                  "Previous step",
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    sharedData["messagePattern"] =
                        _messagePatternController.text;
                    sharedData["label"] = selectedLabel;
                    sharedData["reason"] = _reasonController.text;
                    retrainModels(sharedData);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066CC),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
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
    );
  }

  Future<void> retrainModels(Map<String, dynamic> sharedData) async {
    final url = Uri.parse("http://192.168.101.80:5000/train");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(sharedData), // Pass sharedData directly
    );

    if (response.statusCode == 200) {
      print("Retraining successful: ${response.body}");
    } else {
      print("Retraining failed: ${response.statusCode} ${response.body}");
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
}
