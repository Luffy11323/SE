import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:self_evaluator/constants/color_palette.dart';
import 'package:self_evaluator/models/feedback_question_model.dart';
import 'dart:math';

class CreatePoolScreen extends StatefulWidget {
  const CreatePoolScreen({super.key});

  @override
  State<CreatePoolScreen> createState() => _CreatePoolScreenState();
}

class _CreatePoolScreenState extends State<CreatePoolScreen> {
  String? _selectedCategory;
  List<String> availableCategories = [
    "Personal Relationships",
    "Workplace/Professional",
    "Community/Groups",
    "Customer/Client",
    "Educational/Academic",
    "Social Media/Online",
    "Health & Wellness",
    "Service Feedback",
    "Event Feedback",
    "Self-Improvement"
  ];

  List<FeedbackQuestion> _availableQuestions = [];
  bool _isLoadingQuestions = true;
  bool _isCreatingPool = false;

  @override
  void initState() {
    super.initState();
    _loadFeedbackQuestions();
  }

  Future<void> _loadFeedbackQuestions() async {
    try {
      setState(() => _isLoadingQuestions = true);
      final String jsonString =
          await rootBundle.loadString('assets/data/feedback_questions.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      setState(() {
        _availableQuestions =
            jsonList.map((json) => FeedbackQuestion.fromJson(json)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Failed to load questions."),
            action: SnackBarAction(
              label: "Retry",
              onPressed: _loadFeedbackQuestions,
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoadingQuestions = false);
    }
  }

  String _generateSecureRandomToken(int length) {
    final secureRandom = Random.secure();
    final randomBytes =
        List<int>.generate(length, (_) => secureRandom.nextInt(256));
    return base64Url.encode(randomBytes).substring(0, length);
  }

  Future<void> _createFeedbackPool() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a category.")),
      );
      return;
    }

    if (_availableQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("No questions available for this category.")),
      );
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("You must be logged in to create a pool.")),
      );
      return;
    }

    try {
      setState(() => _isCreatingPool = true);

      final selectedQuestionIds = _availableQuestions
          .where((q) => q.category == _selectedCategory)
          .map((q) => q.id)
          .toList();

      if (selectedQuestionIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No questions for this category.")),
        );
        return;
      }

      final shareToken = _generateSecureRandomToken(10);

      await FirebaseFirestore.instance.collection('feedbackPools').add({
        'ownerUserId': currentUser.uid,
        'category': _selectedCategory,
        'creationTimestamp': FieldValue.serverTimestamp(),
        'shareLinkToken': shareToken,
        'selectedQuestionIds': selectedQuestionIds,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Feedback pool created!\nShare: https://yourapp.com/feedback/$shareToken",
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating pool: $e")),
        );
      }
    } finally {
      setState(() => _isCreatingPool = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create New Feedback Pool")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Select a category for feedback:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: "Feedback Category",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
              ),
              items: availableCategories.map((String category) {
                return DropdownMenuItem<String>(
                    value: category, child: Text(category));
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
            ),
            const SizedBox(height: 40),
            _isLoadingQuestions
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _isCreatingPool ? null : _createFeedbackPool,
                    child: _isCreatingPool
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Text("Generate Shareable Link"),
                  ),
          ],
        ),
      ),
    );
  }
}
