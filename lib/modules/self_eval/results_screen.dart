import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
  final Map<String, int> scores;

  const ResultsScreen({super.key, required this.scores});

  String getFeedback(String category, int score) {
    if (score >= 28) {
      return "$category: High – This is one of your strong points.";
    }
    if (score >= 18) return "$category: Medium – You show a healthy balance.";
    return "$category: Low – There's room to grow in this area.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Self Evaluation")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: scores.entries.map((e) {
          return Card(
            child: ListTile(
              title: Text(getFeedback(e.key, e.value)),
              trailing: Text('${e.value} pts'),
            ),
          );
        }).toList(),
      ),
    );
  }
}
