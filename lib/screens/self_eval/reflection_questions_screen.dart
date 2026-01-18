// lib/screens/self_eval/reflection_questions_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:self_evaluator/constants/app_routes.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:self_evaluator/utils/haptic_feedback.dart';

class ReflectionQuestionsScreen extends StatefulWidget {
  const ReflectionQuestionsScreen({super.key});

  @override
  State<ReflectionQuestionsScreen> createState() => _ReflectionQuestionsScreenState();
}

class _ReflectionQuestionsScreenState extends State<ReflectionQuestionsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  final Map<String, int> _answers = {}; // question index → 1..5
  DateTime? _startedAt; // ← added to track start time

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now(); // record when reflection began
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
      final List<dynamic> allQuestions = json.decode(jsonString);

      // Define safe categories and exclude judgmental tones/levels
      const safeCategories = [
        'Personal Growth',
        'Identity / Core Values',
        'Emotional Self',
        'Social Life',           // only if gentle
        'Religious Self',        // only if non-judgmental
      ];

      const unsafeKeywords = [
        'performance', 'deadline', 'criticism', 'leadership', 'intelligence', 'IQ', 'skills', 'productivity',
        'consistently meet', 'handle criticism', 'take initiative', 'adapt your skills', 'proactively seek',
        'manage my time', 'stay motivated', 'challenge myself', 'support others in growth' // some feel too evaluative
      ];

      // Filter to safe questions only
      final safeQuestions = allQuestions.where((q) {
        final category = q['category'] as String? ?? '';
        final questionText = (q['question'] as String? ?? '').toLowerCase();

        // Must be in safe category
        if (!safeCategories.contains(category)) return false;

        // Exclude if contains unsafe keyword
        for (final keyword in unsafeKeywords) {
          if (questionText.contains(keyword.toLowerCase())) return false;
        }

        // Keep if tone is reflective/neutral/empathetic/warm
        final tone = q['tone'] as String? ?? '';
        if (['reflective', 'neutral', 'empathetic', 'warm'].contains(tone.toLowerCase())) return true;

        return false;
      }).toList();

      if (safeQuestions.isEmpty) {
        throw Exception('No safe questions found');
      }

      // Shuffle the safe list → true randomness across thousands
      safeQuestions.shuffle();

      // Take 12 random safe questions (change to 10 or 15 if you prefer)
      final selected = safeQuestions.take(12).toList();

      setState(() {
        _questions = List<Map<String, dynamic>>.from(selected);
      });

      // Pre-fill neutral answer (3 = "Sometimes")
      for (int i = 0; i < _questions.length; i++) {
        _answers[i.toString()] = 3;
      }

      if (kDebugMode) {
        print('Loaded ${selected.length} random safe questions');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading questions: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load questions. Please try again.'),
            backgroundColor: AppColors.errorColor,
          ),
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
      // Go to summary, pass answers + start time
      Navigator.pushNamed(
        context,
        AppRoutes.reflectionSummary,
        arguments: {
          'answers': _answers,
          'startedAt': _startedAt,
        },
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
    // Optional: save draft later via service
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.primaryDark,
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '${_currentIndex + 1}/${_questions.length}',
              style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.7)),
            ),
          ),
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

              // Descriptive scale (no numbers)
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
        Haptic.selection();
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