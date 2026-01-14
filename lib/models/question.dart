class QuestionModel {
  final String category;
  final String question;
  final List<String> options;
  final String? subcategory;
  final String? tone;
  final String? difficulty;

  QuestionModel({
    required this.category,
    required this.question,
    required this.options,
    this.subcategory,
    this.tone,
    this.difficulty,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      category: json['category'],
      question: json['question'],
      options: List<String>.from(json['options']),
      subcategory: json['subcategory'],
      tone: json['tone'],
      difficulty: json['difficulty'],
    );
  }
}
