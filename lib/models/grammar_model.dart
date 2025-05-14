class GrammarModel {
  final String title;
  final String description;
  final List<String> structures;
  final TheoryModel theory;
  final List<ExampleModel> examples;

  GrammarModel({
    required this.title,
    required this.description,
    required this.structures,
    required this.theory,
    required this.examples,
  });
}

class TheoryModel {
  final List<String> explanation;
  final String tips;

  TheoryModel({
    required this.explanation,
    required this.tips,
  });
}

class ExampleModel {
  final String sentence;
  final String translation;
  final String explanation;

  ExampleModel({
    required this.sentence,
    required this.translation,
    required this.explanation,
  });
}

class Exercise {
  final String id;
  final String type;
  final String question;
  final String answer;
  final String explanation;
  final List<String>? options;

  Exercise({
    required this.id,
    required this.type,
    required this.question,
    required this.answer,
    required this.explanation,
    this.options,
  });
}