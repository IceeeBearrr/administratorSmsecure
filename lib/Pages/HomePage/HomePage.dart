import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'dart:html' as html;

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String selectedView = 'malicious';
  List<MapEntry<String, int>> topUsers = [];
  bool isLoading = true;
  int totalMaliciousUsers = 0;
  double percentageChange = 0;
  Map<int, String> hoverData = {}; // Stores the hover state for each bar
  int? hoveredIndex; // Track the hovered bar index
  Map<String, int> conversationData = {};
  String? selectedUser; // Track selected malicious user
  int totalSpamMessages = 0;
  double spamMessagePercentageChange = 0;
  final screenshotController = ScreenshotController();
  final GlobalKey chartKey = GlobalKey();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    fetchMaliciousUsers();
  }

  Future<void> fetchMaliciousUsers() async {
    try {
      setState(() => isLoading = true);

      final QuerySnapshot spamSnapshot =
          await FirebaseFirestore.instance.collection('spamContact').get();

      Map<String, int> userCounts = {};
      Map<String, DateTime> latestTimestamps = {};
      int todayCount = 0;
      int yesterdayCount = 0;
      int todaySpamCount = 0;
      int yesterdaySpamCount = 0;
      int totalSpamCount = 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      for (var doc in spamSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final sender = data['phoneNo'] as String? ?? 'unknown';
        userCounts[sender] = (userCounts[sender] ?? 0) + 1;

        final spamMessagesSnapshot = await FirebaseFirestore.instance
            .collection('spamContact')
            .doc(doc.id)
            .collection('spamMessages')
            .orderBy('detectedAt', descending: true)
            .get();

        totalSpamCount += spamMessagesSnapshot.docs.length;

        for (var messageDoc in spamMessagesSnapshot.docs) {
          final messageData = messageDoc.data();
          DateTime? messageDate;

          if (messageData['detectedAt'] is Timestamp) {
            messageDate = (messageData['detectedAt'] as Timestamp).toDate();
          } else if (messageData['detectedAt'] is String) {
            messageDate =
                DateTime.tryParse(messageData['detectedAt'] as String);
          }

          if (messageDate != null) {
            if (!latestTimestamps.containsKey(sender) ||
                messageDate.isAfter(latestTimestamps[sender]!)) {
              latestTimestamps[sender] = messageDate;
            }

            final messageDay =
                DateTime(messageDate.year, messageDate.month, messageDate.day);
            if (messageDay == today) {
              todayCount++;
              todaySpamCount++;
            } else if (messageDay == yesterday) {
              yesterdayCount++;
              yesterdaySpamCount++;
            }
          }
        }
      }

      var change = yesterdayCount > 0
          ? ((todayCount - yesterdayCount) / yesterdayCount * 100).toDouble()
          : 0.0;

      var spamChange = yesterdaySpamCount > 0
          ? ((todaySpamCount - yesterdaySpamCount) / yesterdaySpamCount * 100)
              .toDouble()
          : 0.0;

      setState(() {
        topUsers = userCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        totalMaliciousUsers = userCounts.length;
        percentageChange = change;
        totalSpamMessages = totalSpamCount;
        spamMessagePercentageChange = spamChange;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchConversations(String phoneNo) async {
    try {
      setState(() => isLoading = true);
      print("Fetching conversations for phoneNo: $phoneNo...");

      // Query conversations where participants include the phoneNo
      final QuerySnapshot conversationSnapshot = await FirebaseFirestore
          .instance
          .collection('conversations') // Ensure this collection name is correct
          .where('participants', arrayContains: phoneNo)
          .get();

      if (conversationSnapshot.docs.isEmpty) {
        print("No conversations found for phoneNo: $phoneNo");
      }

      // Count messages in each conversation
      Map<String, int> conversationCounts = {};
      for (var doc in conversationSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final conversationId = doc.id;

        print("Conversation found: $data");

        // Query messages in the conversation
        final messagesSnapshot = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .get();

        conversationCounts[conversationId] = messagesSnapshot.docs.length;
      }

      setState(() {
        conversationData = conversationCounts;
        isLoading = false;
      });
      print("Conversation data updated: $conversationCounts");
    } catch (e) {
      print('Error fetching conversation data: $e');
      setState(() => isLoading = false);
    }
  }

  List<BarChartGroupData> _getConversationBarChartData() {
    final limitedConversations = conversationData.entries.take(10).toList();

    return limitedConversations.asMap().entries.map((entry) {
      int index = entry.key;
      String conversation = entry.value.key;
      int count = entry.value.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: Colors.green,
            width: 15,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();
  }

  List<BarChartGroupData> _getBarChartData() {
    // Limit to top 10 users
    final limitedTopUsers = topUsers.take(10).toList();

    return limitedTopUsers.asMap().entries.map((entry) {
      int index = entry.key;
      String user = entry.value.key;
      int count = entry.value.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: hoveredIndex == index
                ? Colors.lightBlue // Highlighted color on hover
                : Colors.blue, // Default color
            width: 15,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        showingTooltipIndicators: hoveredIndex == index ? [0] : [],
      );
    }).toList();
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: _getBarChartData(),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < topUsers.length) {
                  return Text(
                    topUsers[index].key,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        barTouchData: BarTouchData(
          touchCallback: (event, response) {
            if (event is FlLongPressEnd || event is FlTapUpEvent) {
              // Check if the event is a tap/click
              setState(() {
                if (response?.spot != null) {
                  final clickedIndex = response!.spot!.touchedBarGroupIndex;
                  if (clickedIndex < topUsers.length) {
                    final phoneNo = topUsers[clickedIndex].key;
                    fetchConversations(phoneNo);
                    selectedUser = phoneNo;
                  }
                }
              });
            }
          },
          handleBuiltInTouches: true,
          mouseCursorResolver: (event, response) {
            return response?.spot != null
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic;
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < topUsers.length) {
                return BarTooltipItem(
                  rod.toY.toInt().toString(),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConversationBarChart() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 16.0),
        child: Text(
          'Conversations by Selected User',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      Expanded(
          child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: _getConversationBarChartData(),
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index < conversationData.length) {
                    return Text(
                      conversationData.keys.elementAt(index),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ))
    ]);
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String change,
    IconData icon,
    String viewId,
  ) {
    final isSelected = selectedView == viewId;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedView = viewId;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (viewId != 'prediction') // No arrow for Prediction Model
              Row(
                children: [
                  Icon(
                    percentageChange >= 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: percentageChange >= 0 ? Colors.green : Colors.red,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    change,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchPredictionModelStats() async {
    final modelUsageCounts = <String, int>{};
    final falsePositiveCounts = <String, int>{};
    int totalMessages = 0;

    try {
      print('Fetching spamMessages from spamContact collection...');

      // Get all spam contacts
      final spamContactSnapshot =
          await FirebaseFirestore.instance.collection('spamContact').get();

      print('Found ${spamContactSnapshot.docs.length} spam contacts');

      // Loop through each spam contact
      for (final contactDoc in spamContactSnapshot.docs) {
        // Get spamMessages subcollection
        final spamMessagesSnapshot =
            await contactDoc.reference.collection('spamMessages').get();

        print(
            'Found ${spamMessagesSnapshot.docs.length} spam messages for contact ${contactDoc.id}');

        for (final messageDoc in spamMessagesSnapshot.docs) {
          final messageData = messageDoc.data();
          final detectedBy = messageData['detectedDue'] as String? ?? 'Unknown';
          final isRemoved = messageData['isRemoved'] as bool? ?? false;

          modelUsageCounts[detectedBy] =
              (modelUsageCounts[detectedBy] ?? 0) + 1;

          if (isRemoved) {
            falsePositiveCounts[detectedBy] =
                (falsePositiveCounts[detectedBy] ?? 0) + 1;
          }

          totalMessages++;
        }
      }

      print('Total messages processed: $totalMessages');
      print('Model usage counts: $modelUsageCounts');
      print('False positive counts: $falsePositiveCounts');

      final falsePositiveRates = <String, double>{};
      for (final model in modelUsageCounts.keys) {
        final falsePositives = falsePositiveCounts[model] ?? 0;
        final totalModelMessages = modelUsageCounts[model] ?? 0;

        if (totalModelMessages > 0) {
          falsePositiveRates[model] =
              (falsePositives / totalModelMessages) * 100;
        }
      }

      final sortedFalsePositiveRates = Map.fromEntries(
          falsePositiveRates.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)));

      return {
        'modelUsage': modelUsageCounts,
        'falsePositiveRates': sortedFalsePositiveRates,
        'totalMessages': totalMessages,
      };
    } catch (e, stackTrace) {
      print('Error fetching prediction model stats: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  String _getChartTitle() {
    switch (selectedView) {
      case 'malicious':
        return 'Top Malicious Users';
      case 'prediction':
        return 'Prediction Model Performance';
      case 'spam':
        return 'Spam Messages Trend';
      default:
        return 'Activity Chart';
    }
  }

  Widget _buildPredictionModelChart() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPredictionModelStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child:
                Text("Error loading prediction model data: ${snapshot.error}"),
          );
        }

        final data = snapshot.data!;
        final modelUsage = data['modelUsage'] as Map<String, int>;
        final falsePositiveRates =
            data['falsePositiveRates'] as Map<String, double>;

        if (modelUsage.isEmpty) {
          return const Center(
              child: Text("No prediction model data available."));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model Usage Distribution Pie Chart
            const SizedBox(height: 24),
            SizedBox(
              height: 400,
              child: PieChart(
                PieChartData(
                  sections: modelUsage.entries.map((entry) {
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${entry.key}\n${entry.value}',
                      color: _getModelColor(entry.key),
                      radius: 150,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      titlePositionPercentageOffset: 0.6,
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  centerSpaceColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 48),

            // False Positive Rates Bar Chart
            if (falsePositiveRates.isNotEmpty) ...[
              const Text(
                "False Positive Rates by Model",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 400,
                child: Padding(
                  padding: const EdgeInsets.only(right: 32.0),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: falsePositiveRates.isEmpty
                          ? 10 // Default value when empty
                          : (falsePositiveRates.values.reduce(max) * 1.2),
                      barGroups: falsePositiveRates.entries.map((entry) {
                        return BarChartGroupData(
                          x: falsePositiveRates.keys
                              .toList()
                              .indexOf(entry.key),
                          barRods: [
                            BarChartRodData(
                              toY: entry.value,
                              color: _getModelColor(entry.key),
                              width: 20,
                              borderRadius: BorderRadius.circular(4),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY:
                                    falsePositiveRates.values.reduce(max) * 1.2,
                                color: Colors.grey.withOpacity(0.1),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index < falsePositiveRates.length) {
                                String model =
                                    falsePositiveRates.keys.elementAt(index);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: RotatedBox(
                                    quarterTurns: 1,
                                    child: Text(
                                      model,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  "${value.toStringAsFixed(1)}%",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 5,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Color _getModelColor(String model) {
    switch (model) {
      case 'Bidirectional LSTM':
        return Colors.blue;
      case 'Multinomial NB':
        return Colors.red;
      case 'Linear SVM':
        return Colors.green;
      case 'Custom Filter':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<Map<String, dynamic>> _fetchSpamMessageStats() async {
    final messageCounts = <String, int>{};

    try {
      final spamContactSnapshot =
          await FirebaseFirestore.instance.collection('spamContact').get();

      for (final contactDoc in spamContactSnapshot.docs) {
        final spamMessagesSnapshot =
            await contactDoc.reference.collection('spamMessages').get();

        for (final messageDoc in spamMessagesSnapshot.docs) {
          final message = messageDoc.data()['messages'] as String? ?? '';
          if (message.isNotEmpty) {
            messageCounts[message] = (messageCounts[message] ?? 0) + 1;
          }
        }
      }

      return {
        'messageCounts': Map.fromEntries(messageCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(10))
      };
    } catch (e) {
      print('Error fetching spam message stats: $e');
      return {'messageCounts': <String, int>{}};
    }
  }

  Future<List<Map<String, dynamic>>> _fetchKeywordCounts() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('spamMessages')
          .where('detectedDue',
              whereIn: ['Multinomial NB', 'Linear SVM']).get();

      print(
          "Fetched ${querySnapshot.docs.length} spamMessages documents"); // Debugging log

      // Count individual keywords
      final Map<String, int> keywordCounts = {};
      for (var doc in querySnapshot.docs) {
        print("Processing document: ${doc.id}"); // Debugging log
        final dynamic keywordField = doc.get('keyword');

        // Handle both String and List<dynamic> types
        List<String> keywords;
        if (keywordField is String) {
          keywords = keywordField
              .split(',')
              .map((keyword) => keyword.trim()) // Trim extra spaces
              .toList();
        } else if (keywordField is List<dynamic>) {
          keywords = keywordField.map((e) => e.toString().trim()).toList();
        } else {
          print(
              "Skipping invalid keyword field in document: ${doc.id}"); // Debugging log
          continue;
        }

        for (var keyword in keywords) {
          if (keyword.isNotEmpty) {
            keywordCounts[keyword] = (keywordCounts[keyword] ?? 0) + 1;
          }
        }
      }

      print("Keyword counts: $keywordCounts"); // Debugging log

      // Convert the map to a sorted list of maps
      final List<Map<String, dynamic>> sortedKeywords = keywordCounts.entries
          .map((entry) => {'keyword': entry.key, 'count': entry.value})
          .toList();

      sortedKeywords
          .sort((a, b) => b['count'].compareTo(a['count'])); // Sort descending

      return sortedKeywords.take(5).toList();
    } catch (e) {
      print('Error fetching keyword counts: $e');
      return [];
    }
  }

  Future<void> _downloadPDFReport(String section) async {
    // Retrieve the telecomID from secure storage
    final telecomID = await const FlutterSecureStorage().read(key: 'telecomID');
    if (telecomID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telecom ID not found in secure storage')),
      );
      return;
    }
    // Define log actions based on the section
    String successMessage;
    String failureMessage;

    switch (section) {
      case 'malicious':
        successMessage = "Malicious user report downloaded successfully";
        failureMessage = "Malicious user report download failed";
        break;
      case 'prediction':
        successMessage = "Prediction model report downloaded successfully";
        failureMessage = "Prediction model report download failed";
        break;
      case 'spam':
        successMessage =
            "Spam messages and top keywords downloaded successfully";
        failureMessage = "Spam messages and top keywords download failed";
        break;
      default:
        successMessage = "Report downloaded successfully";
        failureMessage = "Report download failed";
    }
    try {
      setState(() => isLoading = true);

      // Capture the widget using RenderRepaintBoundary
      final RenderRepaintBoundary boundary =
          chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? chartImage = byteData?.buffer.asUint8List();

      if (chartImage == null) {
        throw Exception('Failed to capture chart');
      }

      // Create PDF document
      final pdf = pw.Document();

      // Add content to the PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Spam Detection Analytics Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Generated on: ${DateTime.now()}'),
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(chartImage),
                    fit: pw.BoxFit.contain,
                    width: 500,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF as a Uint8List
      final Uint8List pdfBytes = await pdf.save();

      // Download PDF in Web
      final blob = html.Blob([pdfBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = 'blank'
        ..download = 'spam_detection_report_$section.pdf'
        ..click();
      html.Url.revokeObjectUrl(url);

      // Log success in Firestore
      await FirebaseFirestore.instance
          .collection('telecommunicationsAdmin')
          .doc(telecomID)
          .collection('log')
          .add({
        'action': successMessage,
        'timestamp': Timestamp.now(),
        'status': 'success',
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      await FirebaseFirestore.instance
          .collection('telecommunicationsAdmin')
          .doc(telecomID)
          .collection('log')
          .add({
        'action': failureMessage,
        'timestamp': Timestamp.now(),
        'status': 'failed',
      });

      // Show failure message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failureMessage),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    }
  }

  Widget _buildChartContainer() {
    return RepaintBoundary(
      key: chartKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedView == 'prediction') ...[
              _buildSectionHeader("Top Prediction Model", "prediction"),
              const SizedBox(height: 60),
              _buildPredictionModelChart(),
            ],
            if (selectedView == 'spam') ...[
              _buildSectionHeader("Top 5 Keywords", "spam"),
              const SizedBox(height: 60),
              _buildSpamAnalyticsCharts(),
            ],
            if (selectedView == 'malicious') ...[
              _buildSectionHeader("Top Malicious User", "malicious"),
              const SizedBox(height: 60),
              SizedBox(height: 300, child: _buildBarChart()),
              if (selectedUser != null)
                SizedBox(height: 300, child: _buildConversationBarChart()),
            ],
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPDFSectionContent(String section) {
    switch (section) {
      case 'malicious':
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Malicious Users Analysis',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total Malicious Users: $totalMaliciousUsers',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'Change from Previous Period: ${percentageChange.toStringAsFixed(1)}%',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Top Users Breakdown:',
              style: const pw.TextStyle(fontSize: 14),
            ),
            ...topUsers.take(10).map((user) => pw.Text(
                  '${user.key}: ${user.value} incidents',
                  style: const pw.TextStyle(fontSize: 12),
                )),
          ],
        );
      case 'prediction':
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Prediction Model Performance',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Model Accuracy and Performance Metrics',
              style: const pw.TextStyle(fontSize: 14),
            ),
          ],
        );
      case 'spam':
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Spam Messages Analysis',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total Spam Messages: $totalSpamMessages',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'Change from Previous Period: ${spamMessagePercentageChange.toStringAsFixed(1)}%',
              style: const pw.TextStyle(fontSize: 14),
            ),
          ],
        );
      default:
        return pw.Container();
    }
  }

  Widget _buildSectionHeader(String title, String section) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    size: 18,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => _downloadPDFReport(section),
                    child: const Text(
                      'Download Report',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpamAnalyticsCharts() {
    return FutureBuilder<Map<String, dynamic>>(
      future: Future.wait([
        _fetchSpamMessageStats(),
        _fetchKeywordCounts(),
      ]).then((results) => {
            'spamStats': results[0],
            'keywordStats': results[1],
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        final messageCounts = (data['spamStats']
            as Map<String, dynamic>)['messageCounts'] as Map<String, int>;
        final keywordStats = data['keywordStats'] as List<Map<String, dynamic>>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: keywordStats.map((entry) {
                    final idx = keywordStats.indexOf(entry);
                    return PieChartSectionData(
                      value: entry['count'].toDouble(),
                      title: '${entry['keyword']}\n(${entry['count']})',
                      color: Colors.primaries[idx % Colors.primaries.length],
                      radius: 130,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              'Top 10 Spam Messages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 400,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: messageCounts.isEmpty
                      ? 10
                      : (messageCounts.values.reduce(max) * 1.2),
                  barGroups: messageCounts.entries.map((entry) {
                    final idx = messageCounts.keys.toList().indexOf(entry.key);
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: Colors.red.withOpacity(0.8),
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 100,
                        getTitlesWidget: (value, meta) {
                          final messages = messageCounts.keys.toList();
                          if (value.toInt() < messages.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: RotatedBox(
                                quarterTurns: 1,
                                child: Text(
                                  messages[value.toInt()].length > 20
                                      ? '${messages[value.toInt()].substring(0, 20)}...'
                                      : messages[value.toInt()],
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: true),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              // Enable scrolling
              child: Padding(
                padding: const EdgeInsets.all(50.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Metric Cards Section
                    GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3,
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable GridView scrolling
                      shrinkWrap: true, // Let GridView fit content
                      children: [
                        _buildMetricCard(
                          'Malicious Users',
                          totalMaliciousUsers.toString(),
                          '${percentageChange.toStringAsFixed(1)}% ${percentageChange >= 0 ? 'Up' : 'Down'} from yesterday',
                          Icons.person_outline,
                          'malicious',
                        ),
                        _buildMetricCard(
                          'Prediction Model',
                          '3',
                          '', // No change for the Prediction Model card
                          Icons.model_training,
                          'prediction',
                        ),
                        _buildMetricCard(
                          'Spam Messages Detected',
                          totalSpamMessages.toString(),
                          '${spamMessagePercentageChange.toStringAsFixed(1)}% ${spamMessagePercentageChange >= 0 ? 'Up' : 'Down'} from yesterday',
                          Icons.message_outlined,
                          'spam',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Chart Section
                    _buildChartContainer(),
                  ],
                ),
              ),
            ),
    );
  }
}
