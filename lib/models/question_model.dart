class QuestionModel {
  final String question;
  final String category;
  final String? level;
  final String? tone;
  final int? repeatDelay;
  final int? difficulty;

  QuestionModel({
    required this.question,
    required this.category,
    this.level,
    this.tone,
    this.repeatDelay,
    this.difficulty,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      question: json['question'],
      category: json['category'],
      level: json['level'],
      tone: json['tone'],
      repeatDelay: json['repeat_delay'],
      difficulty: json['difficulty'],
    );
  }
}
