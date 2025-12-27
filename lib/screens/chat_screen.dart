import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:empathy_exchange/widgets/material.dart';
import 'package:empathy_exchange/widgets/message.dart';
import 'package:empathy_exchange/lib/firebase.dart';
import 'package:empathy_exchange/services/openai_service.dart';
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
  final _textFocus = FocusNode();

  final _scrollController = ScrollController();

  final List<Widget> _messages = <Widget>[];

  Widget _evaluateButton = const SizedBox.shrink();

  StreamSubscription<DatabaseEvent>? _subscription;
  DatabaseReference? thisRef;

  String? _actualTitle;
  bool _aiAnalysisEnabled = false;

  bool loading = true;

  @override
  void dispose() {
    _textController.dispose();
    _chatNameController.dispose();
    _textFocus.dispose();

    _scrollController.dispose();

    _subscription?.cancel();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    () async {
      _actualTitle = widget.title;

      Map data = await FirebaseChatTools.load('/');
      Map chat = data.values.elementAt(widget.chatId) as Map;
      dynamic items = chat['data'];

      Iterable theirTokens = FirebaseTools.asList(chat['tokens'])
          .where((t) => t != widget.myToken);

      Map<String, String> theirPfps = {};
      for (String token in theirTokens) {
        String emailKey =
            token.replaceAll('.', '_dot_').replaceAll('@', '_at_');
        theirPfps[token] = await FirebaseUserTools.load(
            'profilePictures/$emailKey/profilePicture');
      }

      String myEmailKey =
          widget.myToken.replaceAll('.', '_dot_').replaceAll('@', '_at_');
      String myPfp = await FirebaseUserTools.load(
          'profilePictures/$myEmailKey/profilePicture');

      dynamic uData = await FirebaseUserTools.load('/');
      Map<String, int> theirKarmas = {};
      int myKarma = 0;
      for (Map user in FirebaseTools.asList(uData)) {
        if (!user.containsKey('pairToken')) continue;

        String token = user['pairToken'];
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

      List itemList = FirebaseTools.asList(items);
      for (JSAny? item in itemList.take(itemList.length - 1)) {
        setState(() {
          Map message = item as Map;
          _messages.add(Message(
              message["text"],
              message["sender"] == widget.myToken
                  ? Sender.self
                  : (message["sender"] == 'system'
                      ? Sender.system
                      : Sender.other),
              message["sender"],
              message["sender"] == "system"
                  ? "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAEvElEQVR4Aeydv69MURDHH7UIBSEUqDQ0KqFRiIZo6IhEgqAQlcQ/oFMo/EiIhGg0KpGIggSVaFQqiValQsV82Lzivb1nzrnnx9yzRs7su+/Md+Y7M989m92V3Ld2yf+ZTsAFMB3/0pIL4AIYT8CY3k+AC2A8AWN6PwEugPEEjOl7PQHnZW6PxL7MjGv25Ne+Vo8CfJAR3xM7LbZjZlyzh0+2+lm9CfBURrtPbGjhAzPk/7c/oceeBOBZfjJidmDARkDtIT0JcCxhXCnYhLTloT0JsD+h/RRsQtry0J4E2J7Qfgo2IW15aE8ClO9+AhldAGMRpi4Ar+UPZEa/xVIXMcSSIzW2GX6KAmyU7q+KvRV7L3ZWbOwilhzkIie5x+aqEjc1AXgP/0Y6vSl2QKzUIhc5yQ1HqbzZeaYiAO9a+CqBT7F7srsaTkBuOOCCcxjZyNNQgMGOeEbyzGz5ZRpccMI9WFgLh7UADIBn5K4Wza7ggBNualjhaverpQA0zgDadTufiRqoZb638q6VADRM4ynt/RTwXbFLYkfF9optmBnX7OEDA1Zc0YtaqCk6oBTQQoCDUjwNy4+o9UpQvJ1k2Bfl+o7Yc7FPYt9nxjV7+MCAJYZYgUQtaqK2KHApkIUA1xKKvy7Yw2IPxX6JxS6wxBBLjti4lNpicwZxrQW4INXwUiE/1HVOEDfEchc5yBWTh9qoMQZbBNNSgG1ScewzjHco9wVfapGLnDH5qJFaY7DZmJYC0NjOiIo3C4b/bJcfRRc5ya0lpUZq1XBF/K0E2CTVnhHT1iEBfBOrtcgNh5afWqlZw2X7WwlwQipdLxZal8X5Wqz2ggOuEA+1UnMIE+XTQK0EOK4UwreVtxVMSTdccIZyajWHYqN9LQTgKB9RKnqm+Gu4NU5qpvYa3Ms5WwigfcLkPTsfoJaLanQBJ9whOq32UGyUr4UAu5VKHov/h1jrBSfcIV6t9lBslK+FAFuUSj4q/ppujVurPbu2KQjwNbuL8Qk07oUQYKsyH20ISniWW+PWas8iJ9hPAFMYtoU4AeuG+/vr4SvlvxcGDxq3Vnt2yS1OQHaRi5xgMQXoSDEXwFgsF8AFMJ6AMb2fABfAeALG9H4CXADjCRjT+wlwAYwnYEzvJ2BxBDDupFN6PwHGwrkALoDxBIzp/QS4AMYTMKb3E+ACGE/AmN5PgAtgPAFjej8BmQLkhrsAuRPMjHcBMgeYG+4C5E4wM94FyBxgbngJAbg1WMi0GkOxLXy59WnxQX8JAYIE7gxPwAUIz6e61wWoPuIwgQsQnk91rwtQfcRhgj4FCPfUldcFMJarhABrpIf/2aT98auEAOPZPdL/lqT1c8BPgLECPQiQ+32Q8YjD9D0I8CLcQtCbExtMXMrZgwCfM5rNic2gjQ/tQYCX8e2sQubErkpWY6MHAXgZeTKieWKIHRHaLiRBgHZFzWE6NWdP2xoTo+Us7u9FABrn0/YVLhQDA1aBTcPdkwBM7JY8cIdzbjvJ/T+5ESvGNXv4wAisj9WbAEz1nTxw41XugMutiDGu2cMn7n5WjwL0M92ISl2AiCHVhLgANacbkdsFiBhSTYgLUHO6EbldgIgh1YS4AMp0a7v/AAAA//9aRXhEAAAABklEQVQDALhvssEXv78aAAAAAElFTkSuQmCC"
                  : (message["sender"] == widget.myToken
                      ? myPfp
                      : theirPfps[message['sender']] ??
                          "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAACX0lEQVR4AbyVS+tNURiH999AGfoKBhRFLgkRE5QBGcjAgImRO7lfcr/lzsCQlMQEycDEpeSWXIqk+AxGJhLPs//r1bv3uTgTTr/nfdd69zrrd/Zee60zovrHn/9mMJ4buQTdNJHiC/jV4hn9MdBXcQcfGLUGLkJoLg0nfUeeDm3NoPAFHONYmp0Kgynl0lryBVCPCW/hByyEoRZO+o2aekS4Ah0KgzdcmQlqHeE8qMmEkfAA2npCYTRoRKpWEs5CQ2Fg8TlhM6j1hHOQ9ZSOj0Ne0w5p5N3Z30gIQ5pVlQ0snDEUNpDzLxpFP+Qj1Sj65tkG8HGRhpUNfFus/iRMAOUvClMnHaIopFo+wrpB8A6/k9VYg2SDyxZgEXyEMNlE+zRkhen8XKS9DNR1g2SDWORY0Gzi2pzyC4V4bR+WfqT7pTG15I41iHrkbLKF4klQcwjv4RX0Vb6DXgOzyVYGnQA1yfA3BjFwjmyyjcJxGEjZwH3gl5YbupBNtnP9GLS1oBReltxYgxWleKPkSL6+cdh5ZkV9B42jkHWvdFaX3DD4GkWy234c2c3U67DjcrWTcARCnl22fQHMDQML8wzgwfWJHFpCww2WWUpN7SIcBuXrG3PY7zDwBL1aXxkOt0hOepfc1m0KsRl30z4EyjnMNXmR6wJhFcRB5870MS2m1pa1vCZ7GHAQGupm4ACPh3yrdyhqlLFGuVa8eXvpHYA/6mXgAG/Vx+Ni5+PZa+JfpoedY25SiMe1j/Z+qNXPoB5A+AzTwIkys6jFW0OzyvvkmgUZxMBxg6KJP8L/6vo7vwEAAP//QQI5RQAAAAZJREFUAwC4tmkxSpZfbQAAAABJRU5ErkJggg=="),
              (message["sender"] == widget.myToken
                  ? myKarma
                  : theirKarmas[message['sender']] ?? 0),
              widget.chatId));
        });
      }

      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

      setState(() {
        thisRef = FirebaseChatTools.ref
            .child('/${data.keys.elementAt(widget.chatId)}/data');
        _subscription = thisRef?.onValue.listen((event) async {
          Map item = event.snapshot.children.last.value as Map;
          String sender = item['sender'];

          String pfp;
          int karma;

          if (sender != 'system') {
            final emailKey =
                sender.replaceAll('.', '_dot_').replaceAll('@', '_at_');
            pfp = await FirebaseUserTools.load(
                'profilePictures/$emailKey/profilePicture');
            print("Look! It's now ${_aiAnalysisEnabled}");
            if (_aiAnalysisEnabled) {
              _analyzeWithAI(type: 'owner');
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

          setState(() {
            if (sender != 'system') {
              _messages.add(Message(
                  item["text"],
                  sender == widget.myToken
                      ? Sender.self
                      : (sender == 'system' ? Sender.system : Sender.other),
                  sender,
                  pfp,
                  karma,
                  widget.chatId));
              if (sender != widget.myToken) {
                _showNotification(item['text']);
              }
            } else if (sender == 'system') {
              _messages.add(Message(
                  item["text"],
                  Sender.system,
                  sender,
                  "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAEvElEQVR4Aeydv69MURDHH7UIBSEUqDQ0KqFRiIZo6IhEgqAQlcQ/oFMo/EiIhGg0KpGIggSVaFQqiValQsV82Lzivb1nzrnnx9yzRs7su+/Md+Y7M989m92V3Ld2yf+ZTsAFMB3/0pIL4AIYT8CY3k+AC2A8AWN6PwEugPEEjOl7PQHnZW6PxL7MjGv25Ne+Vo8CfJAR3xM7LbZjZlyzh0+2+lm9CfBURrtPbGjhAzPk/7c/oceeBOBZfjJidmDARkDtIT0JcCxhXCnYhLTloT0JsD+h/RRsQtry0J4E2J7Qfgo2IW15aE8ClO9+AhldAGMRpi4Ar+UPZEa/xVIXMcSSIzW2GX6KAmyU7q+KvRV7L3ZWbOwilhzkIie5x+aqEjc1AXgP/0Y6vSl2QKzUIhc5yQ1HqbzZeaYiAO9a+CqBT7F7srsaTkBuOOCCcxjZyNNQgMGOeEbyzGz5ZRpccMI9WFgLh7UADIBn5K4Wza7ggBNualjhaverpQA0zgDadTufiRqoZb638q6VADRM4ynt/RTwXbFLYkfF9optmBnX7OEDA1Zc0YtaqCk6oBTQQoCDUjwNy4+o9UpQvJ1k2Bfl+o7Yc7FPYt9nxjV7+MCAJYZYgUQtaqK2KHApkIUA1xKKvy7Yw2IPxX6JxS6wxBBLjti4lNpicwZxrQW4INXwUiE/1HVOEDfEchc5yBWTh9qoMQZbBNNSgG1ScewzjHco9wVfapGLnDH5qJFaY7DZmJYC0NjOiIo3C4b/bJcfRRc5ya0lpUZq1XBF/K0E2CTVnhHT1iEBfBOrtcgNh5afWqlZw2X7WwlwQipdLxZal8X5Wqz2ggOuEA+1UnMIE+XTQK0EOK4UwreVtxVMSTdccIZyajWHYqN9LQTgKB9RKnqm+Gu4NU5qpvYa3Ms5WwigfcLkPTsfoJaLanQBJ9whOq32UGyUr4UAu5VKHov/h1jrBSfcIV6t9lBslK+FAFuUSj4q/ppujVurPbu2KQjwNbuL8Qk07oUQYKsyH20ISniWW+PWas8iJ9hPAFMYtoU4AeuG+/vr4SvlvxcGDxq3Vnt2yS1OQHaRi5xgMQXoSDEXwFgsF8AFMJ6AMb2fABfAeALG9H4CXADjCRjT+wlwAYwnYEzvJ2BxBDDupFN6PwHGwrkALoDxBIzp/QS4AMYTMKb3E+ACGE/AmN5PgAtgPAFjej8BmQLkhrsAuRPMjHcBMgeYG+4C5E4wM94FyBxgbngJAbg1WMi0GkOxLXy59WnxQX8JAYIE7gxPwAUIz6e61wWoPuIwgQsQnk91rwtQfcRhgj4FCPfUldcFMJarhABrpIf/2aT98auEAOPZPdL/lqT1c8BPgLECPQiQ+32Q8YjD9D0I8CLcQtCbExtMXMrZgwCfM5rNic2gjQ/tQYCX8e2sQubErkpWY6MHAXgZeTKieWKIHRHaLiRBgHZFzWE6NWdP2xoTo+Us7u9FABrn0/YVLhQDA1aBTcPdkwBM7JY8cIdzbjvJ/T+5ESvGNXv4wAisj9WbAEz1nTxw41XugMutiDGu2cMn7n5WjwL0M92ISl2AiCHVhLgANacbkdsFiBhSTYgLUHO6EbldgIgh1YS4AMp0a7v/AAAA//9aRXhEAAAABklEQVQDALhvssEXv78aAAAAAElFTkSuQmCC",
                  0,
                  widget.chatId));
              _showNotification(item['text']);
            }

            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          });
        });
      });

      final thing = (FirebaseTools.asList(await FirebaseChatTools.load('/'))
          .elementAt(widget.chatId) as Map);
      final Widget evalTemp = thing['owner'] == widget.myToken
          ? IconButton(
              onPressed: () {
                _analyzeWithAI();
              },
              tooltip: "Evaluate chat",
              icon: const Icon(Icons.psychology))
          : const SizedBox.shrink();

      setState(() {
        _evaluateButton = evalTemp;
      });

      setState(() {
        loading = false;
      });

      setState(() {});
    }();

    setState(() {});
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

    bool hasProf = FirebaseChatTools.filter.hasProfanity(v);

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
            thing - FirebaseChatTools.filter.getAllProfanity(v).length);
      } else if (thing is String) {
        await FirebaseUserTools.set(
            '${FirebaseAuth.instance.currentUser?.uid}/karma',
            int.parse(thing) -
                FirebaseChatTools.filter.getAllProfanity(v).length);
      }
    }
  }

  Future<void> _analyzeWithAI({String type = 'message'}) async {
    try {
      await OpenAIService.analyzeMessage(
        chatId: widget.chatId,
        type: type,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _renameChat(String newName) async {
    if (newName.trim().isEmpty) return;

    Map data = await FirebaseChatTools.load('/');
    String chatKey = data.keys.elementAt(widget.chatId);

    await FirebaseChatTools.set(
        '/$chatKey/title', FirebaseChatTools.filter.censor(newName.trim()));

    setState(() {
      _actualTitle = FirebaseChatTools.filter.censor(newName.trim());
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
      AppBar(
          title: Row(children: <Widget>[
        Center(
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width - 220),
                child: Text(_actualTitle ?? widget.title))),
        const SizedBox(width: 40),
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
            icon: const Icon(Icons.edit)),
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
                      title: const Text("Karma History Chart"),
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
                                    child: Text('No karma history available'));
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
        _evaluateButton
      ])),
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
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 15),
                      child: Center(child: CircularProgressIndicator()))
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
                        // print("Look! It's now ${_aiAnalysisEnabled}");
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

  bool _loading = false;

  void _runOpenChat(String enteredUid) {
    if (!mounted) return;

    setState(() {
      () async {
        String myToken = await FirebaseUserTools.load(
            '${FirebaseAuth.instance.currentUser!.uid}/pairToken');

        List<String> parts = [myToken, enteredUid];
        parts.sort();

        try {
          await FirebaseChatTools.listPush('/', {
            "tokens": parts,
            "title":
                '${await FirebaseUserTools.load('${FirebaseAuth.instance.currentUser!.uid}/displayName')} & ${await FirebaseUserTools.load('${await FirebaseUserTools.getUidFromToken(enteredUid)}/displayName')}',
            "data": [
              {"text": "This chat was created.", "sender": "system"},
            ],
          });

          if (mounted) Navigator.of(context).pop();
          rebuildChats();
        } catch (e) {
          print(e);
          if (mounted) Navigator.of(context).pop();
          rebuildChats();
          return;
        }
      }();

      setState(() {});
    });
  }

  void _addChatTalkPage(
      String myToken, List oTokens, String? title, int cid) async {
    List<Widget> pfps = [];
    for (String token in oTokens) {
      if (await FirebaseUserTools.getUidFromToken(token) == null) {
        return;
      }

      String emailKey = token.replaceAll('.', '_dot_').replaceAll('@', '_at_');
      pfps.add(Image.memory(
          base64.decode((await FirebaseUserTools.load(
                  'profilePictures/$emailKey/profilePicture'))
              .replaceAll(RegExp(r'\s'), '')),
          width: 20,
          height: 20,
          fit: BoxFit.cover));
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
                    maxWidth: MediaQuery.sizeOf(context).width - 260),
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

    setState(() {});
  }

  void rebuildChats() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    _chats.clear();
    _chatPages.clear();

    JSAny chatArray = await FirebaseChatTools.load('/');

    if (!mounted) return;

    String myToken = await FirebaseUserTools.load(
        '${FirebaseAuth.instance.currentUser!.uid}/pairToken');
    List chats = FirebaseTools.asList(chatArray.dartify());
    for (int i = 0; i < chats.length; i++) {
      JSAny? chat = chats[i];
      Map data = chat.dartify() as Map;

      if ((data['tokens'] as Iterable).contains(myToken)) {
        _addChatTalkPage(
            myToken,
            FirebaseTools.asList(data['tokens'])
                .where((token) => token != myToken)
                .toList(),
            data['title'],
            i);
      }
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    rebuildChats();
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
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (BuildContext context2, int index) {
                    return _chats[index];
                  }),
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
