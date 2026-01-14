// lib/screens/self_eval/reflection_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:self_evaluator/constants/color_palette.dart';
import 'package:self_evaluator/constants/app_routes.dart';

class ReflectionSummaryScreen extends StatefulWidget {
  final Map<String, int> answers; // {questionIndex: 1..5}

  const ReflectionSummaryScreen({
    super.key,
    required this.answers,
  });

  @override
  State<ReflectionSummaryScreen> createState() => _ReflectionSummaryScreenState();
}

class _ReflectionSummaryScreenState extends State<ReflectionSummaryScreen>
    with SingleTickerProviderStateMixin {
  bool _isSaving = false;
  List<String> _strengths = [];
  List<String> _growthAreas = [];
  List<String> _nextSteps = [];

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

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

    _generateGentleSummary();
  }

  void _generateGentleSummary() {
    // Simple rule-based summary for MVP (later: real AI prompt)
    int highCount = 0; // 4 or 5
    int mediumCount = 0; // 3
    int lowCount = 0; // 1 or 2

    widget.answers.forEach((_, value) {
      if (value >= 4) highCount++;
      else if (value == 3) mediumCount++;
      else lowCount++;
    });

    final total = widget.answers.length;

    // Strengths: focus on high answers
    _strengths = [
      if (highCount >= total * 0.4)
        "You show consistency and presence in many areas of your life.",
      if (highCount >= total * 0.3)
        "There is a quiet strength in how you approach daily moments.",
      "Your willingness to reflect honestly is itself a beautiful quality.",
    ]..removeWhere((s) => s.isEmpty);

    // Growth areas: gentle, optional phrasing
    _growthAreas = [
      if (lowCount > 0 || mediumCount > total * 0.4)
        "There may be moments where pausing a little longer could feel supportive.",
      if (mediumCount > 0)
        "Small, intentional steps in certain areas might bring even more ease.",
      "Every reflection is already a step toward deeper self-kindness.",
    ]..removeWhere((s) => s.isEmpty);

    // Next steps: always positive, optional
    _nextSteps = [
      "Notice one small moment today where you can pause and breathe.",
      "Offer yourself a gentle word of encouragement when things feel heavy.",
      "Continue showing up — even one question at a time is meaningful.",
    ];

    // Shuffle lightly so it feels fresh each time (optional)
    _nextSteps.shuffle();
  }

  Future<void> _saveAndReturn() async {
    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reflections').add({
        'userId': user.uid,
        'category': 'personal_growth',
        'startedAt': FieldValue.serverTimestamp(), // ideally pass real started time from questions screen
        'completedAt': FieldValue.serverTimestamp(),
        'answers': widget.answers,
        'summary': {
          'strengths': _strengths,
          'growthAreas': _growthAreas,
          'nextSteps': _nextSteps,
        },
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save reflection — please try again.'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          'Your Reflection',
          style: TextStyle(color: AppColors.textLight, fontSize: 20),
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGreen))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

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
                        "Here are some gentle patterns that appeared today.",
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: AppColors.textLight.withValues(alpha: 0.8),
                        ),
                      ),

                      const SizedBox(height: 48),

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

                      const SizedBox(height: 80),

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
                            child: const Text("Back to Questions"),
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
                              "Save & Return Home",
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