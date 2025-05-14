import 'package:cloud_firestore/cloud_firestore.dart';

class VocabularyTopic {
  final String id;
  final String title;
  final String description;
  final String imageUrl;

  VocabularyTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
  });

  factory VocabularyTopic.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VocabularyTopic(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}

class VocabWord {
  final String id;
  final String word;
  final String meaning;
  final String ipa;
  final String type;
  final String usage;
  final String example;
  final Map<String, dynamic> exercises;

  VocabWord({
    required this.id,
    required this.word,
    required this.meaning,
    required this.ipa,
    required this.type,
    required this.usage,
    required this.example,
    required this.exercises,
  });

  factory VocabWord.fromMap(String id, Map<String, dynamic> data) {
    return VocabWord(
      id: id,
      word: data['word'] ?? '',
      meaning: data['meaning'] ?? '',
      ipa: data['ipa'] ?? '',
      type: data['type'] ?? '',
      usage: data['usage'] ?? '',
      example: data['example'] ?? '',
      exercises: data['exercises'] ?? {},
    );
  }
}