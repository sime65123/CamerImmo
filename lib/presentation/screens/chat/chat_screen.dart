import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Chat — TODO')),
    );
  }
} 
