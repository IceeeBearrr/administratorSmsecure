import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:html' as html;

class CompareVersion extends StatefulWidget {
  final String messagePatternId;

  const CompareVersion({
    Key? key,
    required this.messagePatternId,
  }) : super(key: key);

  @override
  State<CompareVersion> createState() => _CompareVersionState();
}

class _CompareVersionState extends State<CompareVersion> {
  int currentStep = 1;
  List<String> selectedModels = [];
  Map<String, List<Map<String, dynamic>>> modelMetrics = {};
  bool isLoading = true;
  int currentModelIndex = 0;
  DateTime? messagePatternTimestamp;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Fetch the message pattern document
      final messagePatternDoc = await FirebaseFirestore.instance
          .collection('messagePattern')
          .doc(widget.messagePatternId)
          .get();

      if (!messagePatternDoc.exists) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Get the timestamp from message pattern
      messagePatternTimestamp =
          (messagePatternDoc.data()?['timestamp'] as Timestamp).toDate();

      // Define the models we want to check
      final modelsToCheck = [
        'Bidirectional LSTM',
        'Multinomial NB',
        'Linear SVM'
      ];

      // Filter models that exist in learnedBy
      List<String> learnedBy =
          List<String>.from(messagePatternDoc.data()?['learnedBy'] ?? []);
      selectedModels =
          modelsToCheck.where((model) => learnedBy.contains(model)).toList();

      if (selectedModels.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // For each selected model
      for (String modelName in selectedModels) {
        // Get the prediction model document
        final modelQuerySnapshot = await FirebaseFirestore.instance
            .collection('predictionModel')
            .where('name', isEqualTo: modelName)
            .get();

        if (modelQuerySnapshot.docs.isEmpty) continue;

        final modelDoc = modelQuerySnapshot.docs.first;

        // Get metrics for current version (matching messagePattern timestamp)
        final allMetricsQuery = await modelDoc.reference
            .collection('Metrics')
            .orderBy('timestamp', descending: true)
            .get();

        if (allMetricsQuery.docs.isEmpty) continue;

        // Find the closest timestamp to messagePatternTimestamp
        Map<String, dynamic>? currentMetrics;
        DateTime? closestTimestamp;
        Duration smallestDifference =
            const Duration(days: 365); // Initialize with a large duration

        for (var doc in allMetricsQuery.docs) {
          DateTime metricTimestamp =
              (doc.get('timestamp') as Timestamp).toDate();
          Duration difference =
              metricTimestamp.difference(messagePatternTimestamp!).abs();

          if (difference < smallestDifference) {
            smallestDifference = difference;
            currentMetrics = doc.data();
            closestTimestamp = metricTimestamp;
          }
        }

        // Get previous metrics (the next most recent before the closest timestamp)
        Map<String, dynamic>? previousMetrics;
        if (currentMetrics != null && closestTimestamp != null) {
          final previousMetricsQuery = await modelDoc.reference
              .collection('Metrics')
              .where('timestamp', isLessThan: closestTimestamp)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          if (previousMetricsQuery.docs.isNotEmpty) {
            previousMetrics = previousMetricsQuery.docs.first.data();
          }
        }

        if (currentMetrics != null) {
          modelMetrics[modelName] = [
            if (previousMetrics != null) previousMetrics,
            currentMetrics,
          ];
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildComparisonStep() {
    if (selectedModels.isEmpty) {
      return const Center(
        child: Text(
          'No models available for comparison',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    final currentModel = selectedModels[currentModelIndex];
    final metrics = modelMetrics[currentModel];

    if (metrics == null || metrics.isEmpty) {
      return Center(
        child: Text(
          'No metrics available for $currentModel',
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        if (selectedModels.length > 1) _buildProgressBar(),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  currentModel,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (messagePatternTimestamp != null)
                  Text(
                    'Data as of ${DateFormat('MMM dd, yyyy').format(messagePatternTimestamp!)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.white,
                        child: metrics.length > 1
                            ? _buildMetricsComparison(
                                metrics[0], 'Previous Version')
                            : const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No previous version available'),
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: Colors.white,
                        child: _buildMetricsComparison(
                            metrics.length > 1 ? metrics[1] : metrics[0],
                            'Current Version'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (currentModelIndex > 0)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentModelIndex--;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066CC),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Previous",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              )
            else
              const SizedBox(),
            if (currentModelIndex < selectedModels.length - 1)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentModelIndex++;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066CC),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Next",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              )
            else
              const SizedBox(),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsComparison(Map<String, dynamic>? metrics, String title) {
    if (metrics == null) {
      return Center(child: Text('No $title data available'));
    }

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildMetricsTable(metrics),
            const SizedBox(height: 20),
            _buildDecodedImage(metrics['confusionMatrix'], 'Confusion Matrix'),
            const SizedBox(height: 20),
            if (metrics['accuracyCurve'] != null)
              _buildDecodedImage(metrics['accuracyCurve'], 'Accuracy Curve'),
            if (metrics['learningCurve'] != null)
              _buildDecodedImage(metrics['learningCurve'], 'Learning Curve'),
            if (metrics['lossCurve'] != null) ...[
              const SizedBox(height: 20),
              _buildDecodedImage(metrics['lossCurve'], 'Loss Curve'),
            ],
            _buildDecodedImage(metrics['rocCurve'], 'ROC Curve'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsTable(Map<String, dynamic> metrics) {
    return Table(
      border: TableBorder.all(),
      children: [
        _buildTableRow('Training Accuracy', metrics['trainAccuracy']),
        _buildTableRow('Test Accuracy', metrics['testAccuracy']),
        _buildTableRow('Precision', metrics['testPrecision']),
        _buildTableRow('Recall', metrics['testRecall']),
        _buildTableRow('F1 Score', metrics['testF1Score']),
      ],
    );
  }

  TableRow _buildTableRow(String label, dynamic value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('${(value * 100).toStringAsFixed(2)}%'),
        ),
      ],
    );
  }

  Widget _buildDecodedImage(String base64String, String title) {
    try {
      final Uint8List decodedBytes = base64Decode(base64String);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Changed to center
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.start, // Center the title
          ),
          const SizedBox(height: 8),
          Center(
            // Wrap Image with Center widget
            child: Image.memory(
              decodedBytes,
              height: 400,
              fit: BoxFit.contain,
            ),
          ),
        ],
      );
    } catch (e) {
      return const Text('Error decoding image');
    }
  }

  Future<void> _generateAndDownloadPdf() async {
    try {
      final currentModel = selectedModels[currentModelIndex];
      final metrics = modelMetrics[currentModel];

      if (metrics == null || metrics.isEmpty) {
        throw Exception('No metrics available for $currentModel');
      }

      final pdfBytes = await _generatePdf(currentModel, metrics);
      _showPdfPreview(context, pdfBytes, currentModel);
    } catch (e) {
      print('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating report: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPdfPreview(
      BuildContext context, Uint8List pdfBytes, String modelName) {
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
                          "$modelName Version Comparison Report",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF113953),
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.download,
                                  color: Colors.white),
                              label: const Text(
                                "Download",
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
                              onPressed: () =>
                                  _downloadPdf(pdfBytes, modelName),
                            ),
                            const SizedBox(width: 12),
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

  Future<Uint8List> _generatePdf(
      String modelName, List<Map<String, dynamic>> metrics) async {
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);

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

    // Helper function to create metric rows - Move this BEFORE using it
    pw.TableRow _buildPdfMetricRow(String metric, double? previousValue,
        double currentValue, pw.Font ttf) {
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(metric, style: pw.TextStyle(font: ttf)),
          ),
          if (previousValue != null)
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('${(previousValue * 100).toStringAsFixed(2)}%',
                  style: pw.TextStyle(font: ttf)),
            ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text('${(currentValue * 100).toStringAsFixed(2)}%',
                style: pw.TextStyle(font: ttf)),
          ),
        ],
      );
    }

    // 1. Cover page
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "$modelName Version Comparison Report",
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
              if (messagePatternTimestamp != null)
                pw.Text(
                  "Data as of: ${DateFormat('yyyy-MM-dd').format(messagePatternTimestamp!)}",
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
            ],
          );
        },
      ),
    );

    // 2. Metrics Comparison Table (Add this before visualizations)
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          final currentMetrics = metrics.last;
          final previousMetrics = metrics.length > 1 ? metrics[0] : null;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Performance Metrics Comparison",
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Metric',
                            style: pw.TextStyle(
                                font: ttf, fontWeight: pw.FontWeight.bold)),
                      ),
                      if (previousMetrics != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Previous Version',
                              style: pw.TextStyle(
                                  font: ttf, fontWeight: pw.FontWeight.bold)),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Current Version',
                            style: pw.TextStyle(
                                font: ttf, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Metrics rows
                  _buildPdfMetricRow(
                      'Training Accuracy',
                      previousMetrics?['trainAccuracy'],
                      currentMetrics['trainAccuracy'],
                      ttf),
                  _buildPdfMetricRow(
                      'Test Accuracy',
                      previousMetrics?['testAccuracy'],
                      currentMetrics['testAccuracy'],
                      ttf),
                  _buildPdfMetricRow(
                      'Precision',
                      previousMetrics?['testPrecision'],
                      currentMetrics['testPrecision'],
                      ttf),
                  _buildPdfMetricRow('Recall', previousMetrics?['testRecall'],
                      currentMetrics['testRecall'], ttf),
                  _buildPdfMetricRow(
                      'F1 Score',
                      previousMetrics?['testF1Score'],
                      currentMetrics['testF1Score'],
                      ttf),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Add visualizations for both versions
    final versionLabels = metrics.length > 1
        ? ['Previous Version', 'Current Version']
        : ['Current Version'];

    for (var i = 0; i < metrics.length; i++) {
      final versionMetrics = metrics[i];
      final versionLabel = versionLabels[i];

      // Add confusion matrix
      final confusionMatrix =
          await getImageFromBase64(versionMetrics['confusionMatrix']);
      if (confusionMatrix != null) {
        pdf.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(40),
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Confusion Matrix - $versionLabel",
                  style: pw.TextStyle(
                      font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Center(child: pw.Image(confusionMatrix, height: 400)),
              ],
            ),
          ),
        );
      }

      // Add curves based on model type
      if (modelName == "Bidirectional LSTM") {
        // Add accuracy curve
        final accuracyCurve =
            await getImageFromBase64(versionMetrics['accuracyCurve']);
        if (accuracyCurve != null) {
          pdf.addPage(
            pw.Page(
              margin: const pw.EdgeInsets.all(40),
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Accuracy Curve - $versionLabel",
                    style: pw.TextStyle(
                        font: ttf,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Center(child: pw.Image(accuracyCurve, height: 400)),
                ],
              ),
            ),
          );
        }

        // Add loss curve
        final lossCurve = await getImageFromBase64(versionMetrics['lossCurve']);
        if (lossCurve != null) {
          pdf.addPage(
            pw.Page(
              margin: const pw.EdgeInsets.all(40),
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Loss Curve - $versionLabel",
                    style: pw.TextStyle(
                        font: ttf,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Center(child: pw.Image(lossCurve, height: 400)),
                ],
              ),
            ),
          );
        }
      } else {
        // For Linear SVM and Multinomial NB
        final learningCurve =
            await getImageFromBase64(versionMetrics['learningCurve']);
        if (learningCurve != null) {
          pdf.addPage(
            pw.Page(
              margin: const pw.EdgeInsets.all(40),
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Learning Curve - $versionLabel",
                    style: pw.TextStyle(
                        font: ttf,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Center(child: pw.Image(learningCurve, height: 400)),
                ],
              ),
            ),
          );
        }
        final accuracyCurve =
            await getImageFromBase64(versionMetrics['accuracyCurve']);
        if (accuracyCurve != null) {
          pdf.addPage(
            pw.Page(
              margin: const pw.EdgeInsets.all(40),
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Accuracy Curve - $versionLabel",
                    style: pw.TextStyle(
                        font: ttf,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Center(child: pw.Image(accuracyCurve, height: 400)),
                ],
              ),
            ),
          );
        }
      }

      // Add ROC curve
      final rocCurve = await getImageFromBase64(versionMetrics['rocCurve']);
      if (rocCurve != null) {
        pdf.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(40),
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "ROC Curve - $versionLabel",
                  style: pw.TextStyle(
                      font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Center(child: pw.Image(rocCurve, height: 400)),
              ],
            ),
          ),
        );
      }
    }

    return pdf.save();
  }

  pw.Widget _buildPdfComparisonTable(
      List<Map<String, dynamic>> metrics, pw.Font ttf) {
    print('Building PDF table with metrics: $metrics'); // Debug print

    final List<List<String>> data = [];
    final List<String> headers = ['Metric'];

    // Add version headers
    if (metrics.length > 1) {
      headers.add('Previous Version');
      headers.add('Current Version');
    } else {
      headers.add('Current Version');
    }

    // Prepare the metrics rows with proper formatting
    final metricsToShow = [
      {'name': 'Training Accuracy', 'key': 'trainAccuracy'},
      {'name': 'Test Accuracy', 'key': 'testAccuracy'},
      {'name': 'Precision', 'key': 'testPrecision'},
      {'name': 'Recall', 'key': 'testRecall'},
      {'name': 'F1 Score', 'key': 'testF1Score'},
    ];

    // Build each row of data
    for (var metric in metricsToShow) {
      List<String> row = [metric['name']!];

      // Add values for previous version if it exists
      if (metrics.length > 1) {
        row.add('${(metrics[0][metric['key']] * 100).toStringAsFixed(2)}%');
        row.add('${(metrics[1][metric['key']] * 100).toStringAsFixed(2)}%');
      } else {
        row.add('${(metrics[0][metric['key']] * 100).toStringAsFixed(2)}%');
      }

      data.add(row);
    }

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        font: ttf,
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: pw.TextStyle(
        font: ttf,
        fontSize: 12,
      ),
      border: pw.TableBorder.all(color: PdfColors.grey400),
      cellAlignment: pw.Alignment.center,
      headerDecoration: pw.BoxDecoration(
        color: PdfColors.grey200,
      ),
      cellPadding: const pw.EdgeInsets.all(8),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        if (metrics.length > 1) 2: pw.Alignment.center,
      },
    );
  }

  void _downloadPdf(Uint8List pdfBytes, String modelName) {
    try {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement()
        ..href = url
        ..style.display = 'none'
        ..download =
            '${modelName.replaceAll(' ', '_')}_comparison_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

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

  Widget _buildProgressBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: selectedModels.asMap().entries.map((entry) {
        final isActive = currentModelIndex == entry.key;
        return Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.blue : Colors.grey,
              ),
            ),
            if (entry.key < selectedModels.length - 1)
              Container(
                width: 40,
                height: 2,
                color: Colors.grey,
              ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Set background color
      appBar: AppBar(
        title: const Text('Compare Versions'),
        actions: [
          if (selectedModels.length > 2)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _generateAndDownloadPdf,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildComparisonStep(),
      ),
    );
  }
}
