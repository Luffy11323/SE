import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:self_evaluator/models/question_model.dart';
import 'package:self_evaluator/modules/self_eval/results_screen.dart';
import 'package:vibration/vibration.dart';

class SelfEvalScreen extends StatefulWidget {
  final String category;
  const SelfEvalScreen({super.key, required this.category});

  @override
  State<SelfEvalScreen> createState() => _SelfEvalScreenState();
}

class _SelfEvalScreenState extends State<SelfEvalScreen> {
  List<QuestionModel> questions = [];
  int currentIndex = 0;
  List<int?> _selectedScores = [];
  Map<String, int> scoreMap = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    scoreMap = {widget.category: 0};
    _selectedScores = List.filled(20, null); // Adjust if needed
  }

  Future<void> _loadQuestions() async {
    final String jsonString =
        await rootBundle.loadString('assets/data/self_eval_questions.json');
    final List<dynamic> jsonList = json.decode(jsonString);

    setState(() {
      questions = jsonList.map((json) => QuestionModel.fromJson(json)).toList();
    });
  }

  void _submitAnswer() {
    if (_selectedScores[currentIndex] == null) return;

    setState(() {
      scoreMap[widget.category] =
          scoreMap[widget.category]! + _selectedScores[currentIndex]!;

      if (currentIndex < questions.length - 1) {
        currentIndex++;
      } else {
        _saveResults();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ResultsScreen(scores: scoreMap)),
        );
      }
    });
  }

  Future<void> _saveResults() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('selfEvaluations')
        .add({
      'category': widget.category,
      'score': scoreMap[widget.category],
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final question = questions[currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('${widget.category} Evaluation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              question.question,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            const Text("Rate 1-5 (Strongly Disagree to Strongly Agree)"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [1, 2, 3, 4, 5].map((score) {
                return Expanded(
                  child: RadioListTile<int>(
                    value: score,
                    groupValue: _selectedScores[currentIndex],
                    onChanged: (value) async {
                      await Vibration.hasVibrator().then((hasVibrator) {
                        if (hasVibrator) {
                          Vibration.vibrate(duration: 10);
                        }
                      });
                      setState(() => _selectedScores[currentIndex] = value);
                    },
                    title: Text(score.toString()),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitAnswer,
              child: Text(
                currentIndex < questions.length - 1 ? "Next" : "Submit",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
