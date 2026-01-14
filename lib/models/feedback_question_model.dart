class FeedbackQuestion {
  final String id;
  final String question;
  final String category;
  final String? level;
  final String? tone;
  final int? repeatDelay;
  final int? difficulty;

  FeedbackQuestion({
    required this.id,
    required this.question,
    required this.category,
    this.level,
    this.tone,
    this.repeatDelay,
    this.difficulty,
  });

  factory FeedbackQuestion.fromJson(Map<String, dynamic> json) {
    return FeedbackQuestion(
      id: json['id'],
      question: json['question'],
      category: json['category'],
      level: json['level'],
      tone: json['tone'],
      repeatDelay: json['repeat_delay'],
      difficulty: json['difficulty'],
    );
  }
}
