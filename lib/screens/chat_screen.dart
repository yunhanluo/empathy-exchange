import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:empathy_exchange/services/profanity_check.dart';
import 'package:empathy_exchange/widgets/material.dart';
import 'package:empathy_exchange/widgets/message.dart';
import 'package:empathy_exchange/lib/firebase.dart';
import 'package:empathy_exchange/services/openai_service.dart';
import 'package:empathy_exchange/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

int _ppage = 0;

typedef KarmaHistoryRecord = ({
  String user,
  List<FlSpot> history,
  Color color,
});

final List<Color> colorPalette = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.amber,
];

Color getColorForUser(String user) {
  final hash = user.hashCode;
  final index = hash.abs() % colorPalette.length;
  return colorPalette[index];
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatTalkPage extends StatefulWidget {
  const _ChatTalkPage(
      // ignore: unused_element_parameter
      {super.key,
      required this.myToken,
      required this.otherTokens,
      required this.chatId,
      required this.title});

  final String myToken;
  final List otherTokens;
  final int chatId;
  final String title;

  @override
  State<_ChatTalkPage> createState() => _ChatTalkPageState();
}

class _ChatTalkPageState extends State<_ChatTalkPage> {
  final _textController = TextEditingController();
  final _chatNameController = TextEditingController();
  final _inviteTokenController = TextEditingController();
  final _textFocus = FocusNode();

  final _scrollController = ScrollController();

  final List<Widget> _messages = <Widget>[];

  Widget _editButton = const SizedBox.shrink();
  Widget _evaluateButton = const SizedBox.shrink();
  Widget _deleteButton = const SizedBox.shrink();
  Widget _inviteButton = const SizedBox.shrink();

  StreamSubscription<DatabaseEvent>? _subscription;
  DatabaseReference? thisRef;

  String? _actualTitle;
  bool _aiAnalysisEnabled = false;

  bool loading = true;

  @override
  void dispose() {
    _textController.dispose();
    _chatNameController.dispose();
    _inviteTokenController.dispose();
    _textFocus.dispose();

    _scrollController.dispose();

    _subscription?.cancel();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   if (await FirebaseUserTools.load(
    //           '${FirebaseAuth.instance.currentUser?.uid}/karma') <
    //       -100) {
    //     if (mounted) {
    //       showDialog(
    //           context: context,
    //           barrierDismissible: false,
    //           builder: (BuildContext context) {
    //             return AlertDialog(
    //               backgroundColor: Colors.white,
    //               shape: RoundedRectangleBorder(
    //                 borderRadius: BorderRadius.circular(12),
    //               ),
    //               title: const Text("Your account has been terminated."),
    //               content: const Text("Reason: Too little karma."),
    //               actions: [
    //                 TextButton(
    //                     onPressed: () async {
    //                       await FirebaseAuth.instance.signOut();
    //                       if (mounted) Navigator.pop(context);
    //                     },
    //                     child: const Text("Log out"))
    //               ],
    //             );
    //           });
    //     }
    //   }
    // });

    () async {
      try {
        _actualTitle = widget.title;

        Map data = await FirebaseChatTools.load('/');
        Map chat = data.values.elementAt(widget.chatId) as Map;
        dynamic items = chat['data'];

        List<String> theirTokens = FirebaseTools.asList(chat['tokens'])
            .whereType<String>()
            .where((t) => t != widget.myToken)
            .toList();

        Map<String, String> theirPfps = {};
        for (String token in theirTokens) {
          String emailKey =
              token.replaceAll('.', '_dot_').replaceAll('@', '_at_');
          String pfp = await FirebaseUserTools.load(
              'profilePictures/$emailKey/profilePicture');
          // If it's the default profile picture, use empty string to show default avatar
          if (pfp == AuthService.defaultProfilePicture) {
            theirPfps[token] = '';
          } else {
            theirPfps[token] = pfp;
          }
        }

        String myEmailKey =
            widget.myToken.replaceAll('.', '_dot_').replaceAll('@', '_at_');
        String myPfp = await FirebaseUserTools.load(
            'profilePictures/$myEmailKey/profilePicture');
        // If it's the default profile picture, use empty string to show default avatar
        if (myPfp == AuthService.defaultProfilePicture) {
          myPfp = '';
        }

        dynamic uData = await FirebaseUserTools.load('/');
        Map<String, int> theirKarmas = {};
        int myKarma = 0;
        for (Map user in FirebaseTools.asList(uData)) {
          if (!user.containsKey('pairToken')) continue;

          dynamic tokenDynamic = user['pairToken'];
          if (tokenDynamic == null) continue;
          String token = tokenDynamic.toString();
          if (token.isEmpty) continue;
          if (token == widget.myToken) {
            dynamic karmaToParse = user['karma'];
            if (karmaToParse is int) {
              myKarma = karmaToParse;
            } else if (karmaToParse is String) {
              myKarma = int.parse(karmaToParse);
            }
          } else if (theirTokens.contains(token)) {
            dynamic karmaToParse = user['karma'];
            if (karmaToParse is int) {
              theirKarmas[token] = karmaToParse;
            } else if (karmaToParse is String) {
              theirKarmas[token] = int.parse(karmaToParse);
            }
          }
        }

        setState(() {
          List itemList = FirebaseTools.asList(items);
          for (JSAny? item in itemList.take(itemList.length - 1)) {
            Map message = item as Map;
            dynamic textDynamic = message["text"];
            dynamic senderDynamic = message["sender"];
            if (textDynamic == null || senderDynamic == null) continue;
            String text = textDynamic.toString();
            String sender = senderDynamic.toString();
            _messages.add(Message(
                text,
                sender == widget.myToken
                    ? Sender.self
                    : (sender == 'system' ? Sender.system : Sender.other),
                sender,
                sender == "system"
                    ? "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAEvElEQVR4Aeydv69MURDHH7UIBSEUqDQ0KqFRiIZo6IhEgqAQlcQ/oFMo/EiIhGg0KpGIggSVaFQqiValQsV82Lzivb1nzrnnx9yzRs7su+/Md+Y7M989m92V3Ld2yf+ZTsAFMB3/0pIL4AIYT8CY3k+AC2A8AWN6PwEugPEEjOl7PQHnZW6PxL7MjGv25Ne+Vo8CfJAR3xM7LbZjZlyzh0+2+lm9CfBURrtPbGjhAzPk/7c/oceeBOBZfjJidmDARkDtIT0JcCxhXCnYhLTloT0JsD+h/RRsQtry0J4E2J7Qfgo2IW15aE8ClO9+AhldAGMRpi4Ar+UPZEa/xVIXMcSSIzW2GX6KAmyU7q+KvRV7L3ZWbOwilhzkIie5x+aqEjc1AXgP/0Y6vSl2QKzUIhc5yQ1HqbzZeaYiAO9a+CqBT7F7srsaTkBuOOCCcxjZyNNQgMGOeEbyzGz5ZRpccMI9WFgLh7UADIBn5K4Wza7ggBNualjhaverpQA0zgDadTufiRqoZb638q6VADRM4ynt/RTwXbFLYkfF9optmBnX7OEDA1Zc0YtaqCk6oBTQQoCDUjwNy4+o9UpQvJ1k2Bfl+o7Yc7FPYt9nxjV7+MCAJYZYgUQtaqK2KHApkIUA1xKKvy7Yw2IPxX6JxS6wxBBLjti4lNpicwZxrQW4INXwUiE/1HVOEDfEchc5yBWTh9qoMQZbBNNSgG1ScewzjHco9wVfapGLnDH5qJFaY7DZmJYC0NjOiIo3C4b/bJcfRRc5ya0lpUZq1XBF/K0E2CTVnhHT1iEBfBOrtcgNh5afWqlZw2X7WwlwQipdLxZal8X5Wqz2ggOuEA+1UnMIE+XTQK0EOK4UwreVtxVMSTdccIZyajWHYqN9LQTgKB9RKnqm+Gu4NU5qpvYa3Ms5WwigfcLkPTsfoJaLanQBJ9whOq32UGyUr4UAu5VKHov/h1jrBSfcIV6t9lBslK+FAFuUSj4q/ppujVurPbu2KQjwNbuL8Qk07oUQYKsyH20ISniWW+PWas8iJ9hPAFMYtoU4AeuG+/vr4SvlvxcGDxq3Vnt2yS1OQHaRi5xgMQXoSDEXwFgsF8AFMJ6AMb2fABfAeALG9H4CXADjCRjT+wlwAYwnYEzvJ2BxBDDupFN6PwHGwrkALoDxBIzp/QS4AMYTMKb3E+ACGE/AmN5PgAtgPAFjej8BmQLkhrsAuRPMjHcBMgeYG+4C5E4wM94FyBxgbngJAbg1WMi0GkOxLXy59WnxQX8JAYIE7gxPwAUIz6e61wWoPuIwgQsQnk91rwtQfcRhgj4FCPfUldcFMJarhABrpIf/2aT98auEAOPZPdL/lqT1c8BPgLECPQiQ+32Q8YjD9D0I8CLcQtCbExtMXMrZgwCfM5rNic2gjQ/tQYCX8e2sQubErkpWY6MHAXgZeTKieWKIHRHaLiRBgHZFzWE6NWdP2xoTo+Us7u9FABrn0/YVLhQDA1aBTcPdkwBM7JY8cIdzbjvJ/T+5ESvGNXv4wAisj9WbAEz1nTxw41XugMutiDGu2cMn7n5WjwL0M92ISl2AiCHVhLgANacbkdsFiBhSTYgLUHO6EbldgIgh1YS4AMp0a7v/AAAA//9aRXhEAAAABklEQVQDALhvssEXv78aAAAAAElFTkSuQmCC"
                    : (sender == widget.myToken
                        ? myPfp
                        : theirPfps[sender] ??
                            "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAACX0lEQVR4AbyVS+tNURiH999AGfoKBhRFLgkRE5QBGcjAgImRO7lfcr/lzsCQlMQEycDEpeSWXIqk+AxGJhLPs//r1bv3uTgTTr/nfdd69zrrd/Zee60zovrHn/9mMJ4buQTdNJHiC/jV4hn9MdBXcQcfGLUGLkJoLg0nfUeeDm3NoPAFHONYmp0Kgynl0lryBVCPCW/hByyEoRZO+o2aekS4Ah0KgzdcmQlqHeE8qMmEkfAA2npCYTRoRKpWEs5CQ2Fg8TlhM6j1hHOQ9ZSOj0Ne0w5p5N3Z30gIQ5pVlQ0snDEUNpDzLxpFP+Qj1Sj65tkG8HGRhpUNfFus/iRMAOUvClMnHaIopFo+wrpB8A6/k9VYg2SDyxZgEXyEMNlE+zRkhen8XKS9DNR1g2SDWORY0Gzi2pzyC4V4bR+WfqT7pTG15I41iHrkbLKF4klQcwjv4RX0Vb6DXgOzyVYGnQA1yfA3BjFwjmyyjcJxGEjZwH3gl5YbupBNtnP9GLS1oBReltxYgxWleKPkSL6+cdh5ZkV9B42jkHWvdFaX3DD4GkWy234c2c3U67DjcrWTcARCnl22fQHMDQML8wzgwfWJHFpCww2WWUpN7SIcBuXrG3PY7zDwBL1aXxkOt0hOepfc1m0KsRl30z4EyjnMNXmR6wJhFcRB5870MS2m1pa1vCZ7GHAQGupm4ACPh3yrdyhqlLFGuVa8eXvpHYA/6mXgAG/Vx+Ni5+PZa+JfpoedY25SiMe1j/Z+qNXPoB5A+AzTwIkys6jFW0OzyvvkmgUZxMBxg6KJP8L/6vo7vwEAAP//QQI5RQAAAAZJREFUAwC4tmkxSpZfbQAAAABJRU5ErkJggg=="),
                (sender == widget.myToken ? myKarma : theirKarmas[sender] ?? 0),
                widget.chatId));
          }

          thisRef = FirebaseChatTools.ref
              .child('/${data.keys.elementAt(widget.chatId)}/data');
          _subscription = thisRef!.onValue.listen((DatabaseEvent event) async {
            Map item = event.snapshot.children.last.value as Map;
            dynamic senderDynamic = item['sender'];
            if (senderDynamic == null) return;
            String sender = senderDynamic.toString();

            String pfp;
            int karma;

            if (sender != 'system') {
              final emailKey =
                  sender.replaceAll('.', '_dot_').replaceAll('@', '_at_');
              String loadedPfp = await FirebaseUserTools.load(
                  'profilePictures/$emailKey/profilePicture');
              // If it's the default profile picture, use empty string to show default avatar
              if (loadedPfp == AuthService.defaultProfilePicture) {
                pfp = '';
              } else {
                pfp = loadedPfp;
              }
              // print("Look! It's now ${_aiAnalysisEnabled}");
              if (_aiAnalysisEnabled) {
                _analyzeWithAI();
              }

              Map uData = await FirebaseUserTools.load('/');
              karma = 0;
              for (Map user in FirebaseTools.asList(uData)) {
                if (!user.containsKey('pairToken')) continue;

                if (user['pairToken'] == sender) {
                  dynamic karmaToParse = user['karma'];
                  if (karmaToParse is int) {
                    karma = karmaToParse;
                  } else if (karmaToParse is String) {
                    karma = int.parse(karmaToParse);
                  }

                  break;
                }
              }
            } else {
              pfp = "";
              karma = 0;
            }

            dynamic textDynamic = item["text"];
            if (textDynamic == null) return;
            String text = textDynamic.toString();

            if (sender != 'system') {
              _messages.add(Message(
                  text,
                  sender == widget.myToken
                      ? Sender.self
                      : (sender == 'system' ? Sender.system : Sender.other),
                  sender,
                  pfp,
                  karma,
                  widget.chatId));
              if (sender != widget.myToken) {
                _showNotification(text);
              }
            } else if (sender == 'system') {
              _messages.add(Message(
                  text,
                  Sender.system,
                  sender,
                  "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAEvElEQVR4Aeydv69MURDHH7UIBSEUqDQ0KqFRiIZo6IhEgqAQlcQ/oFMo/EiIhGg0KpGIggSVaFQqiValQsV82Lzivb1nzrnnx9yzRs7su+/Md+Y7M989m92V3Ld2yf+ZTsAFMB3/0pIL4AIYT8CY3k+AC2A8AWN6PwEugPEEjOl7PQHnZW6PxL7MjGv25Ne+Vo8CfJAR3xM7LbZjZlyzh0+2+lm9CfBURrtPbGjhAzPk/7c/oceeBOBZfjJidmDARkDtIT0JcCxhXCnYhLTloT0JsD+h/RRsQtry0J4E2J7Qfgo2IW15aE8ClO9+AhldAGMRpi4Ar+UPZEa/xVIXMcSSIzW2GX6KAmyU7q+KvRV7L3ZWbOwilhzkIie5x+aqEjc1AXgP/0Y6vSl2QKzUIhc5yQ1HqbzZeaYiAO9a+CqBT7F7srsaTkBuOOCCcxjZyNNQgMGOeEbyzGz5ZRpccMI9WFgLh7UADIBn5K4Wza7ggBNualjhaverpQA0zgDadTufiRqoZb638q6VADRM4ynt/RTwXbFLYkfF9optmBnX7OEDA1Zc0YtaqCk6oBTQQoCDUjwNy4+o9UpQvJ1k2Bfl+o7Yc7FPYt9nxjV7+MCAJYZYgUQtaqK2KHApkIUA1xKKvy7Yw2IPxX6JxS6wxBBLjti4lNpicwZxrQW4INXwUiE/1HVOEDfEchc5yBWTh9qoMQZbBNNSgG1ScewzjHco9wVfapGLnDH5qJFaY7DZmJYC0NjOiIo3C4b/bJcfRRc5ya0lpUZq1XBF/K0E2CTVnhHT1iEBfBOrtcgNh5afWqlZw2X7WwlwQipdLxZal8X5Wqz2ggOuEA+1UnMIE+XTQK0EOK4UwreVtxVMSTdccIZyajWHYqN9LQTgKB9RKnqm+Gu4NU5qpvYa3Ms5WwigfcLkPTsfoJaLanQBJ9whOq32UGyUr4UAu5VKHov/h1jrBSfcIV6l9lBslK+FAFuUSj4q/ppujVurPbu2KQjwNbuL8Qk07oUQYKsyH20ISniWW+PWas8iJ9hPAFMYtoU4AeuG+/vr4SvlvxcGDxq3Vnt2yS1OQHaRi5xgMQXoSDEXwFgsF8AFMJ6AMb2fABfAeALG9H4CXADjCRjT+wlwAYwnYEzvJ2BxBDDupFN6PwHGwrkALoDxBIzp/QS4AMYTMKb3E+ACGE/AmN5PgAtgPAFjej8BmQLkhrsAuRPMjHcBMgeYG+4C5E4wM94FyBxgbngJAbg1WMi0GkOxLXy59WnxQX8JAYIE7gxPwAUIz6e61wWoPuIwgQsQnk91rwtQfcRhgj4FCPfUldcFMJarhABrpIf/2aT98auEAOPZPdL/lqT1c8BPgLECPQiQ+32Q8YjD9D0I8CLcQtCbExtMXMrZgwCfM5rNic2gjQ/tQYCX8e2sQubErkpWY6MHAXgZeTKieWKIHRHaLiRBgHZFzWE6NWdP2xoTo+Us7u9FABrn0/YVLhQDA1aBTcPdkwBM7JY8cIdzbjvJ/T+5ESvGNXv4wAisj9WbAEz1nTxw41XugMutiDGu2cMn7n5WjwL0M92ISl2AiCHVhLgANacbkdsFiBhSTYgLUHO6EbldgIgh1YS4AMp0a7v/AAAA//9aRXhEAAAABklEQVQDALhvssEXv78aAAAAAElFTkSuQmCC",
                  0,
                  widget.chatId));
              _showNotification(text);
            }

            // print("event recieved: $item");
            // print("message: ${(_messages.last as Message).value}");

            if (mounted) {
              setState(() {});
            }
          });
        });

        final thing = (FirebaseTools.asList(await FirebaseChatTools.load('/'))
            .elementAt(widget.chatId) as Map);
        final Widget evalTemp = thing['owner'] == widget.myToken
            ? IconButton(
                onPressed: () {
                  _showEvaluationConfirmation();
                },
                tooltip: "Evaluate chat",
                icon: const Icon(Icons.psychology))
            : const SizedBox.shrink();
        final Widget deleteTemp = thing['owner'] == widget.myToken
            ? IconButton(
                onPressed: () {
                  _showDeleteConfirmation();
                },
                tooltip: "Delete chat",
                icon: const Icon(Icons.delete))
            : const SizedBox.shrink();
        final Widget editTemp = thing['owner'] == widget.myToken
            ? IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: const Text("Edit Chat Name"),
                          content: TextField(
                            decoration: const InputDecoration(
                              hintText: "Enter new chat name...",
                            ),
                            onSubmitted: (String value) async {
                              _renameChat(value);
                              Navigator.of(context).pop();
                            },
                            controller: _chatNameController,
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
                                _renameChat(_chatNameController.text);
                                setState(() {});
                                Navigator.of(context).pop();
                              },
                              child: const Text("Okay"),
                            ),
                          ],
                        );
                      });
                },
                tooltip: "Edit Chat Name",
                icon: const Icon(Icons.edit))
            : const SizedBox.shrink();
        final Widget inviteTemp = thing['owner'] == widget.myToken
            ? IconButton(
                onPressed: () {
                  _showInviteDialog();
                },
                tooltip: "Invite user",
                icon: const Icon(Icons.person_add))
            : const SizedBox.shrink();

        setState(() {
          _editButton = editTemp;
          _evaluateButton = evalTemp;
          _deleteButton = deleteTemp;
          _inviteButton = inviteTemp;

          loading = false;
        });

        if (mounted && _scrollController.hasClients) {
          setState(() {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            loading = false;
          });
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading chat: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          } catch (_) {
            // Context is no longer valid, ignore
          }
        }
      }
    }();

    // setState(() {});
  }

  Future<void> _showNotification(String messageText) async {
    if (!kIsWeb) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userData = await FirebaseUserTools.load(user.uid);
      if (userData['notificationEnabled'] != true) return;
    } catch (e) {
      return;
    }

    if (html.Notification.permission == 'default') {
      await html.Notification.requestPermission();
    }
    if (html.Notification.permission == 'granted') {
      html.Notification('New Message',
          body: messageText, icon: '/icons/Icon-67.png');
    }
  }

  void _send(String v) async {
    if (v.trim().isEmpty) return;

    bool hasProf = ProfanityFilter.hasProfanity(v);

    // final emailKey = myToken.replaceAll('.', '_dot_').replaceAll('@', '_at_');
    // String pfp = await FirebaseUserTools.load(
    //     'profilePictures/$emailKey/profilePicture');
    // dynamic karmaD = await FirebaseUserTools.load(
    //     '${FirebaseAuth.instance.currentUser?.uid}/karma');
    // int karma =
    //     karmaD is int ? karmaD : (karmaD is String ? int.parse(karmaD) : 0);

    setState(() {
      // _messages.add(Message(value, Sender.self, pfp, karma));

      _textController.clear();
      _textFocus.requestFocus();
    });

    Map data = await FirebaseChatTools.load('/');
    String name = data.keys.elementAt(widget.chatId);
    await FirebaseChatTools.listPush('$name/data', {
      "sender": widget.myToken,
      "text": v,
    });

    if (hasProf) {
      dynamic thing = await FirebaseUserTools.load(
          '${FirebaseAuth.instance.currentUser?.uid}/karma');
      if (thing is int) {
        await FirebaseUserTools.set(
            '${FirebaseAuth.instance.currentUser?.uid}/karma',
            thing - ProfanityFilter.getProfanities(v));
      } else if (thing is String) {
        await FirebaseUserTools.set(
            '${FirebaseAuth.instance.currentUser?.uid}/karma',
            int.parse(thing) - ProfanityFilter.getProfanities(v));
      }
    }

    if (await FirebaseUserTools.load(
            '${FirebaseAuth.instance.currentUser?.uid}/karma') <=
        -100) {
      if (mounted) {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context2) {
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: const Text("Your account has been terminated."),
                content: const Text("Reason: Too little karma."),
                actions: [
                  TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          try {
                            Navigator.pop(context);
                          } catch (_) {
                            // Context is no longer valid, ignore
                          }
                        }

                        if (mounted) {
                          setState(() {});
                        }
                      },
                      child: const Text("Log out"))
                ],
              );
            });
      }
    }
  }

  Future<void> _showInviteDialog() async {
    if (!mounted) return;

    final inviteController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Invite User'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Enter the user\'s pairing token or email to invite them to this chat.'),
                const SizedBox(height: 16),
                TextField(
                  controller: inviteController,
                  decoration: const InputDecoration(
                    hintText: "Enter pairing token or email...",
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Invite')),
            ]),
      );

      if (!mounted) return;

      if (confirmed == true) {
        final token = inviteController.text.trim();
        if (token.isNotEmpty && mounted) {
          await _inviteUser(token);
        }
      }
    } finally {
      inviteController.dispose();
    }
  }

  Future<void> _inviteUser(String token) async {
    try {
      // Check if user exists
      String? uid = await FirebaseUserTools.getUidFromToken(token);
      if (uid == null) {
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'User not found. Please check the pairing token or email.'),
                backgroundColor: Colors.red,
              ),
            );
          } catch (_) {
            // Context is no longer valid, ignore
          }
        }
        return;
      }

      Map data = await FirebaseChatTools.load('/');
      String chatKey = data.keys.elementAt(widget.chatId);
      Map chat = data.values.elementAt(widget.chatId) as Map;

      // Get current tokens
      List<String> currentTokens =
          FirebaseTools.asList(chat['tokens']).whereType<String>().toList();
      List<String> currentPendingTokens = [];
      if (chat.containsKey('pendingTokens') && chat['pendingTokens'] != null) {
        currentPendingTokens = FirebaseTools.asList(chat['pendingTokens'])
            .whereType<String>()
            .toList();
      }

      // Check if user is already in the chat
      if (currentTokens.contains(token)) {
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User is already in this chat.'),
                backgroundColor: Colors.orange,
              ),
            );
          } catch (_) {
            // Context is no longer valid, ignore
          }
        }
        return;
      }

      if (currentPendingTokens.contains(token)) {
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User has already been invited to this chat.'),
                backgroundColor: Colors.orange,
              ),
            );
          } catch (_) {
            // Context is no longer valid, ignore
          }
        }
        return;
      }

      // Add the new token
      currentPendingTokens.add(token);
      print("Current pending tokens! $currentPendingTokens");
      currentPendingTokens.sort();

      // Update the chat tokens
      await FirebaseChatTools.set(
          '$chatKey/pendingTokens', currentPendingTokens);
      // Get display name for the invited user
      String invitedDisplayName =
          await FirebaseUserTools.load('$uid/displayName');

      // Send system message
      await FirebaseChatTools.listPush('$chatKey/data', {
        'sender': 'system',
        'text': '$invitedDisplayName has been invited to this chat.',
      });

      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('$invitedDisplayName has been invited to the chat.'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (_) {
          // Context is no longer valid, ignore
        }
      }
    } catch (e) {
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error inviting user: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (_) {
          // Context is no longer valid, ignore
        }
      }
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('Delete Chat'),
          content: const Text(
              'Are you sure you want to delete this chat? This action cannot be undone. Only the owner can delete the chat.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete')),
          ]),
    );
    if (confirmed == true) {
      Map data = await FirebaseChatTools.load('/');
      String chatKey = data.keys.elementAt(widget.chatId);
      await FirebaseChatTools.ref.child(chatKey).remove();
    }
  }

  Future<void> _showEvaluationConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evaluate Chat'),
        content: const Text(
          'This will evaluate the last 10 messages for all participants and assign kindness points. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _analyzeWithAI(type: 'owner');
    }
  }

  Future<void> _analyzeWithAI({String type = 'message'}) async {
    try {
      await OpenAIService.analyzeMessage(
        chatId: widget.chatId,
        type: type,
      );
    } catch (e) {
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (_) {
          // Context is no longer valid, ignore
        }
      }
    }
  }

  void _renameChat(String newName) async {
    if (newName.trim().isEmpty) return;

    Map data = await FirebaseChatTools.load('/');
    String chatKey = data.keys.elementAt(widget.chatId);

    await FirebaseChatTools.set(
        '/$chatKey/title', ProfanityFilter.censor(newName.trim()));

    setState(() {
      _actualTitle = ProfanityFilter.censor(newName.trim());
    });
  }

  Future<List<KarmaHistoryRecord>> _formatKarmaHistory() async {
    Map data = await FirebaseChatTools.load('/');
    String chatKey = data.keys.elementAt(widget.chatId).toString();

    if (!await FirebaseChatTools.exists('$chatKey/karmaHistory')) {
      return [];
    }

    dynamic karmaHistoryRaw =
        await FirebaseChatTools.load('$chatKey/karmaHistory');

    // Convert from Map<Object?, Object?> to Map<String, Map<int, int>>
    Map<String, Map<int, int>> karmaHistory = {};
    if (karmaHistoryRaw is Map) {
      karmaHistoryRaw.forEach((key, value) {
        String userKey = key.toString();
        Map<int, int> userHistory = {};
        if (value is Map) {
          if (!value.containsKey(0)) userHistory[0] = 0;

          value.forEach((k, v) {
            int messageCount = k is int ? k : int.tryParse(k.toString()) ?? 0;
            int karmaValue = v is int ? v : int.tryParse(v.toString()) ?? 0;
            userHistory[messageCount] = karmaValue;
          });
        }
        karmaHistory[userKey] = userHistory;
      });
    }
    List<KarmaHistoryRecord> formattedHistory = [];
    int lastMessageTime = karmaHistory.values
        .expand((userHistory) => userHistory.keys)
        .reduce(max);

    for (MapEntry<String, Map<int, int>> entry in karmaHistory.entries) {
      String user = entry.key;

      List<FlSpot> spots = [];
      int lastMessageValue = 0;
      for (int i = entry.value.keys.first; i <= lastMessageTime; i += 5) {
        if (entry.value.containsKey(i)) {
          int karmaValue = entry.value[i]!;
          spots.add(FlSpot(i.toDouble(),
              lastMessageValue.toDouble() + karmaValue.toDouble()));
          lastMessageValue += karmaValue;
        } else {
          spots.add(FlSpot(i.toDouble(), lastMessageValue.toDouble()));
        }
      }

      var record = (user: user, history: spots, color: getColorForUser(user));
      formattedHistory.add(record);
    }
    return formattedHistory;
  }

  @override
  Widget build(BuildContext context) {
    return appInstance(Column(children: <Widget>[
      AppBar(title: Text(_actualTitle ?? widget.title), actions: [
        _editButton,
        IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: const Text("Kindness History Chart"),
                      content: SizedBox(
                          height: 350,
                          width: 300,
                          child: FutureBuilder<List<KarmaHistoryRecord>>(
                            future: _formatKarmaHistory(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError ||
                                  !snapshot.hasData ||
                                  snapshot.data!.isEmpty) {
                                return const Center(
                                    child:
                                        Text('No kindness history available'));
                              }

                              final karmaHistory = snapshot.data!;

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Legend
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: karmaHistory.map((record) {
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: record.color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            record.user
                                                .replaceAll('_at_', '@')
                                                .replaceAll('_dot_', '.'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 8),
                                  // Chart
                                  Expanded(
                                    child: LineChart(
                                      LineChartData(
                                        gridData: const FlGridData(show: true),
                                        titlesData: FlTitlesData(
                                          leftTitles: const AxisTitles(
                                            axisNameWidget: Tooltip(
                                              message:
                                                  'This tracks how many karma points you have gained or lost during this chat.',
                                              child: Text(
                                                'Karma Points',
                                                style: TextStyle(
                                                  color: Color(0xff37434d),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                          topTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                          rightTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 40,
                                              getTitlesWidget: (value, meta) {
                                                return Text(
                                                  value.toInt().toString(),
                                                  style: const TextStyle(
                                                    color: Color(0xff37434d),
                                                    fontSize: 10,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          bottomTitles: AxisTitles(
                                            axisNameWidget: const Tooltip(
                                              message:
                                                  'Point deductions or additions are made every 5 messages. The x-axis shows how your kindness points have changed over time.',
                                              child: Text(
                                                'Time',
                                                style: TextStyle(
                                                  color: Color(0xff37434d),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 30,
                                              getTitlesWidget: (value, meta) {
                                                // Only show labels for values divisible by 5
                                                if (value % 5 == 0) {
                                                  return Text(
                                                    value.toInt().toString(),
                                                    style: const TextStyle(
                                                      color: Color(0xff37434d),
                                                      fontSize: 10,
                                                    ),
                                                  );
                                                }
                                                return const Text('');
                                              },
                                            ),
                                          ),
                                        ),
                                        borderData: FlBorderData(
                                          show: true,
                                          border: Border.all(
                                              color: const Color(0xff37434d)),
                                        ),
                                        lineBarsData:
                                            karmaHistory.map((record) {
                                          return LineChartBarData(
                                            spots: record.history,
                                            isCurved: true,
                                            color: record.color,
                                            barWidth: 3,
                                            dotData:
                                                const FlDotData(show: true),
                                            belowBarData:
                                                BarAreaData(show: false),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text("Close"),
                        )
                      ]);
                },
              );
            },
            tooltip: "Show Karma Chart",
            icon: const Icon(Icons.show_chart)),
        _evaluateButton,
        _deleteButton,
        _inviteButton
      ]),
      Column(children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.blueGrey.shade100,
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
          ),
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height -
              56 -
              56 -
              6 -
              kBottomNavigationBarHeight,
          child: SafeArea(
              child: SingleChildScrollView(
            controller: _scrollController,
            reverse: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: loading
                  ? Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.sizeOf(context).height / 2),
                      child: const Center(child: CircularProgressIndicator()))
                  : Column(
                      children: _messages,
                      // children: <Widget>[
                      //   StreamBuilder<DatabaseEvent>(stream: thisRef?.onValue, builder: (context, snapshot) {
                      //     if (snapshot.hasError) return const Message("An error occured.", Sender.other);
                      //     if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();

                      //     final dynamic data = snapshot.data!.snapshot.value;
                      //     return Message("$data", Sender.other);
                      //   }),
                      // ],
                    ),
            ),
          )),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            color: Colors.lightBlue.shade100,
            height: 60,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.only(left: 10, right: 5),
                  width: MediaQuery.sizeOf(context).width - 130,
                  child: TextField(
                    onSubmitted: (String value) {
                      _send(value);
                    },
                    controller: _textController,
                    focusNode: _textFocus,
                    autofocus: false,
                    decoration:
                        const InputDecoration(hintText: "Say something..."),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
                  width: 50,
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _aiAnalysisEnabled = !_aiAnalysisEnabled;
                        print("Look! It's now ${_aiAnalysisEnabled}");
                      });
                    },
                    tooltip: _aiAnalysisEnabled
                        ? "Disable AI Analysis (Your End Only)"
                        : "Enable AI Analysis (Your End Only)",
                    icon: _aiAnalysisEnabled
                        ? const Icon(Icons.psychology, size: 24)
                        : const Icon(Icons.cancel, size: 20, color: Colors.red),
                    color: _aiAnalysisEnabled
                        ? const Color(0xFF667eea)
                        : Colors.grey,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
                  width: 60,
                  child: FloatingActionButton(
                    onPressed: () {
                      _send(_textController.value.text);
                    },
                    tooltip: "Send",
                    child: const Icon(Icons.send),
                  ),
                ),
              ],
            ),
          ),
        ),
      ])
    ]));
  }
}

class _ChatPageState extends State<ChatPage> {
  TextEditingController uidController = TextEditingController();

  final List<Widget> _chats = <Widget>[];
  final List<Widget> _chatPages = <Widget>[];
  final List<Widget> _pendingInvitations = <Widget>[];

  bool _loading = false;

  void _runOpenChat(String enteredUid) {
    if (!mounted) return;

    () async {
      String myToken = await FirebaseUserTools.load(
          '${FirebaseAuth.instance.currentUser!.uid}/pairToken');

      List<String> parts = [myToken, enteredUid];
      parts.sort();

      try {
        await FirebaseChatTools.listPush('/', {
          "tokens": parts,
          "owner": myToken,
          "title":
              '${await FirebaseUserTools.load('${FirebaseAuth.instance.currentUser!.uid}/displayName')} & ${await FirebaseUserTools.load('${await FirebaseUserTools.getUidFromToken(enteredUid)}/displayName')}',
          "data": [
            {"text": "This chat was created.", "sender": "system"},
          ],
        });

        if (mounted) {
          try {
            Navigator.of(context).pop();
          } catch (_) {
            // Context is no longer valid, ignore
          }
        }
        await rebuildChats();
      } catch (e) {
        // print(e);
        if (mounted) {
          try {
            Navigator.of(context).pop();
          } catch (_) {
            // Context is no longer valid, ignore
          }
        }
        await rebuildChats();
        return;
      } finally {
        if (mounted) {
          setState(() {});
        }
      }
    }();
  }

  Future<void> _addChatTalkPage(
      String myToken, List oTokens, String? title, int cid) async {
    List<Widget> pfps = [];
    List<String> tokens = oTokens.whereType<String>().toList();
    for (String token in tokens) {
      if (await FirebaseUserTools.getUidFromToken(token) == null) {
        return;
      }

      String emailKey = token.replaceAll('.', '_dot_').replaceAll('@', '_at_');

      String pfp = await FirebaseUserTools.load(
          'profilePictures/$emailKey/profilePicture');

      if (pfp == AuthService.defaultProfilePicture) {
        pfp = '';
      }

      if (pfp.isEmpty) {
        // Show default avatar
        pfps.add(Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF667eea),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.person,
            size: 12,
            color: Color(0xFF667eea),
          ),
        ));
      } else {
        pfps.add(Image.memory(base64.decode(pfp.replaceAll(RegExp(r'\s'), '')),
            width: 20, height: 20, fit: BoxFit.cover));
      }
    }

    final int thisid = _chats.length + 1;

    _chatPages.add(_ChatTalkPage(
        myToken: myToken,
        otherTokens: oTokens,
        chatId: cid,
        title: title ?? "Chat ${_chats.length + 1}"));
    _chats.add(TextButton(
      onPressed: () {
        _ppage = thisid;
        Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (context) => _chatPages[_ppage - 1]));
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero, // Square corners
        ),
      ),
      child: Container(
        width: double.infinity, // Make the button fill the entire width
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                  maxHeight: 25, maxWidth: 100, minHeight: 20, minWidth: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: pfps,
              ),
            ),
            ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth:
                        mounted ? MediaQuery.sizeOf(context).width - 220 : 100),
                child: Text(
                  title ?? "Chat ${_chats.length + 1}",
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.left,
                )),
            const Icon(
              Icons.arrow_forward_ios, // Right arrow icon
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    ));

    if (mounted) setState(() {});
  }

  Future<void> _acceptInvitation(int chatIndex, String chatKey) async {
    try {
      String myToken = await FirebaseUserTools.load(
          '${FirebaseAuth.instance.currentUser!.uid}/pairToken');

      Map data = await FirebaseChatTools.load('/');
      Map chat = data.values.elementAt(chatIndex) as Map;

      List<String> currentTokens =
          FirebaseTools.asList(chat['tokens']).whereType<String>().toList();
      List<String> currentPendingTokens = [];
      if (chat.containsKey('pendingTokens') && chat['pendingTokens'] != null) {
        currentPendingTokens = FirebaseTools.asList(chat['pendingTokens'])
            .whereType<String>()
            .toList();
      }

      // Remove from pending and add to tokens
      currentPendingTokens.remove(myToken);
      currentTokens.add(myToken);
      currentTokens.sort();

      // Update both lists
      await FirebaseChatTools.set('$chatKey/tokens', currentTokens);
      if (currentPendingTokens.isEmpty) {
        await FirebaseChatTools.ref.child('$chatKey/pendingTokens').remove();
      } else {
        await FirebaseChatTools.set(
            '$chatKey/pendingTokens', currentPendingTokens);
      }

      // Send system message
      await FirebaseChatTools.listPush('$chatKey/data', {
        'sender': 'system',
        'text':
            '${await FirebaseUserTools.load('${FirebaseAuth.instance.currentUser!.uid}/displayName')} has joined the chat.',
      });

      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invitation accepted!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (_) {
          // Context is no longer valid, ignore
        }
      }

      await rebuildChats();
    } catch (e) {
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error accepting invitation: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (_) {
          // Context is no longer valid, ignore
        }
      }
    }
  }

  Future<void> _rejectInvitation(int chatIndex, String chatKey) async {
    try {
      String myToken = await FirebaseUserTools.load(
          '${FirebaseAuth.instance.currentUser!.uid}/pairToken');

      Map data = await FirebaseChatTools.load('/');
      Map chat = data.values.elementAt(chatIndex) as Map;

      List<String> currentPendingTokens = [];
      if (chat.containsKey('pendingTokens') && chat['pendingTokens'] != null) {
        currentPendingTokens = FirebaseTools.asList(chat['pendingTokens'])
            .whereType<String>()
            .toList();
      }

      // Remove from pending
      currentPendingTokens.remove(myToken);

      // Update or remove pendingTokens
      if (currentPendingTokens.isEmpty) {
        await FirebaseChatTools.ref.child('$chatKey/pendingTokens').remove();
      } else {
        await FirebaseChatTools.set(
            '$chatKey/pendingTokens', currentPendingTokens);
      }

      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invitation rejected.'),
              backgroundColor: Colors.orange,
            ),
          );
        } catch (_) {
          // Context is no longer valid, ignore
        }
      }

      await rebuildChats();
    } catch (e) {
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting invitation: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (_) {
          // Context is no longer valid, ignore
        }
      }
    }
  }

  Future<void> _addPendingInvitation(String myToken, Map data, String chatKey,
      int chatIndex, String? title) async {
    List<Widget> pfps = [];
    List<String> allTokens = [];

    // Get all tokens (both active and pending)
    print(
        "The data does ${(data.containsKey('tokens')) ? "" : "not"} have tokens");
    print(
        "The data does ${(data.containsKey('pendingTokens') && data['pendingTokens'] != null) ? "" : "not"} have pending tokens");
    if (data.containsKey('tokens')) {
      allTokens.addAll(
          FirebaseTools.asList(data['tokens']).whereType<String>().toList());
    }
    if (data.containsKey('pendingTokens') && data['pendingTokens'] != null) {
      allTokens.addAll(FirebaseTools.asList(data['pendingTokens'])
          .whereType<String>()
          .toList());
    }
    print("All tokens! $allTokens");

    // Remove myToken from the list to show other participants
    allTokens.remove(myToken);
    print("This is going as planned so far");

    for (String token in allTokens) {
      if (await FirebaseUserTools.getUidFromToken(token) == null) {
        print("Oops!");
        continue;
      }

      String emailKey = token.replaceAll('.', '_dot_').replaceAll('@', '_at_');

      try {
        String pfp = await FirebaseUserTools.load(
            'profilePictures/$emailKey/profilePicture');

        if (pfp == AuthService.defaultProfilePicture) {
          pfp = '';
        }

        if (pfp.isEmpty) {
          print("Adding default profile picture!");
          pfps.add(Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF667eea),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.person,
              size: 12,
              color: Color(0xFF667eea),
            ),
          ));
        } else {
          print("Adding a non-default profile picture!");
          pfps.add(Image.memory(
              base64.decode(pfp.replaceAll(RegExp(r'\s'), '')),
              width: 20,
              height: 20,
              fit: BoxFit.cover));
        }
      } catch (e) {
        print("Error loading profile picture! $e");
        // If profile picture fails to load, show default
        pfps.add(Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF667eea),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.person,
            size: 12,
            color: Color(0xFF667eea),
          ),
        ));
      }
    }

    print("Adding pending invitation to the list!");
    _pendingInvitations.add(Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (pfps.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxHeight: 25,
                      maxWidth: 100,
                      minHeight: 20,
                      minWidth: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: pfps,
                  ),
                ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth:
                        mounted ? MediaQuery.sizeOf(context).width - 300 : 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? "Chat Invitation",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const Text(
                      "You've been invited to join",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _rejectInvitation(chatIndex, chatKey),
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: "Reject",
              ),
              IconButton(
                onPressed: () => _acceptInvitation(chatIndex, chatKey),
                icon: const Icon(Icons.check, color: Colors.green),
                tooltip: "Accept",
              ),
            ],
          ),
        ],
      ),
    ));
    print("That worked!");
    print("Pending invitations! $_pendingInvitations");
  }

  Future<void> rebuildChats() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      _chats.clear();
      _chatPages.clear();
      _pendingInvitations.clear();

      // Check if chats path exists before loading
      bool chatsExist = await FirebaseChatTools.exists('/');
      if (!chatsExist) {
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _loading = false;
              });
            }
          });
        }

        return;
      }

      JSAny chatArray = await FirebaseChatTools.load('/');

      if (!mounted) return;

      String myToken = await FirebaseUserTools.load(
          '${FirebaseAuth.instance.currentUser!.uid}/pairToken');
      print("My token! $myToken");

      List chats = FirebaseTools.asList(chatArray.dartify());
      Map data = await FirebaseChatTools.load('/');

      for (int i = 0; i < chats.length; i++) {
        JSAny? chat = chats[i];
        Map chatData = chat.dartify() as Map;
        dynamic chatKeyDynamic = data.keys.elementAt(i);
        if (chatKeyDynamic == null) continue;
        String chatKey = chatKeyDynamic.toString();

        List<String> tokens = FirebaseTools.asList(chatData['tokens'])
            .whereType<String>()
            .toList();
        List<String> pendingTokens = [];
        if (chatData.containsKey('pendingTokens') &&
            chatData['pendingTokens'] != null) {
          pendingTokens = FirebaseTools.asList(chatData['pendingTokens'])
              .whereType<String>()
              .toList();
        }
        print("Tokens! $tokens");
        print("Pending tokens! $pendingTokens");

        if (tokens.contains(myToken)) {
          dynamic titleDynamic = chatData['title'];
          String? title = titleDynamic?.toString();
          await _addChatTalkPage(myToken,
              tokens.where((token) => token != myToken).toList(), title, i);
        } else if (pendingTokens.contains(myToken)) {
          dynamic titleDynamic = chatData['title'];
          String? title = titleDynamic?.toString();
          print("Adding pending invitation title! $title");
          await _addPendingInvitation(myToken, chatData, chatKey, i, title);
        }
      }
    } catch (e) {
      // Only show error if it's not a "path not found" error (which means no chats)
      if (mounted && !e.toString().contains('Firebase path not found')) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading chats: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (_) {
          // Context is no longer valid, ignore
        }
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _loading = false;
            });
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    if (!ProfanityFilter.initialized) {
      ProfanityFilter.init();
    }

    () async {
      await rebuildChats();
    }();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuild chats when page becomes visible again
    () async {
      await rebuildChats();
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(
                color: Colors.black,
                width: 3,
                style: BorderStyle.solid,
              ))),
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height -
              56 -
              kBottomNavigationBarHeight,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _chats.isEmpty && _pendingInvitations.isEmpty
                  ? const Center(
                      child: Text(
                        'No chats yet. Create a new chat to get started!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        ..._pendingInvitations,
                        ..._chats,
                      ],
                    ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            label: const Text("New Chat"),
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: const Text("Create New Chat"),
                      content: TextField(
                        decoration: const InputDecoration(
                          hintText: "Enter other user's pairing token...",
                        ),
                        onSubmitted: (String value) async {
                          _runOpenChat(value);
                          setState(() {});
                        },
                        controller: uidController,
                        maxLength: 150,
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
                            _runOpenChat(uidController.text);
                            setState(() {});
                          },
                          child: const Text("Okay"),
                        ),
                      ],
                    );
                  },
                );
              });
            },
          ),
        ),
      ],
    );
  }
}
