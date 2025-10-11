import 'package:flutter/material.dart';
import 'package:empathy_exchange/widgets/message.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.title});

  final String title;

  @override
  State<ChatPage> createState() => _State();
}

class _State extends State<ChatPage> {
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
    return Stack(
      children: <Widget>[
        AppBar(
          backgroundColor: Colors.black,
          toolbarHeight: 5,
        ),
        Container(
          color: Colors.white,
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80, top: 10),
                child: Column(
                  children: _messages,
                ),
              )
            )
          ),
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
                  width: MediaQuery.sizeOf(context).width - 40,
                  child: TextField(
                    onSubmitted: (String value) { _send(value); },
                    controller: _textController,
                    focusNode: _textFocus,
                    autofocus: false,
                    decoration: const InputDecoration(
                      hintText: "Say something..."
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
                  width: 40,
                  child: FloatingActionButton(
                    onPressed: () { _send(_textController.value.text); },
                    tooltip: "Send",
                    child: const Icon(Icons.send),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}