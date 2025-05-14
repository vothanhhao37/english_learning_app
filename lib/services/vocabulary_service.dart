import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';

import '../models/vocabulary_model.dart';

class VocabularyService {
  final FlutterTts _tts = FlutterTts();

  VocabularyService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Stream<List<VocabularyTopic>> fetchTopics() {
    return FirebaseFirestore.instance
        .collection('vocabs_topics')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => VocabularyTopic.fromDoc(doc)).toList());
  }

  Future<List<VocabWord>> fetchWords(String topicId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('vocabs_topics')
        .doc(topicId)
        .collection('words')
        .get();
    return snapshot.docs.map((doc) => VocabWord.fromMap(doc.id, doc.data())).toList();
  }

  Future<List<Map<String, dynamic>>> loadQuiz(String topicId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final wordsSnap = await FirebaseFirestore.instance
        .collection('vocabs_topics')
        .doc(topicId)
        .collection('words')
        .get();

    final resultsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('vocabulary')
        .collection(topicId)
        .doc('summary')
        .collection('quizResults')
        .get();

    final totalQuestions = wordsSnap.docs.fold(0, (sum, doc) {
      final exercises = doc.data()['exercises'] as Map<String, dynamic>? ?? {};
      return sum + exercises.length;
    });

    final Map<String, String> quizStatuses = {
      for (final doc in resultsSnap.docs) doc.id: doc['status'] as String
    };

    final List<Map<String, dynamic>> allExercises = [];
    const supportedTypes = ['multiple_choice', 'listening_choice', 'vocab_reorder', 'typing'];

    for (final wordDoc in wordsSnap.docs) {
      final wordId = wordDoc.id;
      final data = wordDoc.data();
      final exercises = data['exercises'] as Map<String, dynamic>? ?? {};

      for (final entry in exercises.entries) {
        final type = entry.value['type'];
        if (supportedTypes.contains(type)) {
          final quizKey = entry.key;
          final quizId = '${wordId}_$quizKey';
          final status = quizStatuses[quizId];

          allExercises.add({
            'wordId': wordId,
            'type': type,
            'key': quizKey,
            'data': entry.value,
            'status': status,
          });
        }
      }
    }

    final pendingOrWrong = allExercises.where((e) => e['status'] != 'correct').toList();
    final correct = allExercises.where((e) => e['status'] == 'correct').toList();

    pendingOrWrong.shuffle(Random());
    correct.shuffle(Random());

    return [...pendingOrWrong, ...correct].take(15).toList();
  }

  Future<void> saveQuizResult({
    required String topicId,
    required String wordId,
    required String quizKey,
    required String type,
    required String status,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final quizId = '${wordId}_$quizKey';
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('vocabulary')
        .collection(topicId)
        .doc('summary')
        .collection('quizResults')
        .doc(quizId);

    await docRef.set({
      'wordId': wordId,
      'type': type,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastAttemptTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateTopicProgress(String topicId, String topicTitle) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Get total questions from topic
    final wordsSnap = await FirebaseFirestore.instance
        .collection('vocabs_topics')
        .doc(topicId)
        .collection('words')
        .get();
    
    int totalQuestions = 0;
    for (var wordDoc in wordsSnap.docs) {
      final exercises = wordDoc.data()['exercises'] as Map<String, dynamic>? ?? {};
      totalQuestions += exercises.length;
    }

    // Get unique quiz results for this topic
    final quizResultsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('vocabulary')
        .collection(topicId)
        .doc('summary')
        .collection('quizResults')
        .get();

    // Count unique quizIds attempted and correct ones
    Set<String> attemptedQuizIds = {};
    Set<String> correctQuizIds = {};
    
    for (var doc in quizResultsSnap.docs) {
      final quizId = doc.id;
      attemptedQuizIds.add(quizId);
      if (doc['status'] == 'correct') {
        correctQuizIds.add(quizId);
      }
    }

    final completedQuestions = attemptedQuizIds.length;
    final correctQuestions = correctQuizIds.length;

    // Calculate progress and accuracy
    final progress = totalQuestions > 0 ? completedQuestions / totalQuestions : 0;
    final accuracy = completedQuestions > 0 ? correctQuestions / completedQuestions : 0;

    // Update topic summary
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('vocabulary')
        .collection(topicId)
        .doc('summary')
        .set({
      'topicId': topicId,
      'topicTitle': topicTitle,
      'totalQuestions': totalQuestions,
      'completedQuestions': completedQuestions,
      'correctQuestions': correctQuestions,
      'progress': progress,
      'accuracy': accuracy,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update overall vocabulary progress
    await updateOverallProgress(uid);
  }

  Future<void> updateOverallProgress(String uid) async {
    // Get all topics
    final allTopicsSnap = await FirebaseFirestore.instance.collection('vocabs_topics').get();
    
    int totalQuestions = 0;
    int totalCompletedQuestions = 0;
    int totalCorrectQuestions = 0;
    Map<String, int> topicsQuestions = {};

    // Process each topic
    for (var topicDoc in allTopicsSnap.docs) {
      final topicId = topicDoc.id;
      
      // Get topic summary
      final topicSummarySnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('vocabulary')
          .collection(topicId)
          .doc('summary')
          .get();

      if (topicSummarySnap.exists) {
        final data = topicSummarySnap.data()!;
        final topicTotalQuestions = data['totalQuestions'] as int? ?? 0;
        final topicCompletedQuestions = data['completedQuestions'] as int? ?? 0;
        final topicCorrectQuestions = data['correctQuestions'] as int? ?? 0;

        totalQuestions += topicTotalQuestions;
        totalCompletedQuestions += topicCompletedQuestions;
        totalCorrectQuestions += topicCorrectQuestions;
        topicsQuestions[topicId] = topicTotalQuestions;
      }
    }

    // Calculate overall progress and accuracy
    final overallProgress = totalQuestions > 0 ? totalCompletedQuestions / totalQuestions : 0;
    final overallAccuracy = totalCompletedQuestions > 0 ? totalCorrectQuestions / totalCompletedQuestions : 0;

    // Update overall summary
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('vocabulary')
        .set({
      'summary': {
        'totalTopics': allTopicsSnap.docs.length,
        'totalQuestions': totalQuestions,
        'totalCompletedQuestions': totalCompletedQuestions,
        'totalCorrectQuestions': totalCorrectQuestions,
        'overallProgress': overallProgress,
        'overallAccuracy': overallAccuracy,
        'topicsQuestions': topicsQuestions,
        'lastUpdated': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.4);
      await _tts.setPitch(1.0);
      await _tts.speak(text);
    }
  }

  void dispose() {
    _tts.stop();
  }
}