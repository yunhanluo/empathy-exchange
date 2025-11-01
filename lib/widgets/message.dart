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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // More balanced padding
        child: Container(
          decoration: BoxDecoration( // Use BoxDecoration for more styling options
            color: (sender == Sender.self ? Colors.green.shade300 : Colors.blue.shade300),
            borderRadius: BorderRadius.circular(12), // Rounded corners
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Adjusted padding
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
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