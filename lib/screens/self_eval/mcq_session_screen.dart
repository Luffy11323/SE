// lib/screens/self_eval/mcq_session_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:self_evaluator/services/journey_service.dart';
import 'package:self_evaluator/utils/haptic_feedback.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MCQQuestion {
  final String id;
  final String question;
  final List<String> options;
  final String? recordId;

  MCQQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.recordId,
  });

  factory MCQQuestion.fromMap(Map<String, dynamic> map) {
    return MCQQuestion(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      recordId: map['recordId'],
    );
  }
}

class MCQSessionScreen extends StatefulWidget {
  final String category;
  final bool isNewSession;
  final String? sessionId;

  const MCQSessionScreen({
    super.key,
    required this.category,
    this.isNewSession = true,
    this.sessionId,
  });

  @override
  State<MCQSessionScreen> createState() => _MCQSessionScreenState();
}

class _MCQSessionScreenState extends State<MCQSessionScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final _journeyService = JourneyService();
  late final String _userId = supabase.auth.currentUser?.id ?? 'anonymous';

  List<MCQQuestion> _questions = [];
  int _currentIndex = 0;
  final Map<String, String> _answers = {}; // question_id -> selected_answer
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  // Session state
  String? _voiceAnswer;
  String? _cumulativeSummary;
  String? _progressNote;
  int _totalQuestions = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  late RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnim = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    if (widget.isNewSession) {
      _startNewSession();
    } else {
      _loadPendingQuestions();
    }

    _setupRealtime();
  }

  Future<void> _startNewSession() async {
    setState(() => _isLoading = true);

    try {
      // Send initial message to trigger MCQ generation
      await supabase.from('chat_history').insert({
        'user_id': _userId,
        'message_type': 'user',
        'content': 'I want to start a ${widget.category} reflection journey',
        'category_context': widget.category,
      });

      // Wait a bit for backend to process
      await Future.delayed(const Duration(seconds: 2));
      
      // Load generated questions
      await _loadPendingQuestions();
    } catch (e) {
      debugPrint('Error starting session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPendingQuestions() async {
    setState(() => _isLoading = true);

    try {
      final questions = await _journeyService.getPendingQuestions(_userId, widget.category);
      
      if (mounted) {
        setState(() {
          _questions = questions;
          _totalQuestions = questions.length;
          _isLoading = false;
        });

        if (questions.isEmpty) {
          // No pending questions, load summary
          await _loadSummary();
        } else {
          _animController.forward();
        }
      }
    } catch (e) {
      debugPrint('Error loading questions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load questions: $e')),
        );
      }
    }
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _journeyService.getCumulativeSummary(_userId, widget.category);
      
      if (mounted) {
        setState(() {
          _cumulativeSummary = summary['cumulative_summary'];
          _progressNote = summary['progress_note'];
          _voiceAnswer = summary['voice_answer'];
        });
      }
    } catch (e) {
      debugPrint('Error loading summary: $e');
    }
  }

  void _setupRealtime() {
    _channel = supabase.channel('mcq_session_${widget.category}').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_history',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: _userId,
      ),
      callback: (payload) {
        if (!mounted) return;
        
        final newRecord = payload.newRecord;
        if (newRecord['category_context'] == widget.category &&
            newRecord['message_type'] == 'bot') {
          
          // Update summary data
          setState(() {
            _cumulativeSummary = newRecord['cumulative_summary'] as String?;
            _progressNote = newRecord['progress_note'] as String?;
            _voiceAnswer = newRecord['voice_answer'] as String?;
          });

          // Check for new MCQ
          if (newRecord['mcq_question'] != null) {
            _loadPendingQuestions();
          }
        }
      },
    ).subscribe();
  }

  Future<void> _submitAnswer(String answer) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    Haptic.selection();

    try {
      final currentQuestion = _questions[_currentIndex];
      
      // Save answer
      _answers[currentQuestion.id] = answer;

      // Submit to backend via chat_history
      await supabase.from('chat_history').insert({
        'user_id': _userId,
        'message_type': 'user',
        'content': answer,
        'category_context': widget.category,
      });

      // Save partial progress
      await _journeyService.savePartialAnswers(
        _userId,
        widget.category,
        _answers,
        _currentIndex,
      );

      // Wait for backend response
      await Future.delayed(const Duration(milliseconds: 800));

      // Move to next question or finish
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _isSubmitting = false;
        });
        _animController.reset();
        _animController.forward();
      } else {
        // All questions answered
        setState(() => _isSubmitting = false);
        await _loadSummary();
        _showCompletionDialog();
      }
    } catch (e) {
      debugPrint('Error submitting answer: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit answer: $e')),
        );
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Row(
          children: [
            Icon(Icons.celebration, color: AppColors.accentGreen),
            SizedBox(width: 12),
            Text(
              'Journey Complete!',
              style: TextStyle(color: AppColors.textLight),
            ),
          ],
        ),
        content: Text(
          'You\'ve completed all questions for ${widget.category}. Your insights are being generated.',
          style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to dashboard
            },
            child: Text('View Summary', style: TextStyle(color: AppColors.accentGreen)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Reset Journey?', style: TextStyle(color: AppColors.textLight)),
        content: Text(
          'This will clear all progress and start fresh.',
          style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _journeyService.resetJourney(_userId, widget.category);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reset: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _channel.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category,
              style: TextStyle(color: AppColors.textLight, fontSize: 18),
            ),
            if (_totalQuestions > 0)
              Text(
                'Question ${_currentIndex + 1} of $_totalQuestions',
                style: TextStyle(
                  color: AppColors.textLight.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.textLight),
            onSelected: (value) {
              if (value == 'reset') {
                _resetSession();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Reset Journey'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _questions.isEmpty
              ? _buildSummaryView()
              : _buildQuestionView(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accentGreen),
          SizedBox(height: 24),
          Text(
            widget.isNewSession
                ? 'Generating your personalized questions...'
                : 'Loading your journey...',
            style: TextStyle(color: AppColors.textLight, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionView() {
    final question = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _totalQuestions;

    return SafeArea(
      child: Column(
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.cardBackground,
                color: AppColors.accentGreen,
                minHeight: 8,
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: AnimatedBuilder(
                  animation: _slideAnim,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnim.value),
                      child: child,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Question
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accentGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          question.question,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 20,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Options
                      if (_isSubmitting)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: CircularProgressIndicator(color: AppColors.accentGreen),
                          ),
                        )
                      else
                        ...question.options.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildOptionButton(option, index),
                          );
                        }),

                      const SizedBox(height: 24),

                      // Progress indicator
                      if (_voiceAnswer != null || _progressNote != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              if (_progressNote != null) ...[
                                Row(
                                  children: [
                                    Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _progressNote!,
                                        style: TextStyle(
                                          color: AppColors.textLight.withValues(alpha: 0.8),
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String option, int index) {
    final letters = ['A', 'B', 'C', 'D', 'E'];
    final letter = index < letters.length ? letters[index] : '';

    return GestureDetector(
      onTap: () => _submitAnswer(option),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentGreen.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Completion header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentGreen.withValues(alpha: 0.2),
                    AppColors.accentGreen.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(Icons.celebration, color: AppColors.accentGreen, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Journey Summary',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Here\'s what we\'ve learned about your ${widget.category} journey',
                    style: TextStyle(
                      color: AppColors.textLight.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Cumulative Summary
            if (_cumulativeSummary != null)
              _buildSummarySection(
                'Overall Summary',
                _cumulativeSummary!,
                Icons.summarize,
                AppColors.accentGreen,
              ),

            if (_cumulativeSummary != null) const SizedBox(height: 20),

            // Progress Note
            if (_progressNote != null)
              _buildSummarySection(
                'Current Focus',
                _progressNote!,
                Icons.lightbulb_outline,
                Colors.amber,
              ),

            if (_progressNote != null) const SizedBox(height: 20),

            // Voice Answer
            if (_voiceAnswer != null)
              _buildSummarySection(
                'Reflection',
                _voiceAnswer!,
                Icons.chat_bubble_outline,
                Color(0xFF2196F3),
              ),

            const SizedBox(height: 32),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetSession,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textLight,
                      side: BorderSide(color: AppColors.textLight.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Start Over'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: AppColors.textLight.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}