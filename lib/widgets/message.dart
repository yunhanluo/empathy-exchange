import 'dart:convert';

import 'package:empathy_exchange/lib/firebase.dart';
import 'package:empathy_exchange/widgets/sidetooltip.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Message extends StatefulWidget {
  const Message(this.value, this.sender, this.senderToken, this.pfp64,
      this.karma, this.chatId,
      {super.key});

  final String value;
  final Sender sender;
  final String senderToken;
  final String pfp64;
  final int karma;
  final int chatId;

  @override
  // ignore: no_logic_in_create_state
  State<Message> createState() => _MessageState();
}

class _MessageState extends State<Message> {
  String? _censoredValue;

  TextEditingController reasonController = TextEditingController();
  String? selectedIcon;
  String? selectedReason;

  @override
  void initState() {
    super.initState();

    _censoredValue =
        FirebaseChatTools.filter.censor(_censoredValue ?? widget.value);
  }

  @override
  void dispose() {
    reasonController.dispose();

    super.dispose();
  }

  Widget _buildIconOption(
    BuildContext context,
    StateSetter setDialogState,
    IconData icon,
    String name,
    String reason,
  ) {
    bool isSelected = selectedIcon == name;
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          selectedIcon = name;
          selectedReason = reason;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDefaultReason(String iconName) {
    switch (iconName) {
      case 'Love':
        return 'For being caring and compassionate';
      case 'Support':
        return 'For being supportive and encouraging';
      case 'Excellence':
        return 'For going above and beyond';
      case 'Insight':
        return 'For sharing great ideas and wisdom';
      case 'Joy':
        return 'For bringing happiness and positivity';
      case 'Help':
        return 'For being helpful and reliable';
      default:
        return 'For being kind';
    }
  }

  void _giveBadge(String reason, String icon) async {
    String mytoken = await FirebaseUserTools.load(
        '${FirebaseAuth.instance.currentUser?.uid}/pairToken');
    String? uid = await FirebaseUserTools.getUidFromToken(widget.senderToken);

    await FirebaseUserTools.listPush('$uid/badges', {
      'giver': mytoken,
      'reason': FirebaseChatTools.filter.censor(reason),
      'icon': icon,
      'time': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
    await FirebaseUserTools.set(
        '$uid/karma', await FirebaseUserTools.load('$uid/karma') + 1);

    Map data = await FirebaseChatTools.load('/');
    String name = data.keys.elementAt(widget.chatId);
    await FirebaseChatTools.listPush('$name/data', {
      "sender": 'system',
      "text":
          "${await FirebaseUserTools.load('${FirebaseAuth.instance.currentUser?.uid}/displayName')} gave ${await FirebaseUserTools.load('$uid/displayName')} a kindness badge! Reason: $reason",
    });

    dynamic messagesSnapshot = await FirebaseChatTools.load('$name/data');
    List<MapEntry<String, dynamic>> entries = [];
    if (messagesSnapshot is Map) {
      entries = messagesSnapshot.entries.map((entry) {
        return MapEntry<String, dynamic>(
          entry.key.toString(),
          entry.value,
        );
      }).toList();
    }
    entries = entries.where((entry) {
      final message = entry.value as Map?;
      final sender = message?['sender'] as String?;
      return sender != 'system' && sender != 'ai';
    }).toList();

    int chatLength = entries.length;

    dynamic karmaHistoryRaw =
        await FirebaseChatTools.load('$name/karmaHistory');

    // Convert from Map<Object?, Object?> to Map<String, Map<int, int>>
    Map<String, Map<int, int>> karmaHistory = {};
    if (karmaHistoryRaw is Map) {
      karmaHistoryRaw.forEach((key, value) {
        String userKey = key.toString();
        Map<int, int> userHistory = {};
        if (value is Map) {
          value.forEach((k, v) {
            int messageCount = k is int ? k : int.tryParse(k.toString()) ?? 0;
            int karmaValue = v is int ? v : int.tryParse(v.toString()) ?? 0;
            userHistory[messageCount] = karmaValue;
          });
        }
        karmaHistory[userKey] = userHistory;
      });
    }
    String userEmail = await FirebaseUserTools.load('$uid/email');
    String formattedEmail =
        userEmail.replaceAll('.', '_dot_').replaceAll('@', '_at_');
    // print('ChatLength: $chatLength');

    // Create the user's history map if it doesn't exist
    if (karmaHistory[formattedEmail] == null) {
      karmaHistory[formattedEmail] = {};
    }

    karmaHistory[formattedEmail]![chatLength] =
        (karmaHistory[formattedEmail]![chatLength] ?? 0) + 1;

    // print(karmaHistory);
    await FirebaseChatTools.set('$name/karmaHistory', karmaHistory);
  }

  @override
  Widget build(BuildContext context) {
    Widget mainChatMessage = Container(
        decoration: BoxDecoration(
          // Use BoxDecoration for more styling options
          color: (widget.sender == Sender.self
              ? Colors.green.shade300
              : (widget.sender == Sender.system
                  ? Colors.transparent
                  : Colors.blue.shade300)),
          borderRadius: BorderRadius.circular(12), // Rounded corners
        ),
        child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8), // Adjusted padding
            child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                ),
                child: Text(
                  _censoredValue ?? widget.value,
                  style: const TextStyle(fontSize: 16),
                ))));

    IconButton addButton = IconButton(
        icon: Image.memory(
            base64.decode(
                "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"
                    .replaceAll(RegExp(r'\s'), '')),
            width: 25,
            height: 25,
            fit: BoxFit.cover),
        onPressed: () {
          selectedIcon = null;
          selectedReason = null;
          reasonController.clear();
          showDialog(
              context: context,
              builder: (context) {
                return StatefulBuilder(
                  builder: (context, setDialogState) {
                    return AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: const Text("Give Kindness Badge"),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon selection
                            const Text(
                              "Choose an icon:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildIconOption(
                                  context,
                                  setDialogState,
                                  Icons.favorite,
                                  'Love',
                                  'For being caring and compassionate',
                                ),
                                _buildIconOption(
                                  context,
                                  setDialogState,
                                  Icons.thumb_up,
                                  'Support',
                                  'For being supportive and encouraging',
                                ),
                                _buildIconOption(
                                  context,
                                  setDialogState,
                                  Icons.star,
                                  'Excellence',
                                  'For going above and beyond',
                                ),
                                _buildIconOption(
                                  context,
                                  setDialogState,
                                  Icons.lightbulb,
                                  'Insight',
                                  'For sharing great ideas and wisdom',
                                ),
                                _buildIconOption(
                                  context,
                                  setDialogState,
                                  Icons.celebration,
                                  'Joy',
                                  'For bringing happiness and positivity',
                                ),
                                _buildIconOption(
                                  context,
                                  setDialogState,
                                  Icons.handshake,
                                  'Help',
                                  'For being helpful and reliable',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Custom reason field
                            TextField(
                              decoration: const InputDecoration(
                                hintText: "Enter a reason...",
                              ),
                              controller: reasonController,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedReason = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (selectedIcon != null) {
                              // print("Selected icon: $selectedIcon");
                              String reason = selectedReason ??
                                  _getDefaultReason(selectedIcon!);
                              _giveBadge(reason, selectedIcon!);
                              setState(() {});
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Text("Give Badge"),
                        ),
                      ],
                    );
                  },
                );
              });
        },
        constraints: BoxConstraints.tight(const Size.square(30)),
        iconSize: 25,
        padding: const EdgeInsets.all(2));
    Widget paddedMessage =
        (widget.sender == Sender.self || !widget.senderToken.contains('@'))
            ? mainChatMessage
            : CustomSideTooltip(
                preferredDirection: AxisDirection.right,
                tooltip: addButton,
                child: mainChatMessage,
              );

    Padding padding = const Padding(padding: EdgeInsets.only(left: 5));
    Widget pfpSec = Column(children: <Widget>[
      Image.memory(base64.decode(widget.pfp64.replaceAll(RegExp(r'\s'), '')),
          width: 20, height: 20, fit: BoxFit.cover),
      Text(widget.karma.toString(), style: const TextStyle(fontSize: 10))
    ]);

    return Align(
        alignment: (widget.sender == Sender.self
            ? Alignment.centerRight
            : (widget.sender == Sender.system
                ? Alignment.center
                : Alignment.centerLeft)),
        child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4), // More balanced padding
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.sender == Sender.self
                    ? <Widget>[paddedMessage, padding, pfpSec]
                    : (widget.sender == Sender.system
                        ? <Widget>[
                            padding,
                            Center(child: paddedMessage),
                            padding
                          ]
                        : <Widget>[pfpSec, padding, paddedMessage]))));
  }
}

enum Sender { self, other, system }
