// lib/screens/self_eval/reflection_history_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:self_evaluator/constants/app_routes.dart';
import 'package:self_evaluator/services/reflection_service.dart';
import 'package:self_evaluator/utils/haptic_feedback.dart';

class ReflectionHistoryScreen extends StatelessWidget {
  const ReflectionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final service = ReflectionService();

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              "Please sign in to view your reflection history.",
              style: TextStyle(
                color: AppColors.textLight.withValues(alpha:0.9),
                fontSize: 18,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Your Reflection History",
          style: TextStyle(color: AppColors.textLight, fontSize: 20),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textLight),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getUserReflections(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGreen));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Something went wrong loading history.",
                style: TextStyle(color: AppColors.errorColor, fontSize: 16),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 80,
                      color: AppColors.accentGreen.withValues(alpha:0.6),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "No reflections yet",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Your first quiet moment of reflection will appear here when you're ready.",
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: AppColors.textLight.withValues(alpha:0.75),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final reflectionId = doc.id;

              final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
              final dateStr = completedAt != null
                  ? DateFormat('MMMM d, yyyy • h:mm a').format(completedAt)
                  : 'Unknown date';

              final category = data['category'] as String? ?? 'Unknown';

              String preview = "Reflection completed";
              final summary = data['summary'] as Map<String, dynamic>?;
              if (summary != null) {
                final strengths = summary['strengths'] as List<dynamic>? ?? [];
                final growth = summary['growthAreas'] as List<dynamic>? ?? [];
                preview = strengths.isNotEmpty
                    ? strengths.first.toString()
                    : (growth.isNotEmpty ? growth.first.toString() : preview);
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: AppColors.cardBackground.withValues(alpha:0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accentGreen.withValues(alpha:0.2),
                    child: Text(
                      category.isNotEmpty ? category[0].toUpperCase() : '?',
                      style: TextStyle(color: AppColors.accentGreen),
                    ),
                  ),
                  title: Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.accentGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview.length > 80 ? '${preview.substring(0, 77)}...' : preview,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textLight.withValues(alpha:0.8),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.errorColor.withValues(alpha:0.7),
                        ),
                        onPressed: () => _confirmDelete(context, reflectionId, doc),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.accentGreen,
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.reflectionSummary,
                      arguments: {
                        'answers': data['answers'] ?? {},
                        'summary': summary ?? {},
                        'category': category, // ← pass category to summary
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String reflectionId, QueryDocumentSnapshot doc) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final service = ReflectionService();

    service.deleteReflection(reflectionId);
    Haptic.warning();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Reflection deleted'),
        duration: const Duration(seconds: 5),
        backgroundColor: AppColors.cardBackground,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.accentGreen,
          onPressed: () {
            service.saveReflection(
              category: doc['category'] ?? 'personal_growth',
              startedAt: (doc['startedAt'] as Timestamp).toDate(),
              answers: Map<String, int>.from(
                (doc['answers'] as Map).map((key, value) => MapEntry(key.toString(), value as int)),
              ),
              summary: Map<String, dynamic>.from(doc['summary']),
            );

            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Reflection restored'),
                backgroundColor: AppColors.accentGreen,
              ),
            );
          },
        ),
      ),
    );
  }
}