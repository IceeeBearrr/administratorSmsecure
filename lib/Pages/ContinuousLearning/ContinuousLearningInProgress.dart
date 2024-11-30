import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContinuousLearningInProgress extends StatelessWidget {
  final String messagePatternId;

  const ContinuousLearningInProgress({super.key, required this.messagePatternId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Retraining Models",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('messagePattern')
              .doc(messagePatternId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Document not found'));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'Unknown';
            final errorMessage = data['errorMessage'] ?? '';

            bool isLoading = status == 'Learning in Progress';
            bool isSuccess = status == 'Complete';
            bool isException = status == 'Exception Found';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          )
                        : isSuccess
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor:
                                        Colors.green.withOpacity(0.2),
                                    child: const Icon(Icons.check,
                                        color: Colors.green, size: 50),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "Training Completed Successfully!",
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.green),
                                  ),
                                ],
                              )
                            : isException
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 50,
                                        backgroundColor:
                                            Colors.red.withOpacity(0.2),
                                        child: const Icon(Icons.close,
                                            color: Colors.red, size: 50),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        "Training Failed!",
                                        style: TextStyle(
                                            fontSize: 18, color: Colors.red),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        errorMessage,
                                        style: const TextStyle(
                                            fontSize: 16, color: Colors.black),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                  ),
                ),

                // Back Button
                if (!isLoading)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
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
                      "Back to Continuous Learning List",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
