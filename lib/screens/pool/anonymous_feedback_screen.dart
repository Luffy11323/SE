import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:self_evaluator/models/feedback_question_model.dart';
import 'package:vibration/vibration.dart';

class AnonymousFeedbackScreen extends StatefulWidget {
  final String poolId;
  final String shareToken;

  const AnonymousFeedbackScreen({
    super.key,
    required this.poolId,
    required this.shareToken,
  });

  @override
  State<AnonymousFeedbackScreen> createState() =>
      _AnonymousFeedbackScreenState();
}

class _AnonymousFeedbackScreenState extends State<AnonymousFeedbackScreen> {
  List<FeedbackQuestion> questions = [];
  Map<String, int?> _answers = {};
  String? _textFeedback;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final poolDoc = await FirebaseFirestore.instance
        .collection('feedbackPools')
        .doc(widget.poolId)
        .get();

    final List<String> questionIds =
        List.from(poolDoc.data()?['questionIds'] ?? []);

    final String jsonString =
        await rootBundle.loadString('assets/data/feedback_questions.json');
    final List<dynamic> jsonList = json.decode(jsonString);

    setState(() {
      questions = jsonList
          .map((json) => FeedbackQuestion.fromJson(json))
          .where((q) => questionIds.contains(q.id))
          .toList();
      _answers = {for (var q in questions) q.id: null};
    });
  }

  Future<void> _submitFeedback() async {
    if (_answers.values.any((score) => score == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please answer all questions")),
      );
      return;
    }

    await Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator) Vibration.vibrate(duration: 50);
    });

    try {
      showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          title: Text("Submitting..."),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Please wait"),
            ],
          ),
        ),
      );

      await FirebaseFirestore.instance
          .collection('feedbackPools')
          .doc(widget.poolId)
          .collection('submissions')
          .add({
        'answers': _answers,
        'textFeedback': _textFeedback,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // close loading
        await Vibration.hasVibrator().then((v) {
          if (v) Vibration.vibrate(pattern: [0, 100, 50, 100]);
        });
        if (mounted) _showThankYouScreen(context);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      await Vibration.hasVibrator().then((v) {
        if (v) Vibration.vibrate(duration: 500);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Submission failed"),
            action: SnackBarAction(
              label: "Retry",
              onPressed: _submitFeedback,
            ),
          ),
        );
      }
    }
  }

  void _showThankYouScreen(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Thank You!"),
        content: const Text("Your feedback has been submitted anonymously."),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _confirmExit(BuildContext context) {
    if (_answers.values.any((v) => v != null)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Discard Feedback?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text("Discard"),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: questions.isEmpty
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : Scaffold(
              key: const ValueKey('feedback-form'),
              appBar: AppBar(
                title: const Text("Feedback Form"),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _confirmExit(context),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        key: const ValueKey('questions-column'),
                        children: [
                          ...questions.map((question) => AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Card(
                                  key: ValueKey(question.id),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(question.question),
                                        const SizedBox(height: 8),
                                        const Text(
                                            "1 = Strongly Disagree, 5 = Strongly Agree"),
                                        Row(
                                          children:
                                              [1, 2, 3, 4, 5].map((score) {
                                            return Expanded(
                                              child: RadioListTile<int>(
                                                value: score,
                                                groupValue:
                                                    _answers[question.id],
                                                onChanged: (value) => setState(
                                                    () =>
                                                        _answers[question.id] =
                                                            value),
                                                title: Text(score.toString()),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: "Additional feedback (optional)",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _textFeedback = value,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitFeedback,
                      child: const Text("Submit Feedback"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
