import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:custom_clippers/custom_clippers.dart';

class SpamMessagePage extends StatefulWidget {
  final String conversationID;
  final String spamContactID;
  final String conversationWith;

  const SpamMessagePage({
    super.key,
    required this.conversationID,
    required this.spamContactID,
    required this.conversationWith,
  });

  @override
  _SpamMessagePageState createState() => _SpamMessagePageState();
}

class _SpamMessagePageState extends State<SpamMessagePage> {
  final ScrollController _scrollController = ScrollController();

  bool isLoading = true;
  String? participantName;
  String? participantImage;
  Map<String, Map<String, dynamic>> spamMessagesInfo = {};
  int previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    print(
        "Initializing SpamMessagePage with conversationWith: ${widget.conversationWith}");
    loadData();
  }

  Future<void> loadData() async {
    try {
      // 1. Get participant details from smsUser
      await loadParticipantDetails();

      // 2. Load spam messages if spamContactID exists
      if (widget.spamContactID.isNotEmpty) {
        await loadSpamMessages();
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading data: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> loadParticipantDetails() async {
    try {
      print("Loading participant details for: ${widget.conversationWith}");
      final smsUserSnapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: widget.conversationWith)
          .limit(1)
          .get();

      if (smsUserSnapshot.docs.isNotEmpty) {
        final userData = smsUserSnapshot.docs.first.data();
        if (mounted) {
          setState(() {
            participantName = userData['name'] ?? widget.conversationWith;
            participantImage = userData['profileImageUrl'];
          });
        }
        print("Participant details loaded - Name: $participantName");
      } else {
        print("No smsUser found for phone number: ${widget.conversationWith}");
        if (mounted) {
          setState(() {
            participantName = widget.conversationWith;
          });
        }
      }
    } catch (e) {
      print("Error loading participant details: $e");
      // Still set the conversationWith as fallback name
      if (mounted) {
        setState(() {
          participantName = widget.conversationWith;
        });
      }
    }
  }

  Future<void> loadSpamMessages() async {
    try {
      print("Loading spam messages for contact ID: ${widget.spamContactID}");
      final spamMessagesSnapshot = await FirebaseFirestore.instance
          .collection('spamContact')
          .doc(widget.spamContactID)
          .collection('spamMessages')
          .where('isRemoved', isEqualTo: false)
          .get();

      Map<String, Map<String, dynamic>> tempSpamMessages = {};
      for (var doc in spamMessagesSnapshot.docs) {
        String normalizedId = doc.id.split('_')[0];
        tempSpamMessages[normalizedId] = doc.data();
      }

      if (mounted) {
        setState(() {
          spamMessagesInfo = tempSpamMessages;
        });
      }
      print("Loaded ${tempSpamMessages.length} spam messages");
    } catch (e) {
      print("Error loading spam messages: $e");
    }
  }

  void _showSpamMessageDetails(Map<String, dynamic> spamDetails) {
    String detectedDue = spamDetails['detectedDue'] ?? "Unknown";
    String rawConfidence = spamDetails['confidenceLevel'] ?? "0";
    String keyword = spamDetails['keyword'] ?? "N/A";
    bool isKeywordNull = keyword.isEmpty;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            "Spam Message Details",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: "Keyword: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: isKeywordNull ? "No Keyword" : keyword,
                        style: TextStyle(
                          color: isKeywordNull ? Colors.grey : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text("Detected Due: $detectedDue"),
                Text(
                    "Confidence Level: ${formatConfidenceLevelBasedOnModel(detectedDue, rawConfidence)}"),
                Text("Processing Time: ${spamDetails['processingTime']}ms"),
                if (spamDetails['detectedAt'] != null)
                  Text(
                      "Detected At: ${DateFormat('dd MMM yyyy, HH:mm').format(spamDetails['detectedAt'].toDate())}"),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Only close the dialog
              },
              tooltip: 'Close',
              color: Colors.grey,
            ),
          ],
        );
      },
    );
  }

  List<TextSpan> _getHighlightedText(String messageContent, String keywords) {
    if (keywords.isEmpty) return [TextSpan(text: messageContent)];

    List<TextSpan> spans = [];
    List<String> keywordList =
        keywords.split(',').map((k) => k.trim()).toList();
    int start = 0;

    while (start < messageContent.length) {
      int nextKeywordIndex = messageContent.length;
      String? currentKeyword;

      for (String keyword in keywordList) {
        int index =
            messageContent.toLowerCase().indexOf(keyword.toLowerCase(), start);
        if (index != -1 && index < nextKeywordIndex) {
          nextKeywordIndex = index;
          currentKeyword = keyword;
        }
      }

      if (currentKeyword == null) {
        spans.add(TextSpan(text: messageContent.substring(start)));
        break;
      }

      if (nextKeywordIndex > start) {
        spans.add(
            TextSpan(text: messageContent.substring(start, nextKeywordIndex)));
      }

      spans.add(TextSpan(
        text: messageContent.substring(
            nextKeywordIndex, nextKeywordIndex + currentKeyword.length),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.yellow,
          color: Colors.black,
        ),
      ));

      start = nextKeywordIndex + currentKeyword.length;
    }

    return spans;
  }

  void _showContextMenu(BuildContext context, Offset tapPosition,
      Map<String, dynamic> spamDetails, String messageContent) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        overlay.size.width - tapPosition.dx,
        overlay.size.height - tapPosition.dy,
      ),
      items: [
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFF4444)),
            title: Text('View Spam Details'),
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            // Close menu and show details immediately
            _showEnhancedSpamDetails(context, spamDetails, messageContent);
          },
        ),
      ],
    );
  }

  void _showEnhancedSpamDetails(BuildContext context,
      Map<String, dynamic> spamDetails, String messageContent) {
    String detectedDue = spamDetails['detectedDue'] ?? "Unknown";
    String rawConfidence = spamDetails['confidenceLevel'] ?? "0";
    String formattedConfidence =
        formatConfidenceLevelBasedOnModel(detectedDue, rawConfidence);
    String keyword = spamDetails['keyword'] ?? "";
    bool isKeywordNull = keyword.isEmpty;

    showDialog(
      context: context,
      barrierDismissible: true, // Allow clicking outside to close
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Column(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF4444),
                size: 48,
              ),
              SizedBox(height: 8),
              Text(
                "Spam Message Details",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF113953),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailsSection(
                  "Detection Method",
                  detectedDue,
                  Icons.security,
                ),
                const SizedBox(height: 16),
                _buildDetailsSection(
                  "Confidence Score",
                  formattedConfidence,
                  Icons.analytics,
                  showProgress: true,
                  progress:
                      double.parse(formattedConfidence.replaceAll('%', '')) /
                          100,
                ),
                if (!isKeywordNull) ...[
                  const SizedBox(height: 16),
                  _buildDetailsSection(
                    "Detected Keywords",
                    keyword,
                    Icons.key,
                  ),
                ],
                const SizedBox(height: 16),
                _buildDetailsSection(
                  "Processing Time",
                  "${spamDetails['processingTime']}ms",
                  Icons.timer,
                ),
                const SizedBox(height: 16),
                _buildDetailsSection(
                  "Detected At",
                  DateFormat('dd MMM yyyy, HH:mm')
                      .format(spamDetails['detectedAt'].toDate()),
                  Icons.access_time,
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Only close the dialog
              },
              tooltip: 'Close',
              color: Colors.grey,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light gray background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF113953)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: participantImage != null
                    ? MemoryImage(base64Decode(participantImage!))
                    : null,
                child: participantImage == null
                    ? const Icon(Icons.person,
                        size: 30, color: Color(0xFF113953))
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participantName ?? "Loading...",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF113953),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.conversationWith != participantName &&
                      widget.conversationWith.isNotEmpty)
                    Text(
                      widget.conversationWith,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF113953),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Loading conversation...",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(widget.conversationID)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "Error loading messages: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      "No messages found",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    var messageContent = message['content'] as String;
                    var senderID = message['senderID'] as String;
                    String normalizedMessageId = message.id.split('_')[0];
                    bool isSpam =
                        spamMessagesInfo.containsKey(normalizedMessageId);

                    var spamDetails =
                        isSpam ? spamMessagesInfo[normalizedMessageId] : null;
                    String keyword = spamDetails?['keyword'] ?? '';

                    return GestureDetector(
                      onSecondaryTapUp: isSpam
                          ? (TapUpDetails details) {
                              _showContextMenu(
                                context,
                                details.globalPosition,
                                spamDetails!,
                                messageContent,
                              );
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: senderID == widget.conversationWith
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.end,
                          children: [
                            if (senderID != widget.conversationWith)
                              const Spacer(flex: 1),
                            Flexible(
                              flex: 6,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: ClipPath(
                                  clipper: senderID == widget.conversationWith
                                      ? UpperNipMessageClipper(
                                          MessageType.receive)
                                      : LowerNipMessageClipper(
                                          MessageType.send),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSpam
                                          ? const Color(0xFFFF4444)
                                          : (senderID != widget.conversationWith
                                              ? const Color(0xFF113953)
                                              : Colors.white),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.4,
                                          color: isSpam ||
                                                  senderID !=
                                                      widget.conversationWith
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        children: _getHighlightedText(
                                            messageContent, keyword),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (senderID == widget.conversationWith)
                              const Spacer(flex: 1),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String formatConfidenceLevelBasedOnModel(
      String detectedDue, String rawConfidence) {
    double rawScore = double.tryParse(rawConfidence) ?? 0.0;
    double confidence;

    switch (detectedDue) {
      case "Custom Filter":
        confidence = 1.0;
        break;
      case "Bidirectional LSTM":
      case "Multinomial NB":
        confidence = rawScore;
        break;
      case "Linear SVM":
        confidence = 1 / (1 + exp(-rawScore));
        break;
      default:
        confidence = 0.0;
    }

    return "${(confidence * 100).toStringAsFixed(2)}%";
  }
}

String formatConfidenceLevelBasedOnModel(
    String detectedDue, String rawConfidence) {
  double rawScore = double.tryParse(rawConfidence) ?? 0.0;
  double confidence;

  switch (detectedDue) {
    case "Custom Filter":
      confidence = 1.0;
      break;
    case "Bidirectional LSTM":
    case "Multinomial NB":
      confidence = rawScore;
      break;
    case "Linear SVM":
      confidence = 1 / (1 + exp(-rawScore));
      break;
    default:
      confidence = 0.0;
  }

  return "${(confidence * 100).toStringAsFixed(2)}%";
}

Widget _buildDetailsSection(String title, String value, IconData icon,
    {bool showProgress = false, double progress = 0}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF113953)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF113953),
              fontSize: 14,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      if (showProgress) ...[
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF113953)),
        ),
        const SizedBox(height: 4),
      ],
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade800,
        ),
      ),
    ],
  );
}
