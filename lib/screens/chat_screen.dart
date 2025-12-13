import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:http/http.dart' as http;
import 'package:profanity_filter/profanity_filter.dart';
import 'package:empathy_exchange/widgets/material.dart';
import 'package:empathy_exchange/widgets/message.dart';
import 'package:empathy_exchange/lib/firebase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

int _ppage = 0;

final ProfanityFilter filter = ProfanityFilter();

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
      required this.otherToken,
      required this.chatId});

  final String myToken;
  final String otherToken;
  final int chatId;

  @override
  State<_ChatTalkPage> createState() =>
      // ignore: no_logic_in_create_state
      _ChatTalkPageState(chatId: chatId, myToken: myToken);
}

class _ChatTalkPageState extends State<_ChatTalkPage> {
  _ChatTalkPageState({required this.chatId, required this.myToken});

  final _textController = TextEditingController();
  final _textFocus = FocusNode();

  final _scrollController = ScrollController();

  final List<Widget> _messages = <Widget>[];

  final int chatId;
  final String myToken;

  StreamSubscription<DatabaseEvent>? _subscription;
  DatabaseReference? thisRef;

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();

    _scrollController.dispose();

    _subscription?.cancel();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    () async {
      Map data = await FirebaseChatTools.load('/');
      Map chat = data.values.elementAt(chatId) as Map;
      dynamic items = chat['data'];

      final emailKey = ((chat['aToken'] == myToken
              ? chat['bToken']
              : chat['aToken']) as String)
          .replaceAll('.', '_dot_')
          .replaceAll('@', '_at_');
      String pfp = await FirebaseUserTools.load(
          'profilePictures/$emailKey/profilePicture');
      Map uData = await FirebaseUserTools.load('/');
      int karma = 0;
      for (Map user in uData.values) {
        if (user['pairToken'] == emailKey) {
          dynamic karmaToParse = user['karma'];
          if (karmaToParse is int) {
            karma = karmaToParse;
          } else if (karmaToParse is String) {
            karma = int.parse(karmaToParse);
          }

          break;
        }
      }

      if (items is Map) {
        for (JSAny? item in items.values) {
          setState(() {
            Map message = item as Map;
            _messages.add(Message(
                message["text"],
                message["sender"] == myToken ? Sender.self : Sender.other,
                pfp));
          });
        }
      } else if (items is JSArray) {
        for (JSAny? item in items.toDart) {
          setState(() {
            Map message = item as Map;
            _messages.add(Message(
                message["text"],
                message["sender"] == myToken ? Sender.self : Sender.other,
                pfp));
          });
        }
      }

      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

      setState(() {
        thisRef =
            FirebaseChatTools.ref.child('/${data.keys.elementAt(chatId)}/data');
        _subscription = thisRef?.onValue.listen((event) async {
          Map item = event.snapshot.children.last.value as Map;
          String sender = item['sender'];

          String pfp;
          if (sender != myToken && sender != 'system') {
            final emailKey =
                sender.replaceAll('.', '_dot_').replaceAll('@', '_at_');
            pfp = await FirebaseUserTools.load(
                'profilePictures/$emailKey/profilePicture');
          } else {
            pfp = "";
          }

          setState(() {
            if (sender != myToken && sender != 'system') {
              _messages.add(Message(item["text"], Sender.other, pfp));
              _showNotification(item['text']);
            }

            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          });
        });
      });
    }();
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
    bool hasProf = filter.hasProfanity(v);
    String value = filter.censor(v);

    final emailKey = myToken.replaceAll('.', '_dot_').replaceAll('@', '_at_');
    String pfp = await FirebaseUserTools.load(
        'profilePictures/$emailKey/profilePicture');

    setState(() {
      _messages.add(Message(value, Sender.self, pfp));

      _textController.clear();
      _textFocus.requestFocus();
    });

    Map data = await FirebaseChatTools.load('/');
    String name = data.keys.elementAt(chatId);
    await FirebaseChatTools.listPush('$name/data', {
      "sender": myToken,
      "text": value,
    });

    if (hasProf) {
      dynamic thing = await FirebaseUserTools.load(
          '${FirebaseAuth.instance.currentUser?.uid}/karma');
      if (thing is int) {
        await FirebaseUserTools.set(
            '${FirebaseAuth.instance.currentUser?.uid}/karma',
            thing - filter.getAllProfanity(v).length);
      } else if (thing is String) {
        await FirebaseUserTools.set(
            '${FirebaseAuth.instance.currentUser?.uid}/karma',
            int.parse(thing) - filter.getAllProfanity(v).length);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return appInstance(Column(children: [
      AppBar(
        leading: IconButton(
          onPressed: () {
            _ppage = 0;
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black), // Back icon
        ),
        title: const Center(child: Text("Chat")),
      ),
      Column(
        children: <Widget>[
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
                child: Column(
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
                    width: MediaQuery.sizeOf(context).width - 60,
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
                    width: 60, // Increased width from 40 to 60
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
        ],
      )
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
        String path = parts.join(' ');

        try {
          Map chatList = await FirebaseChatTools.load('/');
          for (JSAny? chat in chatList.values) {
            if ((chat.dartify() as Map)["fullToken"] == path) {
              if (mounted) Navigator.of(context).pop();
              return;
            }
          }

          await FirebaseChatTools.listPush('/', {
            "aToken": uidController.text,
            "bToken": myToken,
            "fullToken": path,
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

  void _addChatTalkPage(String euid, String myToken) async {
    final emailKey = myToken.replaceAll('.', '_dot_').replaceAll('@', '_at_');

    String pfp = await FirebaseUserTools.load(
        'profilePictures/$emailKey/profilePicture');

    _chatPages
        .add(_ChatTalkPage(myToken: myToken, otherToken: euid, chatId: _ppage));
    _chats.add(TextButton(
      onPressed: () {
        _ppage = _chats.length;
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
            Image.memory(base64.decode(pfp.replaceAll(RegExp(r'\s'), '')),
                width: 20, height: 20, fit: BoxFit.cover),
            Text(
              "Chat ${_chats.length + 1}",
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.left,
            ),
            const Icon(
              Icons.arrow_forward_ios, // Right arrow icon
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    ));
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

    for (JSAny? chat in (chatArray.dartify() as Map).values) {
      Map data = chat.dartify() as Map;
      String myToken = await FirebaseUserTools.load(
          '${FirebaseAuth.instance.currentUser!.uid}/pairToken');
      if ((data['fullToken'] as String).split(' ').contains(myToken)) {
        if (data['aToken'] == myToken) {
          _addChatTalkPage(myToken, data["bToken"] as String);
        } else if (data['bToken'] == myToken) {
          _addChatTalkPage(myToken, data["aToken"] as String);
        }
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
