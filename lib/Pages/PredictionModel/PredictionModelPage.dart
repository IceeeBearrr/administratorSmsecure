import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // For PDF preview and downloading
import 'dart:html' as html;

class PredictionModelPage extends StatefulWidget {
  const PredictionModelPage({super.key});

  @override
  State<PredictionModelPage> createState() => _PredictionModelPageState();
}

class _PredictionModelPageState extends State<PredictionModelPage> {
  final List<String> models = [
    "Bidirectional LSTM",
    "Linear SVM",
    "Multinomial NB"
  ];
  String? selectedModel; // To store the selected model
  int currentStep = 1; // Progress step
  Map<String, dynamic>?
      modelMetrics; // To store the latest metrics for the selected model
  bool isLoading = false; // For loading Firestore data

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false, // Disable the back icon
        title: const Text("Prediction Models",
            style: TextStyle(color: Colors.black)),
      ),
      body: Center(
        child: Container(
          width: 600, // A4 width approximation
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Progress Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProgressCircle(isActive: currentStep >= 1),
                  _buildProgressLine(),
                  _buildProgressCircle(isActive: currentStep >= 2),
                ],
              ),
              const SizedBox(height: 20),

              // Download Button (Below Progress Bar)
              if (currentStep == 2)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        "",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066CC),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        if (modelMetrics == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Please select a model to generate the report."),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        try {
                          setState(() => isLoading = true);
                          final pdfBytes = await _generatePdf();
                          if (!mounted) return;
                          setState(() => isLoading = false);

                          _showPdfPreview(context, pdfBytes);
                        } catch (e) {
                          setState(() => isLoading = false);
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error generating report: $e"),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 20),

              // Step Content
              Expanded(
                child: currentStep == 1 ? _buildStepOne() : _buildStepTwo(),
              ),

              // Navigation Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: currentStep > 1
                        ? () {
                            setState(() {
                              currentStep -= 1; // Go to the previous step
                            });
                          }
                        : null, // Disable if on the first step
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentStep > 1
                          ? Colors.grey.shade300
                          : Colors.grey.shade100,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Previous",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (selectedModel != null || currentStep > 1)
                        ? () {
                            if (currentStep == 1 && selectedModel != null) {
                              setState(() {
                                currentStep += 1; // Proceed to the next step
                              });
                            }
                          }
                        : null, // Disable if no model selected on the first step
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (selectedModel != null || currentStep > 1)
                              ? const Color(0xFF0066CC)
                              : Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Next",
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

  // Step 1: Choose Prediction Models
  Widget _buildStepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Choose a Prediction Model",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF113953),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Tap on a prediction model to view its latest report.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 30),
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
              return GestureDetector(
                onTap: () async {
                  setState(() {
                    selectedModel = model;
                    isLoading = true;
                  });

                  await _fetchLatestModelMetrics(model);

                  setState(() {
                    isLoading = false;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedModel == model
                        ? const Color(0xFFD9EFFF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: selectedModel == model
                          ? const Color(0xFF0066CC)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    model,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF113953),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Step 2: Display Metrics
  Widget _buildStepTwo() {
    if (isLoading || modelMetrics == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final timestamp = modelMetrics?["timestamp"]?.toDate();
    final formattedTimestamp = timestamp != null
        ? DateFormat('yyyy-MM-dd hh:mm a').format(timestamp)
        : "N/A";

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Model: $selectedModel",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Last Updated At: $formattedTimestamp',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Text(
            "Metrics Report",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildMetricsTable(),
          const SizedBox(height: 20),
          _buildDecodedImage(
              modelMetrics?["confusionMatrix"], "Confusion Matrix"),
          if (selectedModel == "Bidirectional LSTM") ...[
            _buildDecodedImage(
                modelMetrics?["accuracyCurve"], "Accuracy Curve"),
            _buildDecodedImage(modelMetrics?["lossCurve"], "Loss Curve"),
          ],
          if (selectedModel != "Bidirectional LSTM")
            _buildDecodedImage(
                modelMetrics?["learningCurve"], "Learning Curve"),
          _buildDecodedImage(modelMetrics?["accuracyCurve"], "Learning Curve"),
          _buildDecodedImage(modelMetrics?["rocCurve"], "ROC Curve"),
        ],
      ),
    );
  }

  // Fetch the latest metrics from Firestore
  Future<void> _fetchLatestModelMetrics(String modelName) async {
    try {
      final modelCollection = FirebaseFirestore.instance
          .collection("predictionModel")
          .where("name", isEqualTo: modelName);

      final modelSnapshot = await modelCollection.get();

      if (modelSnapshot.docs.isNotEmpty) {
        final modelId = modelSnapshot.docs.first.id;

        final metricsCollection = FirebaseFirestore.instance
            .collection("predictionModel")
            .doc(modelId)
            .collection("Metrics")
            .orderBy("timestamp", descending: true)
            .limit(1);

        final metricsSnapshot = await metricsCollection.get();

        if (metricsSnapshot.docs.isNotEmpty) {
          setState(() {
            modelMetrics = metricsSnapshot.docs.first.data();
          });
        }
      }
    } catch (e) {
      print("Error fetching latest metrics: $e");
    }
  }

  // Build Metrics Table
  Widget _buildMetricsTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
      },
      border: TableBorder.all(color: Colors.grey),
      children: [
        _buildTableRow(
            "Train Accuracy",
            modelMetrics?["trainAccuracy"] != null
                ? "${(modelMetrics?["trainAccuracy"] * 100).toStringAsFixed(2)}%"
                : "N/A"),
        _buildTableRow(
            "Test Accuracy",
            modelMetrics?["testAccuracy"] != null
                ? "${(modelMetrics?["testAccuracy"] * 100).toStringAsFixed(2)}%"
                : "N/A"),
        _buildTableRow(
            "Test Precision",
            modelMetrics?["testPrecision"] != null
                ? "${(modelMetrics?["testPrecision"] * 100).toStringAsFixed(2)}%"
                : "N/A"),
        _buildTableRow(
            "Test Recall",
            modelMetrics?["testRecall"] != null
                ? "${(modelMetrics?["testRecall"] * 100).toStringAsFixed(2)}%"
                : "N/A"),
        _buildTableRow(
            "Test F1 Score",
            modelMetrics?["testF1Score"] != null
                ? "${(modelMetrics?["testF1Score"] * 100).toStringAsFixed(2)}%"
                : "N/A"),
      ],
    );
  }

  TableRow _buildTableRow(String metricName, dynamic value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(metricName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(value != null ? value.toString() : "N/A"),
        ),
      ],
    );
  }

  // Build Decoded Image
// Build Decoded Image
  Widget _buildDecodedImage(String? base64String, String title) {
    if (base64String == null) {
      // Return an empty container instead of showing "Data not available"
      return const SizedBox.shrink();
    }

    try {
      final Uint8List decodedBytes = base64Decode(base64String);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            width: 400, // Fixed width
            height: 300, // Fixed height
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              physics: const ClampingScrollPhysics(),
              child: Image.memory(
                decodedBytes,
                width: 400, // Match the container width
                height: 300, // Match the container height
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      );
    } catch (e) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Error decoding image: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ],
      );
    }
  }

  void _showPdfPreview(BuildContext context, Uint8List pdfBytes) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1000,
              maxHeight: 800,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$selectedModel Report Preview",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF113953),
                          ),
                        ),
                        Row(
                          children: [
                            // Download button
                            ElevatedButton.icon(
                              icon: const Icon(Icons.download,
                                  color: Colors.white),
                              label: const Text(
                                "Download",
                                style: TextStyle(
                                    color: Color.fromARGB(255, 255, 255, 255)),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0066CC),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _downloadPdf(pdfBytes),
                            ),
                            const SizedBox(width: 12),
                            // Close button
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Close preview',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // PDF Preview
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PdfPreview(
                        build: (format) => pdfBytes,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        allowPrinting: false,
                        allowSharing: false,
                        maxPageWidth: 700,
                        pdfPreviewPageDecoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);

    // Helper function to convert base64 to image
    Future<pw.MemoryImage?> getImageFromBase64(String? base64String) async {
      if (base64String == null) return null;
      try {
        final Uint8List bytes = base64Decode(base64String);
        return pw.MemoryImage(bytes);
      } catch (e) {
        print("Error decoding image: $e");
        return null;
      }
    }

    // Add title page
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "$selectedModel Report",
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                "Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 14,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                "Performance Metrics",
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 15),
              // Metrics Table
              pw.Table.fromTextArray(
                headers: ["Metric", "Value"],
                data: [
                  [
                    "Train Accuracy",
                    "${(modelMetrics?["trainAccuracy"] * 100).toStringAsFixed(2)}%"
                  ],
                  [
                    "Test Accuracy",
                    "${(modelMetrics?["testAccuracy"] * 100).toStringAsFixed(2)}%"
                  ],
                  [
                    "Precision",
                    "${(modelMetrics?["testPrecision"] * 100).toStringAsFixed(2)}%"
                  ],
                  [
                    "Recall",
                    "${(modelMetrics?["testRecall"] * 100).toStringAsFixed(2)}%"
                  ],
                  [
                    "F1 Score",
                    "${(modelMetrics?["testF1Score"] * 100).toStringAsFixed(2)}%"
                  ],
                ],
                border: pw.TableBorder.all(color: PdfColors.grey400),
                headerStyle: pw.TextStyle(
                  font: ttf,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: pw.TextStyle(
                  font: ttf,
                  fontSize: 12,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellPadding: const pw.EdgeInsets.all(8),
              ),
            ],
          );
        },
      ),
    );

    // Add confusion matrix page
    if (modelMetrics?["confusionMatrix"] != null) {
      final confusionMatrix =
          await getImageFromBase64(modelMetrics?["confusionMatrix"]);
      if (confusionMatrix != null) {
        pdf.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Confusion Matrix",
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Center(
                    child: pw.Image(confusionMatrix, height: 400),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    // Add model-specific pages
    if (selectedModel == "Bidirectional LSTM") {
      // Add accuracy curve
      final accuracyCurve =
          await getImageFromBase64(modelMetrics?["accuracyCurve"]);
      if (accuracyCurve != null) {
        pdf.addPage(pw.Page(
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Accuracy Curve",
                  style: pw.TextStyle(
                      font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Image(accuracyCurve, height: 400)),
            ],
          ),
        ));
      }

      // Add loss curve
      final lossCurve = await getImageFromBase64(modelMetrics?["lossCurve"]);
      if (lossCurve != null) {
        pdf.addPage(pw.Page(
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Loss Curve",
                  style: pw.TextStyle(
                      font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Image(lossCurve, height: 400)),
            ],
          ),
        ));
      }
    } else {
      // For Linear SVM and Multinomial NB
      // Add learning curve
      final learningCurve =
          await getImageFromBase64(modelMetrics?["learningCurve"]);
      if (learningCurve != null) {
        pdf.addPage(pw.Page(
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Learning Curve",
                  style: pw.TextStyle(
                      font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Image(learningCurve, height: 400)),
            ],
          ),
        ));
      }
      final accuracyCurve =
          await getImageFromBase64(modelMetrics?["accuracyCurve"]);
      if (accuracyCurve != null) {
        pdf.addPage(pw.Page(
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Learning Curve",
                  style: pw.TextStyle(
                      font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Image(accuracyCurve, height: 400)),
            ],
          ),
        ));
      }
    }

    // Add ROC curve for all models
    final rocCurve = await getImageFromBase64(modelMetrics?["rocCurve"]);
    if (rocCurve != null) {
      pdf.addPage(pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("ROC Curve",
                style: pw.TextStyle(
                    font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Center(child: pw.Image(rocCurve, height: 400)),
          ],
        ),
      ));
    }

    return pdf.save();
  }

  void _downloadPdf(Uint8List pdfBytes) {
    try {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement()
        ..href = url
        ..style.display = 'none'
        ..download =
            '${selectedModel?.replaceAll(' ', '_')}_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Report downloaded successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error downloading PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error downloading report: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Progress Circle
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

  // Progress Line
  Widget _buildProgressLine() {
    return Container(
      height: 2,
      width: 40,
      color: Colors.grey.shade300,
    );
  }
}
