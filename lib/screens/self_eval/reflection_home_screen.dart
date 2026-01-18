// lib/screens/self_eval/reflection_home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:self_evaluator/constants/strings.dart';
import 'package:self_evaluator/constants/app_routes.dart';

class CategorySession {
  final String category;
  final int pendingCount;
  final DateTime? lastActive;
  final String? sessionId;
  final bool isCompleted;

  CategorySession({
    required this.category,
    this.pendingCount = 0,
    this.lastActive,
    this.sessionId,
    this.isCompleted = false,
  });
}

class ReflectionHomeScreen extends StatefulWidget {
  const ReflectionHomeScreen({super.key});

  @override
  State<ReflectionHomeScreen> createState() => _ReflectionHomeScreenState();
}

class _ReflectionHomeScreenState extends State<ReflectionHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  final user = FirebaseAuth.instance.currentUser;
  final supabase = Supabase.instance.client;
  late final String _userId = supabase.auth.currentUser?.id ?? user?.uid ?? 'anonymous';

  // Categories aligned with your backend
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Professional Life', 'icon': Icons.work_outline_rounded},
    {'name': 'Intelligence (IQ)', 'icon': Icons.psychology_rounded},
    {'name': 'Social Life', 'icon': Icons.group_rounded},
    {'name': 'Emotional Self', 'icon': Icons.sentiment_satisfied_rounded},
    {'name': 'Family Role', 'icon': Icons.family_restroom_rounded},
    {'name': 'Relationships', 'icon': Icons.favorite_rounded},
    {'name': 'Religious Self', 'icon': Icons.mosque_rounded},
    {'name': 'Online Persona', 'icon': Icons.language_rounded},
    {'name': 'Identity / Core Values', 'icon': Icons.self_improvement_rounded},
    {'name': 'Sports / Fitness', 'icon': Icons.fitness_center_rounded},
    {'name': 'Academic Life', 'icon': Icons.school_rounded},
  ];

  Map<String, CategorySession> _sessionStatus = {};
  bool _isLoading = true;
  late RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();

    _loadCategoryStatuses();
    _setupRealtime();
  }

  Future<void> _loadCategoryStatuses() async {
    setState(() => _isLoading = true);

    try {
      final sessions = <String, CategorySession>{};

      // Query chat_history for each category
      for (final cat in _categories) {
        final categoryName = cat['name'] as String;

        final response = await supabase
            .from('chat_history')
            .select()
            .eq('user_id', _userId)
            .eq('category_context', categoryName)
            .order('happened_at', ascending: false)
            .limit(1);

        if (response.isNotEmpty) {
          final latest = response.first;
          sessions[categoryName] = CategorySession(
            category: categoryName,
            pendingCount: latest['pending_count'] as int? ?? 0,
            lastActive: DateTime.parse(latest['happened_at']),
            sessionId: latest['id'] as String?,
            isCompleted: (latest['pending_count'] as int? ?? 0) == 0,
          );
        } else {
          // Also check Firestore for legacy reflections
          final firestoreQuery = await FirebaseFirestore.instance
              .collection('reflections')
              .where('userId', isEqualTo: user?.uid)
              .where('category', isEqualTo: categoryName)
              .orderBy('completedAt', descending: true)
              .limit(1)
              .get();

          if (firestoreQuery.docs.isNotEmpty) {
            final doc = firestoreQuery.docs.first;
            final data = doc.data();
            final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

            sessions[categoryName] = CategorySession(
              category: categoryName,
              pendingCount: 0,
              lastActive: completedAt,
              isCompleted: true,
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _sessionStatus = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading category statuses: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtime() {
    _channel = supabase.channel('reflection_updates').onPostgresChanges(
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
        _loadCategoryStatuses();
      },
    ).subscribe();
  }

  void _startReflection(String category, {bool isContinuing = false}) {
    final session = _sessionStatus[category];

    Navigator.pushNamed(
      context,
      AppRoutes.reflectionQuestions,
      arguments: {
        'category': category,
        'isContinuing': isContinuing,
        'sessionId': session?.sessionId,
        'isMCQMode': session?.pendingCount ?? 0 > 0,
      },
    );
  }

  String _getStatusText(String category) {
    final session = _sessionStatus[category];
    if (session == null) return "Start journey";

    if (session.pendingCount > 0) {
      return "${session.pendingCount} question${session.pendingCount > 1 ? 's' : ''} pending";
    }

    if (session.isCompleted && session.lastActive != null) {
      final diff = DateTime.now().difference(session.lastActive!);
      if (diff.inDays == 0) return "Completed today";
      if (diff.inDays == 1) return "Completed yesterday";
      return "Last: ${DateFormat('MMM d').format(session.lastActive!)}";
    }

    return "Continue journey";
  }

  Color _getStatusColor(String category) {
    final session = _sessionStatus[category];
    if (session == null) return AppColors.textLight.withValues(alpha: 0.5);
    if (session.pendingCount > 0) return Colors.orange;
    if (session.isCompleted) return AppColors.accentGreen;
    return AppColors.textLight.withValues(alpha: 0.7);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Back button
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.textLight),
                onPressed: () => Navigator.pop(context),
              ),

              const SizedBox(height: 24),

              // Header
              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  "Choose Your Reflection Path",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                    height: 1.15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  "Each journey is independent. Continue where you left off or start fresh.",
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: AppColors.textLight.withValues(alpha: 0.82),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Category cards
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentGreen,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCategoryStatuses,
                        color: AppColors.accentGreen,
                        backgroundColor: AppColors.cardBackground,
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final categoryName = cat['name'] as String;
                            final statusText = _getStatusText(categoryName);
                            final statusColor = _getStatusColor(categoryName);
                            final session = _sessionStatus[categoryName];
                            final hasPending = (session?.pendingCount ?? 0) > 0;

                            return FadeTransition(
                              opacity: _fadeAnim,
                              child: ScaleTransition(
                                scale: _scaleAnim,
                                child: GestureDetector(
                                  onTap: () => _startReflection(
                                    categoryName,
                                    isContinuing: session != null,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          (cat['color'] as Color).withValues(alpha: 0.15),
                                          AppColors.cardBackground.withValues(alpha: 0.8),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: (cat['color'] as Color).withValues(alpha: 0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (cat['color'] as Color).withValues(alpha: 0.15),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Icon(
                                              cat['icon'] as IconData,
                                              size: 40,
                                              color: cat['color'] as Color,
                                            ),
                                            if (hasPending)
                                              Positioned(
                                                right: -6,
                                                top: -6,
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: AppColors.primaryDark,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  constraints: const BoxConstraints(
                                                    minWidth: 20,
                                                    minHeight: 20,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '${session?.pendingCount}',
                                                      style: TextStyle(
                                                        color: AppColors.primaryDark,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          categoryName,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textLight,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: statusColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}