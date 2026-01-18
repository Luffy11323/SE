// lib/screens/self_eval/reflection_questions_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:self_evaluator/constants/app_routes.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:self_evaluator/utils/haptic_feedback.dart';
import 'package:http/http.dart' as http;

class ReflectionQuestionsScreen extends StatefulWidget {
  final String? category;
  final bool isContinuing;
  final String? sessionId;
  final bool isMCQMode;

  const ReflectionQuestionsScreen({
    super.key,
    this.category,
    this.isContinuing = false,
    this.sessionId,
    this.isMCQMode = false,
  });

  @override
  State<ReflectionQuestionsScreen> createState() => _ReflectionQuestionsScreenState();
}

class _ReflectionQuestionsScreenState extends State<ReflectionQuestionsScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late final String _userId = supabase.auth.currentUser?.id ?? 'anonymous';

  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  final Map<String, dynamic> _answers = {}; // question index → answer
  DateTime? _startedAt;
  bool _isLoading = true;
  bool _isSaving = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();

    if (widget.isMCQMode) {
      _loadPendingQuestions();
    } else {
      _loadQuestions();
    }
  }

  Future<void> _loadPendingQuestions() async {
    setState(() => _isLoading = true);

    try {
      // Fetch pending MCQs from chat_history
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', _userId)
          .eq('category_context', widget.category ?? 'General')
          .eq('message_type', 'bot')
          .not('mcq_question', 'is', null)
          .order('happened_at', ascending: true);

      final mcqs = <Map<String, dynamic>>[];

      for (final record in response) {
        final mcqData = record['mcq_question'];
        if (mcqData != null && mcqData is Map) {
          mcqs.add({
            'question': mcqData['question'] as String? ?? 'Question',
            'options': mcqData['options'] as List? ?? [],
            'recordId': record['id'],
            'category': widget.category,
          });
        }
      }

      if (mcqs.isEmpty) {
        // No pending questions, load regular questions
        await _loadQuestions();
        return;
      }

      setState(() {
        _questions = mcqs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading pending questions: $e');
      await _loadQuestions(); // Fallback to regular questions
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);

    try {
      final String jsonString = await rootBundle.loadString('assets/data/self_eval_full_questions.json');
      final List<dynamic> allQuestions = json.decode(jsonString);

      // Filter by selected category
      final category = widget.category;

      final filtered = allQuestions.where((q) {
        final qCat = q['category'] as String?;
        return category == null || qCat == category;
      }).toList();

      if (filtered.isEmpty) {
        throw Exception('No questions found for category: $category');
      }

      // Shuffle and take 10
      filtered.shuffle();
      final selected = filtered.take(10).toList();

      setState(() {
        _questions = List<Map<String, dynamic>>.from(selected);
        _isLoading = false;
      });

      // Pre-fill neutral (3) for scale questions
      if (!widget.isMCQMode) {
        for (int i = 0; i < _questions.length; i++) {
          _answers[i.toString()] = 3;
        }
      }

      if (kDebugMode) {
        print('Loaded ${selected.length} questions for category: $category');
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAnswer(dynamic answer) async {
    if (widget.isMCQMode) {
      // Submit MCQ answer to backend
      await _submitMCQAnswer(answer);
    } else {
      // Save scale answer locally
      setState(() {
        _answers[_currentIndex.toString()] = answer;
      });
    }
  }

  Future<void> _submitMCQAnswer(String answer) async {
    setState(() => _isSaving = true);

    try {
      final currentQuestion = _questions[_currentIndex];
      
      // Send answer to chat endpoint
      await supabase.from('chat_history').insert({
        'user_id': _userId,
        'message_type': 'user',
        'content': answer,
        'category_context': widget.category ?? 'General',
      });

      // Move to next question or finish
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _isSaving = false;
        });
        _animController.reset();
        _animController.forward();
      } else {
        // All MCQs answered, go to summary
        _navigateToSummary();
      }
    } catch (e) {
      debugPrint('Error submitting MCQ answer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit answer: $e')),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveDraft() async {
    // Save partial answers to backend for resume later
    try {
      await supabase.from('reflection_drafts').upsert({
        'user_id': _userId,
        'category': widget.category,
        'answers': _answers,
        'current_index': _currentIndex,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Progress saved'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
      _animController.reset();
      _animController.forward();
    } else {
      _navigateToSummary();
    }
  }

  void _navigateToSummary() {
    Navigator.pushNamed(
      context,
      AppRoutes.reflectionSummary,
      arguments: {
        'answers': _answers,
        'startedAt': _startedAt,
        'category': widget.category,
        'isMCQMode': widget.isMCQMode,
      },
    );
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _animController.reset();
      _animController.forward();
    }
  }

  void _saveAndExit() async {
    if (!widget.isMCQMode) {
      await _saveDraft();
    }
    if(!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.accentGreen),
              SizedBox(height: 16),
              Text(
                widget.isMCQMode ? 'Loading your questions...' : 'Preparing reflection...',
                style: TextStyle(color: AppColors.textLight),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: AppColors.accentGreen),
              SizedBox(height: 16),
              Text(
                'No pending questions!',
                style: TextStyle(color: AppColors.textLight, fontSize: 20),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: AppColors.primaryDark,
                ),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];
    final isMCQ = widget.isMCQMode || question.containsKey('options');
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
        title: Row(
          children: [
            Text(
              widget.category ?? 'Personal Growth',
              style: TextStyle(color: AppColors.textLight, fontSize: 18),
            ),
            if (widget.isMCQMode) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'MCQ Mode',
                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/${_questions.length}',
                style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.7)),
              ),
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

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _questions.length,
                  backgroundColor: AppColors.cardBackground,
                  color: AppColors.accentGreen,
                  minHeight: 8,
                ),
              ),

              const SizedBox(height: 32),

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

              if (_isSaving)
                Center(child: CircularProgressIndicator(color: AppColors.accentGreen))
              else if (isMCQ)
                _buildMCQOptions(question['options'] as List? ?? [])
              else
                _buildScaleOptions(),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentIndex > 0 && !widget.isMCQMode)
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

                  if (!widget.isMCQMode)
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

  Widget _buildScaleOptions() {
    return Column(
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
    );
  }

  Widget _buildAnswerOption(int value, String label) {
    final isSelected = _answers[_currentIndex.toString()] == value;

    return GestureDetector(
      onTap: () {
        Haptic.selection();
        _submitAnswer(value);
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

  Widget _buildMCQOptions(List options) {
    return Column(
      children: options.map<Widget>((option) {
        final optionText = option.toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              Haptic.selection();
              _submitAnswer(optionText);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accentGreen.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Text(
                optionText,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}