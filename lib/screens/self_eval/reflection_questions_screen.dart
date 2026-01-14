// lib/screens/self_eval/reflection_questions_screen.dart

import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/color_palette.dart';
import 'package:self_evaluator/constants/app_routes.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ReflectionQuestionsScreen extends StatefulWidget {
  const ReflectionQuestionsScreen({super.key});

  @override
  State<ReflectionQuestionsScreen> createState() => _ReflectionQuestionsScreenState();
}

class _ReflectionQuestionsScreenState extends State<ReflectionQuestionsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  Map<String, int> _answers = {}; // question index → 1..5

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _loadQuestions();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();
  }

  Future<void> _loadQuestions() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/self_eval_full_questions.json');
      final List<dynamic> data = json.decode(jsonString);

      // For MVP: filter to ~12 neutral / gentle questions from Personal Growth / Identity categories
      final filtered = data.where((q) {
        final cat = q['category'] as String?;
        return cat == 'Personal Growth' || cat == 'Identity / Core Values';
      }).take(12).toList();

      setState(() {
        _questions = List<Map<String, dynamic>>.from(filtered);
      });

      // Pre-fill answers with 3 (neutral/middle) so user can skip easily
      for (int i = 0; i < _questions.length; i++) {
        _answers[i.toString()] = 3;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load questions: $e')),
        );
      }
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
      _animController.reset();
      _animController.forward();
    } else {
      // Go to summary with answers
      Navigator.pushNamed(
        context,
        AppRoutes.reflectionSummary,
        arguments: _answers,
      );
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _animController.reset();
      _animController.forward();
    }
  }

  void _saveAndExit() {
    // Optional: save draft to local storage or Firestore later
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.accentGreen)),
      );
    }

    final question = _questions[_currentIndex];
    final qText = question['question'] as String? ?? 'Question not loaded';

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
          onPressed: _saveAndExit,
        ),
        title: Text(
          'Personal Growth',
          style: TextStyle(color: AppColors.textLight, fontSize: 18),
        ),
        actions: [
          Text(
            '${_currentIndex + 1}/${_questions.length}',
            style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.7)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_questions.length, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentIndex
                          ? AppColors.accentGreen
                          : AppColors.cardBackground,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 48),

              // Question text
              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  qText,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.4,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(),

              // Descriptive scale (no numbers visible)
              Column(
                children: [
                  _buildAnswerOption(5, "Almost always"),
                  const SizedBox(height: 12),
                  _buildAnswerOption(4, "Often"),
                  const SizedBox(height: 12),
                  _buildAnswerOption(3, "Sometimes"),
                  const SizedBox(height: 12),
                  _buildAnswerOption(2, "Rarely"),
                  const SizedBox(height: 12),
                  _buildAnswerOption(1, "Almost never"),
                ],
              ),

              const Spacer(),

              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentIndex > 0)
                    OutlinedButton(
                      onPressed: _previousQuestion,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textLight,
                        side: BorderSide(color: AppColors.textLight.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text("Back"),
                    )
                  else
                    const SizedBox.shrink(),

                  ElevatedButton(
                    onPressed: _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      _currentIndex < _questions.length - 1 ? "Next" : "See Summary",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerOption(int value, String label) {
    final isSelected = _answers[_currentIndex.toString()] == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _answers[_currentIndex.toString()] = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentGreen.withValues(alpha: 0.25)
              : AppColors.cardBackground.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentGreen : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              color: isSelected ? AppColors.accentGreen : AppColors.textLight.withValues(alpha: 0.9),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}