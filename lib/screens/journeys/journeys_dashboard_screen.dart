// lib/screens/journeys/journeys_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:intl/intl.dart';
import 'package:self_evaluator/screens/self_eval/mcq_session_screen.dart';
import 'package:self_evaluator/services/journey_service.dart';

class CategoryJourney {
  final String category;
  final String status; // 'no_session', 'ongoing', 'completed'
  final int pendingCount;
  final DateTime? lastActive;
  final String? sessionId;
  final String? summary;

  CategoryJourney({
    required this.category,
    required this.status,
    this.pendingCount = 0,
    this.lastActive,
    this.sessionId,
    this.summary,
  });
}

class JourneysDashboardScreen extends StatefulWidget {
  const JourneysDashboardScreen({super.key});

  @override
  State<JourneysDashboardScreen> createState() => _JourneysDashboardScreenState();
}

class _JourneysDashboardScreenState extends State<JourneysDashboardScreen> {
  final supabase = Supabase.instance.client;
  final _journeyService = JourneyService();
  late final String _userId = supabase.auth.currentUser?.id ?? 'anonymous';

  Map<String, CategoryJourney> _journeys = {};
  bool _isLoading = true;
  late RealtimeChannel _channel;

  // Available categories with metadata
  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Professional Life',
      'icon': Icons.work_outline_rounded,
      'color': Color(0xFF2196F3),
      'description': 'Career progress, work performance, and professional goals'
    },
    {
      'name': 'Intelligence (IQ)',
      'icon': Icons.psychology_rounded,
      'color': Color(0xFF673AB7),
      'description': 'Critical thinking, problem solving, and mental sharpness'
    },
    {
      'name': 'Social Life',
      'icon': Icons.group_rounded,
      'color': Color(0xFFE91E63),
      'description': 'Friends, social activities, and community involvement'
    },
    {
      'name': 'Emotional Self',
      'icon': Icons.sentiment_satisfied_rounded,
      'color': Color(0xFFFFC107),
      'description': 'Emotional balance, self-awareness, and mental wellbeing'
    },
    {
      'name': 'Family Role',
      'icon': Icons.family_restroom_rounded,
      'color': Color(0xFF795548),
      'description': 'Family responsibilities, support, and bonding'
    },
    {
      'name': 'Relationships',
      'icon': Icons.favorite_rounded,
      'color': Color(0xFFF44336),
      'description': 'Romantic relationships, intimacy, and partnership'
    },
    {
      'name': 'Religious Self',
      'icon': Icons.mosque_rounded,
      'color': Color(0xFF9C27B0),
      'description': 'Faith, worship, and spiritual connection'
    },
    {
      'name': 'Online Persona',
      'icon': Icons.language_rounded,
      'color': Color(0xFF00BCD4),
      'description': 'Digital presence, social media, and online behavior'
    },
    {
      'name': 'Identity / Core Values',
      'icon': Icons.self_improvement_rounded,
      'color': Color(0xFF3F51B5),
      'description': 'Personal identity, values, and sense of purpose'
    },
    {
      'name': 'Sports / Fitness',
      'icon': Icons.fitness_center_rounded,
      'color': Color(0xFF4CAF50),
      'description': 'Physical fitness, exercise, and body health'
    },
    {
      'name': 'Academic Life',
      'icon': Icons.school_rounded,
      'color': Color(0xFFFF9800),
      'description': 'Education, learning, and academic achievement'
    },
  ];


  @override
  void initState() {
    super.initState();
    _loadJourneys();
    _setupRealtime();
  }

  Future<void> _loadJourneys() async {
    setState(() => _isLoading = true);

    try {
      final journeys = <String, CategoryJourney>{};

      for (final cat in _categories) {
        final categoryName = cat['name'] as String;
        final journey = await _journeyService.getCategoryStatus(_userId, categoryName);
        journeys[categoryName] = journey;
      }

      if (mounted) {
        setState(() {
          _journeys = journeys;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading journeys: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtime() {
    _channel = supabase.channel('journeys_dashboard').onPostgresChanges(
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
        _loadJourneys(); // Reload all journeys on any change
      },
    ).subscribe();
  }

  Future<void> _startOrResumeJourney(String category) async {
    final journey = _journeys[category];
    
    if (journey == null || journey.status == 'no_session') {
      // Start new journey
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MCQSessionScreen(
            category: category,
            isNewSession: true,
          ),
        ),
      );
    } else {
      // Resume existing journey
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MCQSessionScreen(
            category: category,
            isNewSession: false,
            sessionId: journey.sessionId,
          ),
        ),
      );
    }

    // Reload after returning
    _loadJourneys();
  }

  Future<void> _showResetDialog(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Reset $category Journey?',
          style: TextStyle(color: AppColors.textLight),
        ),
        content: Text(
          'This will clear your progress and start fresh. Your previous summary will be archived.',
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
      await _resetJourney(category);
    }
  }

  Future<void> _resetJourney(String category) async {
    try {
      await _journeyService.resetJourney(_userId, category);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$category journey reset successfully'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        _loadJourneys();
      }
    } catch (e) {
      debugPrint('Error resetting journey: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset journey: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _getCategoryConfig(String category) {
    return _categories.firstWhere(
      (c) => c['name'] == category,
      orElse: () => _categories.last,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return DateFormat('MMM d').format(date);
  }

  Widget _buildJourneyCard(String category, CategoryJourney journey) {
    final config = _getCategoryConfig(category);
    final color = config['color'] as Color;
    final icon = config['icon'] as IconData;
    final description = config['description'] as String;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (journey.status) {
      case 'ongoing':
        statusColor = Colors.orange;
        statusText = '${journey.pendingCount} pending';
        statusIcon = Icons.pending_actions;
        break;
      case 'completed':
        statusColor = AppColors.accentGreen;
        statusText = 'Completed';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = AppColors.textLight.withValues(alpha: 0.5);
        statusText = 'Not started';
        statusIcon = Icons.play_circle_outline;
    }

    return GestureDetector(
      onTap: () => _startOrResumeJourney(category),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              AppColors.cardBackground.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          color: AppColors.textLight.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Summary (if exists)
            if (journey.summary != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  journey.summary!,
                  style: TextStyle(
                    color: AppColors.textLight.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // Footer
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (journey.lastActive != null)
                  Text(
                    'Last active: ${_formatDate(journey.lastActive)}',
                    style: TextStyle(
                      color: AppColors.textLight.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                
                if (journey.status != 'no_session')
                  TextButton.icon(
                    onPressed: () => _showResetDialog(category),
                    icon: Icon(Icons.refresh, size: 16, color: AppColors.textLight.withValues(alpha: 0.6)),
                    label: Text(
                      'Reset',
                      style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.6)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: Text(
          'Your Growth Journeys',
          style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.accentGreen),
            onPressed: _loadJourneys,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.accentGreen),
            )
          : RefreshIndicator(
              onRefresh: _loadJourneys,
              color: AppColors.accentGreen,
              backgroundColor: AppColors.cardBackground,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentGreen.withValues(alpha: 0.2),
                          AppColors.accentGreen.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accentGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.insights, color: AppColors.accentGreen, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'Journey Overview',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              'Active',
                              _journeys.values.where((j) => j.status == 'ongoing').length.toString(),
                              Colors.orange,
                            ),
                            _buildStatItem(
                              'Completed',
                              _journeys.values.where((j) => j.status == 'completed').length.toString(),
                              AppColors.accentGreen,
                            ),
                            _buildStatItem(
                              'Pending',
                              _journeys.values.fold<int>(0, (sum, j) => sum + j.pendingCount).toString(),
                              Colors.amber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Active Journeys
                  if (_journeys.values.any((j) => j.status == 'ongoing')) ...[
                    Text(
                      'Continue Your Journey',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._journeys.entries
                        .where((e) => e.value.status == 'ongoing')
                        .map((e) => _buildJourneyCard(e.key, e.value)),
                    const SizedBox(height: 24),
                  ],

                  // Completed Journeys
                  if (_journeys.values.any((j) => j.status == 'completed')) ...[
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._journeys.entries
                        .where((e) => e.value.status == 'completed')
                        .map((e) => _buildJourneyCard(e.key, e.value)),
                    const SizedBox(height: 24),
                  ],

                  // Available Journeys
                  Text(
                    'Start New Journey',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._journeys.entries
                      .where((e) => e.value.status == 'no_session')
                      .map((e) => _buildJourneyCard(e.key, e.value)),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textLight.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}