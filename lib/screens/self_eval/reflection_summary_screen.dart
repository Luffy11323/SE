// lib/screens/self_eval/reflection_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:self_evaluator/constants/app_routes.dart';
import 'package:self_evaluator/services/reflection_service.dart';
import 'package:self_evaluator/utils/haptic_feedback.dart';

class ReflectionSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> answers;
  final DateTime? startedAt;
  final String? category;
  final bool isMCQMode;

  const ReflectionSummaryScreen({
    super.key,
    required this.answers,
    this.startedAt,
    this.category,
    this.isMCQMode = false,
  });

  @override
  State<ReflectionSummaryScreen> createState() => _ReflectionSummaryScreenState();
}

class _ReflectionSummaryScreenState extends State<ReflectionSummaryScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late final String _userId = supabase.auth.currentUser?.id ?? 
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  bool _isSaving = false;
  bool _isLoading = false;
  
  // AI-generated summary from backend
  String? _cumulativeSummary;
  String? _progressNote;
  String? _voiceAnswer;
  
  // Local summary (for non-MCQ mode)
  List<String> _strengths = [];
  List<String> _growthAreas = [];
  List<String> _nextSteps = [];

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final ReflectionService _service = ReflectionService();
  late RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();

    if (widget.isMCQMode) {
      _loadAISummary();
      _setupRealtime();
    } else {
      _generateLocalSummary();
    }
  }

  Future<void> _loadAISummary() async {
    setState(() => _isLoading = true);

    try {
      // Get latest summary from chat_history
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', _userId)
          .eq('category_context', widget.category ?? 'General')
          .eq('message_type', 'bot')
          .order('happened_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final latest = response.first;
        setState(() {
          _cumulativeSummary = latest['cumulative_summary'] as String?;
          _progressNote = latest['progress_note'] as String?;
          _voiceAnswer = latest['voice_answer'] as String?;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading AI summary: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setupRealtime() {
    _channel = supabase.channel('summary_updates').onPostgresChanges(
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
          setState(() {
            _cumulativeSummary = newRecord['cumulative_summary'] as String?;
            _progressNote = newRecord['progress_note'] as String?;
            _voiceAnswer = newRecord['voice_answer'] as String?;
          });
        }
      },
    ).subscribe();
  }

  void _generateLocalSummary() {
    int high = 0, medium = 0, low = 0;
    
    widget.answers.forEach((_, v) {
      if (v is int) {
        if (v >= 4) {
          high++;
        } else if (v == 3) {
          medium++;
        } else {
          low++;
        }
      }
    });

    final total = widget.answers.length;

    _strengths = [
      if (high > total * 0.5) "You naturally lean toward presence and consistency in many moments.",
      if (high > total * 0.35) "Quiet strengths show up in how you hold space for yourself.",
      "The act of reflecting is already a deep kindness to yourself.",
    ];

    _growthAreas = [
      if (low + medium > total * 0.5) "There may be gentle invitations to pause more deeply in certain situations.",
      if (medium > total * 0.4) "Small shifts in awareness could open even more ease.",
      "Growth is never a race — it's just the next honest step.",
    ];

    _nextSteps = [
      "Try one intentional breath when emotions rise today.",
      "Notice a moment where you can speak gently to yourself.",
      "Carry forward one small act of self-kindness this week.",
    ]..shuffle();
  }

  Future<void> _saveAndReturn() async {
    setState(() => _isSaving = true);

    try {
      if (widget.isMCQMode) {
        // MCQ mode - summary already saved by backend
        // Just mark as completed in Firestore if needed
        await FirebaseFirestore.instance.collection('reflections').add({
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'category': widget.category,
          'completedAt': Timestamp.now(),
          'type': 'mcq_journey',
          'summary': _cumulativeSummary,
        });
      } else {
        // Regular reflection mode
        final success = await _service.saveReflection(
          category: widget.category ?? 'Personal Growth',
          startedAt: widget.startedAt ?? DateTime.now(),
          answers: widget.answers.map((k, v) => MapEntry(k, v as int)),
          summary: {
            'strengths': _strengths,
            'growthAreas': _growthAreas,
            'nextSteps': _nextSteps,
          },
        );

        if (success == null) {
          throw Exception('Failed to save reflection');
        }
      }

      setState(() => _isSaving = false);

      if (mounted) {
        Haptic.success();
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.dashboard,
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error saving reflection: $e');
      setState(() => _isSaving = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save — please try again'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    if (widget.isMCQMode) {
      _channel.unsubscribe();
    }
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
          icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category ?? 'Your Reflection',
          style: TextStyle(color: AppColors.textLight, fontSize: 20),
        ),
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.accentGreen),
                  SizedBox(height: 16),
                  Text(
                    'Saving your journey...',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // Header
                      if (widget.isMCQMode)
                        _buildMCQHeader()
                      else
                        _buildLocalHeader(),

                      const SizedBox(height: 48),

                      // Content based on mode
                      if (widget.isMCQMode)
                        _buildMCQContent()
                      else
                        _buildLocalContent(),

                      const SizedBox(height: 80),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textLight,
                              side: BorderSide(color: AppColors.textLight.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: const Text("Back"),
                          ),
                          ElevatedButton(
                            onPressed: _saveAndReturn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGreen,
                              foregroundColor: AppColors.primaryDark,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              elevation: 6,
                              shadowColor: AppColors.accentGreen.withValues(alpha: 0.4),
                            ),
                            child: const Text(
                              "Complete Journey",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMCQHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.accentGreen, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Your Journey Progress",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Here's what we've learned together about your ${widget.category} journey.",
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textLight.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Thank you for showing up for yourself.",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.textLight,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Here are some gentle patterns from your ${widget.category ?? 'reflection'}.",
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textLight.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMCQContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.accentGreen),
            SizedBox(height: 16),
            Text(
              'Generating your summary...',
              style: TextStyle(color: AppColors.textLight),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cumulative Summary
        if (_cumulativeSummary != null)
          _buildAISection(
            title: "Journey Summary",
            content: _cumulativeSummary!,
            icon: Icons.summarize,
            color: AppColors.accentGreen,
          ),

        if (_cumulativeSummary != null && _progressNote != null)
          const SizedBox(height: 32),

        // Progress Note
        if (_progressNote != null)
          _buildAISection(
            title: "Current Focus",
            content: _progressNote!,
            icon: Icons.lightbulb_outline,
            color: Colors.amber,
          ),

        if (_voiceAnswer != null) ...[
          const SizedBox(height: 32),
          _buildAISection(
            title: "Reflection",
            content: _voiceAnswer!,
            icon: Icons.chat_bubble_outline,
            color: Color(0xFF2196F3),
          ),
        ],

        // Fallback if no AI summary yet
        if (_cumulativeSummary == null && _progressNote == null && _voiceAnswer == null)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Icon(Icons.pending, color: AppColors.accentGreen, size: 48),
                SizedBox(height: 16),
                Text(
                  'Your summary is being generated...',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'This usually takes a few moments.',
                  style: TextStyle(
                    color: AppColors.textLight.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLocalContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: "Strengths worth preserving",
          items: _strengths,
          icon: Icons.favorite_border_rounded,
        ),
        const SizedBox(height: 48),
        _buildSection(
          title: "Areas that might deserve gentle reflection",
          items: _growthAreas,
          icon: Icons.lightbulb_outline_rounded,
        ),
        const SizedBox(height: 48),
        _buildSection(
          title: "Possible small next steps (optional)",
          items: _nextSteps,
          icon: Icons.directions_walk_rounded,
        ),
      ],
    );
  }

  Widget _buildAISection({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textLight.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> items,
    required IconData icon,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.accentGreen.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accentGreen.withValues(alpha: 0.8), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((text) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "• $text",
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: AppColors.textLight.withValues(alpha: 0.9),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}