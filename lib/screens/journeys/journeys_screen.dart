// lib/screens/journeys/journeys_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:intl/intl.dart';
import 'package:self_evaluator/screens/chatbot/chatbot_screen.dart';

class CategoryProgress {
  final String category;
  final String? lastReflectionDate;
  final int pendingCount;
  final String? currentSummary;
  final String? progressNote;
  final int totalMessages;

  CategoryProgress({
    required this.category,
    this.lastReflectionDate,
    this.pendingCount = 0,
    this.currentSummary,
    this.progressNote,
    this.totalMessages = 0,
  });
}

class JourneysScreen extends StatefulWidget {
  const JourneysScreen({super.key});

  @override
  State<JourneysScreen> createState() => _JourneysScreenState();
}

class _JourneysScreenState extends State<JourneysScreen> {
  final supabase = Supabase.instance.client;
  late final String _userId = supabase.auth.currentUser?.id ?? 'anonymous';
  
  Map<String, CategoryProgress> _categoryProgress = {};
  bool _isLoading = true;
  late RealtimeChannel _channel;

  // Available categories
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Spiritual', 'icon': Icons.mosque, 'color': Color(0xFF9C27B0)},
    {'name': 'Relationships', 'icon': Icons.people, 'color': Color(0xFFE91E63)},
    {'name': 'Health', 'icon': Icons.favorite, 'color': Color(0xFFF44336)},
    {'name': 'Career', 'icon': Icons.work, 'color': Color(0xFF2196F3)},
    {'name': 'Personal Growth', 'icon': Icons.trending_up, 'color': Color(0xFF00BCD4)},
    {'name': 'Financial', 'icon': Icons.attach_money, 'color': Color(0xFF4CAF50)},
    {'name': 'Education', 'icon': Icons.school, 'color': Color(0xFFFF9800)},
    {'name': 'General', 'icon': Icons.chat, 'color': Color(0xFF607D8B)},
  ];

  @override
  void initState() {
    super.initState();
    _loadCategoryProgress();
    _setupRealtime();
  }

  Future<void> _loadCategoryProgress() async {
    setState(() => _isLoading = true);

    try {
      // Get all chat history for this user
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', _userId)
          .order('happened_at', ascending: false);

      final Map<String, CategoryProgress> progressMap = {};

      // Group by category
      for (final record in response) {
        final category = record['category_context'] as String? ?? 'General';
        
        if (!progressMap.containsKey(category)) {
          progressMap[category] = CategoryProgress(
            category: category,
            lastReflectionDate: record['happened_at'] as String?,
            pendingCount: record['pending_count'] as int? ?? 0,
            currentSummary: record['cumulative_summary'] as String?,
            progressNote: record['progress_note'] as String?,
            totalMessages: 1,
          );
        } else {
          // Update with latest data
          final existing = progressMap[category]!;
          progressMap[category] = CategoryProgress(
            category: category,
            lastReflectionDate: existing.lastReflectionDate,
            pendingCount: record['pending_count'] as int? ?? existing.pendingCount,
            currentSummary: record['cumulative_summary'] as String? ?? existing.currentSummary,
            progressNote: record['progress_note'] as String? ?? existing.progressNote,
            totalMessages: existing.totalMessages + 1,
          );
        }
      }

      if (mounted) {
        setState(() {
          _categoryProgress = progressMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading category progress: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtime() {
    _channel = supabase.channel('journeys_updates').onPostgresChanges(
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
        // Reload progress when new messages arrive
        _loadCategoryProgress();
      },
    ).subscribe();
  }

  Map<String, dynamic> _getCategoryConfig(String category) {
    return _categories.firstWhere(
      (c) => c['name'] == category,
      orElse: () => _categories.last, // Default to General
    );
  }

  void _startNewJourney(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatbotScreen(),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryProgress progress) {
    final config = _getCategoryConfig(progress.category);
    final hasActivity = progress.totalMessages > 0;
    final hasPending = progress.pendingCount > 0;

    return GestureDetector(
      onTap: () => _startNewJourney(progress.category),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (config['color'] as Color).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (config['color'] as Color).withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (config['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    config['icon'] as IconData,
                    color: config['color'] as Color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.category,
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (progress.lastReflectionDate != null)
                        Text(
                          'Last: ${_formatDate(progress.lastReflectionDate!)}',
                          style: TextStyle(
                            color: AppColors.textLight.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pending_actions,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${progress.pendingCount}',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Summary (if exists)
            if (progress.currentSummary != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  progress.currentSummary!,
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

            // Progress note (if exists)
            if (progress.progressNote != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      progress.progressNote!,
                      style: TextStyle(
                        color: AppColors.textLight.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Stats bar
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatChip(
                  Icons.chat_bubble_outline,
                  '${progress.totalMessages} messages',
                  config['color'] as Color,
                ),
                const SizedBox(width: 8),
                if (hasActivity)
                  _buildStatChip(
                    Icons.trending_up,
                    'Active',
                    AppColors.accentGreen,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCategoryCard(Map<String, dynamic> categoryConfig) {
    return GestureDetector(
      onTap: () => _startNewJourney(categoryConfig['name']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (categoryConfig['color'] as Color).withValues(alpha: 0.2),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (categoryConfig['color'] as Color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                categoryConfig['icon'] as IconData,
                color: (categoryConfig['color'] as Color).withValues(alpha: 0.6),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryConfig['name'],
                    style: TextStyle(
                      color: AppColors.textLight.withValues(alpha: 0.7),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'No journey started yet',
                    style: TextStyle(
                      color: AppColors.textLight.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textLight.withValues(alpha: 0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('MMM d').format(date);
      }
    } catch (e) {
      return 'Recently';
    }
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
          'Your Journeys',
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
            onPressed: _loadCategoryProgress,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.accentGreen,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadCategoryProgress,
              color: AppColors.accentGreen,
              backgroundColor: AppColors.cardBackground,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Active journeys section
                  if (_categoryProgress.isNotEmpty) ...[
                    Text(
                      'Active Journeys',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._categoryProgress.values.map((progress) => _buildCategoryCard(progress)),
                    const SizedBox(height: 24),
                  ],

                  // Available categories
                  Text(
                    _categoryProgress.isEmpty ? 'Start Your First Journey' : 'Start New Journey',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._categories
                      .where((cat) => !_categoryProgress.containsKey(cat['name']))
                      .map((cat) => _buildEmptyCategoryCard(cat)),

                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewJourney('General'),
        backgroundColor: AppColors.accentGreen,
        icon: const Icon(Icons.add, color: AppColors.primaryDark),
        label: Text(
          'New Journey',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}