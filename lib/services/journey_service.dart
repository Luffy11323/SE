// lib/services/journey_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:self_evaluator/screens/self_eval/mcq_session_screen.dart';
import 'package:self_evaluator/screens/journeys/journeys_dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class JourneyService {
  final supabase = Supabase.instance.client;

  /// Get the current status of a category journey
  Future<CategoryJourney> getCategoryStatus(String userId, String category) async {
    try {
      // Query chat_history for this category
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId)
          .eq('category_context', category)
          .order('happened_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return CategoryJourney(
          category: category,
          status: 'no_session',
        );
      }

      final latest = response.first;
      final pendingCount = latest['pending_count'] as int? ?? 0;
      final summary = latest['cumulative_summary'] as String?;
      final lastActive = DateTime.parse(latest['happened_at'] as String);

      String status;
      if (pendingCount > 0) {
        status = 'ongoing';
      } else if (summary != null && summary.isNotEmpty) {
        status = 'completed';
      } else {
        status = 'no_session';
      }

      return CategoryJourney(
        category: category,
        status: status,
        pendingCount: pendingCount,
        lastActive: lastActive,
        sessionId: latest['id'] as String?,
        summary: summary,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting category status: $e');
      }
      return CategoryJourney(
        category: category,
        status: 'no_session',
      );
    }
  }

  /// Get all pending MCQ questions for a category
  Future<List<MCQQuestion>> getPendingQuestions(String userId, String category) async {
    try {
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId)
          .eq('category_context', category)
          .eq('message_type', 'bot')
          .not('mcq_question', 'is', null)
          .order('happened_at', ascending: true);

      final questions = <MCQQuestion>[];

      for (final record in response) {
        final mcqData = record['mcq_question'];
        if (mcqData != null && mcqData is Map) {
          questions.add(MCQQuestion(
            id: record['id'] as String,
            question: mcqData['question'] as String? ?? 'Question',
            options: List<String>.from(mcqData['options'] as List? ?? []),
            recordId: record['id'] as String?,
          ));
        }
      }

      return questions;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting pending questions: $e');
      }
      return [];
    }
  }

  /// Save partial answers (draft) for resume later
  Future<void> savePartialAnswers(
    String userId,
    String category,
    Map<String, String> answers,
    int currentIndex,
  ) async {
    try {
      await supabase.from('journey_progress').upsert({
        'user_id': userId,
        'category': category,
        'answers': answers,
        'current_index': currentIndex,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error saving partial answers: $e');
      }
      rethrow;
    }
  }

  /// Get cumulative summary and progress notes for a category
  Future<Map<String, String?>> getCumulativeSummary(String userId, String category) async {
    try {
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId)
          .eq('category_context', category)
          .eq('message_type', 'bot')
          .order('happened_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return {
          'cumulative_summary': null,
          'progress_note': null,
          'voice_answer': null,
        };
      }

      final latest = response.first;
      return {
        'cumulative_summary': latest['cumulative_summary'] as String?,
        'progress_note': latest['progress_note'] as String?,
        'voice_answer': latest['voice_answer'] as String?,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting summary: $e');
      }
      return {
        'cumulative_summary': null,
        'progress_note': null,
        'voice_answer': null,
      };
    }
  }

  /// Reset a journey (clear all progress and start fresh)
  Future<void> resetJourney(String userId, String category) async {
    try {
      // Archive current journey (optional - move to history table)
      final currentData = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId)
          .eq('category_context', category);

      if (currentData.isNotEmpty) {
        // Archive to journey_history table
        await supabase.from('journey_history').insert(
          currentData.map((record) => {
            ...record,
            'archived_at': DateTime.now().toIso8601String(),
          }).toList(),
        );

        // Delete from chat_history
        await supabase
            .from('chat_history')
            .delete()
            .eq('user_id', userId)
            .eq('category_context', category);
      }

      // Clear progress
      await supabase
          .from('journey_progress')
          .delete()
          .eq('user_id', userId)
          .eq('category', category);

      if (kDebugMode) {
        print('Journey reset successfully for $category');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting journey: $e');
      }
      rethrow;
    }
  }

  /// Load saved progress for resume
  Future<Map<String, dynamic>?> loadProgress(String userId, String category) async {
    try {
      final response = await supabase
          .from('journey_progress')
          .select()
          .eq('user_id', userId)
          .eq('category', category)
          .single();

      return {
        'answers': response['answers'] as Map<String, dynamic>,
        'current_index': response['current_index'] as int,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error loading progress: $e');
      }
      return null;
    }
  }

  /// Get journey statistics for dashboard
  Future<Map<String, int>> getJourneyStats(String userId) async {
    try {
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId);

      final categories = <String>{};
      int totalPending = 0;
      int completed = 0;

      for (final record in response) {
        final category = record['category_context'] as String?;
        if (category != null) {
          categories.add(category);
          
          final pendingCount = record['pending_count'] as int? ?? 0;
          totalPending += pendingCount;

          if (pendingCount == 0 && record['cumulative_summary'] != null) {
            completed++;
          }
        }
      }

      return {
        'total_categories': categories.length,
        'active_journeys': categories.where((cat) {
          return response.any((r) => 
            r['category_context'] == cat && 
            (r['pending_count'] as int? ?? 0) > 0
          );
        }).length,
        'completed_journeys': completed,
        'total_pending': totalPending,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting journey stats: $e');
      }
      return {
        'total_categories': 0,
        'active_journeys': 0,
        'completed_journeys': 0,
        'total_pending': 0,
      };
    }
  }

  /// Submit a batch of answers to the chat endpoint
  Future<Map<String, dynamic>?> submitAnswerBatch(
    String userId,
    String category,
    List<Map<String, String>> answers,
  ) async {
    try {
      // Each answer is submitted as a separate user message
      for (final answer in answers) {
        await supabase.from('chat_history').insert({
          'user_id': userId,
          'message_type': 'user',
          'content': answer['answer'],
          'category_context': category,
        });

        // Small delay between submissions
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Get the latest bot response with summary
      await Future.delayed(const Duration(seconds: 2));
      
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId)
          .eq('category_context', category)
          .eq('message_type', 'bot')
          .order('happened_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        return {
          'cumulative_summary': response.first['cumulative_summary'],
          'progress_note': response.first['progress_note'],
          'voice_answer': response.first['voice_answer'],
          'pending_count': response.first['pending_count'],
        };
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting answer batch: $e');
      }
      rethrow;
    }
  }

  /// Get journey history (archived sessions)
  Future<List<Map<String, dynamic>>> getJourneyHistory(String userId, String category) async {
    try {
      final response = await supabase
          .from('journey_history')
          .select()
          .eq('user_id', userId)
          .eq('category_context', category)
          .order('archived_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting journey history: $e');
      }
      return [];
    }
  }

  /// Check if category has active session
  Future<bool> hasActiveSession(String userId, String category) async {
    try {
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId)
          .eq('category_context', category)
          .eq('message_type', 'bot')
          .not('pending_count', 'eq', 0)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking active session: $e');
      }
      return false;
    }
  }

  /// Get last activity date for category
  Future<DateTime?> getLastActivityDate(String userId, String category) async {
    try {
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId)
          .eq('category_context', category)
          .order('happened_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      return DateTime.parse(response.first['happened_at'] as String);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting last activity: $e');
      }
      return null;
    }
  }

  /// Get total questions answered for category
  Future<int> getTotalQuestionsAnswered(String userId, String category) async {
    try {
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId)
          .eq('category_context', category)
          .eq('message_type', 'user');

      return response.length;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting total questions: $e');
      }
      return 0;
    }
  }
}