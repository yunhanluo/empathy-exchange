import 'package:flutter/material.dart';

class Message extends StatelessWidget {
  const Message(this.value, this.sender, {super.key});

  final String value;
  final Sender sender;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: (sender == Sender.self ? Alignment.centerRight : Alignment.centerLeft),
      child: Padding(
        padding: (sender == Sender.self ? EdgeInsets.only(right: 5) : EdgeInsets.only(left: 5)),
        child: Container(
          color: (sender == Sender.self ? Colors.green.shade300 : Colors.blue.shade300),
          child: Padding(
            padding: EdgeInsets.all(5),
            child: Text(value, style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}

enum Sender {
  self,
  other
}