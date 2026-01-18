// lib/screens/chatbot/chatbot_screen.dart
import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/strings.dart';
import 'package:self_evaluator/constants/colors.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  void _handleSendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': _messageController.text.trim()});
      _messageController.clear();
      _simulateBotResponse();
    });
  }

  void _simulateBotResponse() {
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        final userMessage = _messages.last['text']!.toLowerCase();
        String botResponse;

        if (userMessage.contains('stressed') || userMessage.contains('tired')) {
          botResponse =
              "Your ruh seems tired. Want to reflect on Ayah X from the Qur'an? Or perhaps a moment of dhikr?";
        } else if (userMessage.contains('emotional')) {
          botResponse =
              "You've taken emotional tests, but today — let's just breathe. Remember, Allah is with the patient.";
        } else if (userMessage.contains('hello') ||
            userMessage.contains('salam')) {
          botResponse = AppStrings.chatbotWelcome;
        } else {
          botResponse =
              "That's an interesting thought. How does that connect with your inner peace?";
        }
        _messages.add({'sender': 'bot', 'text': botResponse});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.aiBotChatModule)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['sender'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.accentGreen.withValues(alpha: 0.8)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: Radius.circular(isUser ? 15 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 15),
                      ),
                    ),
                    child: Text(
                      message['text']!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? AppColors.buttonText
                            : AppColors.textLight,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: AppStrings.typeMessageHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _handleSendMessage,
                  backgroundColor: AppColors.accentGreen,
                  mini: true,
                  child: const Icon(Icons.send, color: AppColors.buttonText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
