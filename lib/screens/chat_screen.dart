import 'package:empathy_exchange/screens/chat_screen.dart';
import 'package:empathy_exchange/widgets/message.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  int _page = 0;
  final List<Widget> _chats = <Widget>[];

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
    if (_page == 0) {
      // chat selection page
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
                  _chats.add(TextButton(
                    onPressed: () {
                      setState(() {
                        _page = 1;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero, // Square corners
                      ),
                    ),
                    child: Container(
                      width: double
                          .infinity, // Make the button fill the entire width
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
                });
              },
            ),
          ),
        ],
      );
    } else {
      // chat page
      return Column(children: [
        AppBar(
          leading: IconButton(
            onPressed: () {
              setState(() {
                _page = 0;
              });
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white
                  .withValues(alpha: 0.7), // Translucent white background
              shape: const CircleBorder(), // Circular shape
            ),
            icon:
                const Icon(Icons.arrow_back, color: Colors.black), // Back icon
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
                  66 -
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
                      width: MediaQuery.sizeOf(context).width -
                          60, // Reduced width by 20 (40 + 20)
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
                      padding:
                          const EdgeInsets.only(right: 5, top: 5, bottom: 5),
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
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Colors.black,
                      width: 3,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
                height: 3,
              ),
            ),
          ],
        )
      ]);
    }
  }
}
