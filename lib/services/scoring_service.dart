// lib/services/scoring_service.dart
class ScoringService {
  Map<String, int> categoryScores = {};

  void scoreQuestion(String category, int answerScore) {
    categoryScores.update(
      category,
      (val) => val + answerScore,
      ifAbsent: () => answerScore,
    );
  }

  String getCategoryLevel(String category) {
    int score = categoryScores[category] ?? 0;
    if (score >= 28) return "High";
    if (score >= 18) return "Medium";
    return "Low";
  }

  void resetScores() {
    categoryScores.clear();
  }
}
