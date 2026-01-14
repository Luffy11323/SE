// lib/screens/self_eval/reflection_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:self_evaluator/constants/color_palette.dart';
import 'package:self_evaluator/constants/app_routes.dart';
import 'package:self_evaluator/services/reflection_service.dart';

class ReflectionSummaryScreen extends StatefulWidget {
  final Map<String, int> answers;
  final DateTime? startedAt; // ← received from questions screen

  const ReflectionSummaryScreen({
    super.key,
    required this.answers,
    this.startedAt,
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

  final ReflectionService _service = ReflectionService();

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
    int high = 0, medium = 0, low = 0;

    widget.answers.forEach((_, v) {
      if (v >= 4) {
        high++;
      } else if (v == 3) { medium++;}
      else {low++;}
    });

    final total = widget.answers.length;

    _strengths = [
      if (high >= total * 0.4) "You show consistency and presence in many areas.",
      if (high >= total * 0.3) "There is quiet strength in your daily approach.",
      "Your willingness to reflect honestly is beautiful.",
    ]..removeWhere((s) => s.isEmpty);

    _growthAreas = [
      if (low > 0 || medium > total * 0.4) "Pausing longer in certain moments could feel supportive.",
      if (medium > 0) "Small intentional steps may bring more ease.",
      "Every reflection is already a step toward deeper self-kindness.",
    ]..removeWhere((s) => s.isEmpty);

    _nextSteps = [
      "Notice one moment today to pause and breathe.",
      "Offer yourself a gentle word when things feel heavy.",
      "Continue showing up — one question at a time is meaningful.",
    ]..shuffle();
  }

  Future<void> _saveAndReturn() async {
    setState(() => _isSaving = true);

    final success = await _service.saveReflection(
      category: 'personal_growth',
      startedAt: widget.startedAt ?? DateTime.now(),
      answers: widget.answers,
      summary: {
        'strengths': _strengths,
        'growthAreas': _growthAreas,
        'nextSteps': _nextSteps,
      },
    );

    setState(() => _isSaving = false);

    if (success != null && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save — please try again')),
      );
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