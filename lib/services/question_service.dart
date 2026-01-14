import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:self_evaluator/models/question_model.dart';

class QuestionService {
  Future<List<QuestionModel>> loadQuestions() async {
    final String jsonString = await rootBundle.loadString(
      'assets/data/self_eval_full_questions.json',
    );

    final Map<String, dynamic> jsonMap = json.decode(jsonString);

    final List<dynamic> rawList = jsonMap['questions'] ?? [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((json) {
          try {
            return QuestionModel.fromJson(json);
          } catch (e) {
            if (kDebugMode) {
              print("❌ Error parsing question: $e");
            }
            return null;
          }
        })
        .whereType<QuestionModel>()
        .toList();
  }
}
