class ConversationPronunciationTopic {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final List<ConversationLesson> lessons;

  ConversationPronunciationTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.lessons,
  });

  factory ConversationPronunciationTopic.fromMap(String id, Map<String, dynamic> data, List<ConversationLesson> lessons) {
    return ConversationPronunciationTopic(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      lessons: lessons,
    );
  }
}

class ConversationLesson {
  final String id;
  final String type;
  final String? title;
  final String? sentence;
  final List<Map<String, String>>? dialogue;

  ConversationLesson({
    required this.id,
    required this.type,
    this.title,
    this.sentence,
    this.dialogue,
  });

  factory ConversationLesson.fromMap(String id, Map<String, dynamic> data) {
    return ConversationLesson(
      id: id,
      type: data['type'] ?? 'unknown',
      title: data['title'],
      sentence: data['sentence'],
      dialogue: data['dialogue'] != null
          ? (data['dialogue'] as List<dynamic>)
          .map((e) => {
        'question': e['question']?.toString() ?? '',
        'answer': e['answer']?.toString() ?? '',
      })
          .toList()
          : null,
    );
  }
}