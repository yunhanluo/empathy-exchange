import 'dart:js_interop';

import 'package:empathy_exchange/widgets/material.dart';
import 'package:empathy_exchange/widgets/message.dart';
import 'package:empathy_exchange/lib/firebase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

int _ppage = 0;

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatTalkPage extends StatefulWidget {
  const _ChatTalkPage({super.key, required this.otherToken});

  final String otherToken;

  @override
  State<_ChatTalkPage> createState() => _ChatTalkPageState();
}

class _ChatTalkPageState extends State<_ChatTalkPage> {
  final _textController = TextEditingController();
  final _textFocus = FocusNode();

  final List<Widget> _messages = <Widget>[];

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();

    super.dispose();
  }

  void _send(String value) {
    setState(() {
      _messages.add(Message(value, Sender.self));

      _textController.clear();
      _textFocus.requestFocus();
    });
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
                    child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Column(
                children: _messages,
              ),
            ))),
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

  void _runOpenChat(String enteredUid) {
    if (!mounted) return;

    setState(() {
      () async {
        String myToken = await FirebaseTools.load('${FirebaseAuth.instance.currentUser!.uid}/pairToken');

        List<String> parts = [myToken, enteredUid];
        parts.sort();
        String path = parts.join('&');

        try {
          JSArray chatList = await FirebaseTools.load(
              '${FirebaseAuth.instance.currentUser!.uid}/chats');
          for (JSAny? chat in chatList.toDart) {
            if ((chat.dartify() as Map)["withToken"] == enteredUid) {
              print("exists already");
              if (mounted) Navigator.of(context).pop();
              return;
            }
          }
        } catch (e) {
          if (mounted) Navigator.of(context).pop();
          return;
        }

        await FirebaseTools.listPush(
            '${FirebaseAuth.instance.currentUser!.uid}/chats', {
          "withToken": uidController.text,
          "fullToken": path,
          "data": [],
        });

        if (mounted) Navigator.of(context).pop();

        _addChatTalkPage(enteredUid);
      }();

      setState(() {});
    });
  }

  void _addChatTalkPage(String euid) {
    print("new page");
    _chatPages.add(_ChatTalkPage(otherToken: euid));
    _chats.add(TextButton(
      onPressed: () {
        _ppage = _chats.length;
        Navigator.push(context,
            MaterialPageRoute<void>(builder: (context) => _chatPages[_ppage]));
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

  @override
  Widget build(BuildContext context) {
    print("new build");
    setState(() {
      () async {
        // _chatPages.clear();
        // _chats.clear();
        
        JSArray chatArray;
        try {
          chatArray = await FirebaseTools.load(
            '${FirebaseAuth.instance.currentUser!.uid}/chats');
        } catch (e) {
          return;
        }
        for (JSAny? chat in chatArray.toDart) {
          _addChatTalkPage((chat.dartify() as Map)["withToken"] as String);
        }
      }();
    });

    setState(() {});

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
          child: Column(
            children: _chats,
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
                          },
                          child: const Text("Okay"),
                        ),
                      ],
                    );
                  },
                );
              });
              setState(() {});
            },
          ),
        ),
      ],
    );
  }
}
