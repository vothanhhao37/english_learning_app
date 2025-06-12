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

    final Map<String, bool> quizResultsStatus = {
      for (final doc in resultsSnap.docs) doc.id: doc['bestResult'] as bool? ?? false
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
          final isCorrect = quizResultsStatus[quizId] ?? false;

          allExercises.add({
            'wordId': wordId,
            'type': type,
            'key': quizKey,
            'data': entry.value,
            'status': isCorrect ? 'correct' : 'pending',
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
    required bool isCorrect,
    required String userAnswer,
    required String topicTitle,
    int scorePerCorrectAnswer = 10,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final quizId = '${wordId}_$quizKey';
    final summaryDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('vocabulary')
        .collection(topicId)
        .doc('summary')
        .collection('quizResults')
        .doc(quizId);

    final attemptsColRef = summaryDocRef.collection('attempts');

    try {
      await attemptsColRef.add({
        'isCorrect': isCorrect,
        'score': isCorrect ? scorePerCorrectAnswer : 0,
        'timestamp': FieldValue.serverTimestamp(),
        'userAnswer': userAnswer,
      });

      final summaryDoc = await summaryDocRef.get();
      int currentAttemptCount = 0;
      bool currentBestResult = false;

      if (summaryDoc.exists) {
        final data = summaryDoc.data()!;
        currentAttemptCount = (data['attemptCount'] as int? ?? 0);
        currentBestResult = (data['bestResult'] as bool? ?? false);
      }

      final newBestResult = currentBestResult || isCorrect;

      await summaryDocRef.set({
        'wordId': wordId,
        'quizKey': quizKey,
        'type': type,
        'attemptCount': currentAttemptCount + 1,
        'bestResult': newBestResult,
        'lastAttemptTime': FieldValue.serverTimestamp(),
        'topicTitle': topicTitle,
      }, SetOptions(merge: true));

      await updateTopicProgress(topicId, topicTitle);
      await updateOverallProgress(uid);

      print('Đã lưu kết quả bài tập từ vựng (attempt) cho $quizId, đúng: $isCorrect. Summary updated.');

    } catch (e) {
       print('Lỗi khi lưu kết quả bài tập từ vựng: $e');
    }
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

    // Get quiz results summaries for this topic
    final quizResultsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('vocabulary')
        .collection(topicId)
        .doc('summary')
        .collection('quizResults')
        .get();

    // Tính toán completedQuestions và correctQuestions từ các document summary
    int completedQuestions = quizResultsSnap.docs.length;
    int correctQuestions = 0;
    
    for (var doc in quizResultsSnap.docs) {
      final bestResult = doc.data()['bestResult'] as bool? ?? false;
      if (bestResult) {
        correctQuestions++;
      }
    }

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
    // Get all topics (logic này vẫn đúng)
    final allTopicsSnap = await FirebaseFirestore.instance.collection('vocabs_topics').get();
    
    int totalQuestions = 0;
    // totalCompletedQuestions và totalCorrectQuestions sẽ tổng hợp từ summary chủ đề
    int totalCompletedQuestions = 0;
    int totalCorrectQuestions = 0;
    Map<String, int> topicsQuestions = {}; // Map này lưu tổng số câu hỏi mỗi chủ đề gốc

    // Process each topic
    for (var topicDoc in allTopicsSnap.docs) {
      final topicId = topicDoc.id;
      // Lấy tổng số câu hỏi từ dữ liệu gốc của chủ đề
      final wordsSnap = await FirebaseFirestore.instance
          .collection('vocabs_topics')
          .doc(topicId)
          .collection('words')
          .get();
      int topicTotalQuestions = 0;
       for (var wordDoc in wordsSnap.docs) {
          final exercises = wordDoc.data()['exercises'] as Map<String, dynamic>? ?? {};
          topicTotalQuestions += exercises.length;
       }
       totalQuestions += topicTotalQuestions;
       topicsQuestions[topicId] = topicTotalQuestions;

      // Get topic summary (lấy document summary của chủ đề)
      final topicSummaryDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('vocabulary')
          .collection(topicId)
          .doc('summary') // Lấy document summary của chủ đề
          .get();

      if (topicSummaryDoc.exists) {
        final data = topicSummaryDoc.data()!;
        // Đọc completedQuestions và correctQuestions từ document summary chủ đề
        final topicCompletedQuestions = data['completedQuestions'] as int? ?? 0;
        final topicCorrectQuestions = data['correctQuestions'] as int? ?? 0;

        // Cộng dồn vào tổng
        totalCompletedQuestions += topicCompletedQuestions;
        totalCorrectQuestions += topicCorrectQuestions;
        // topicsQuestions[topicId] = topicTotalQuestions; // Đã làm ở trên
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
        .doc('vocabulary') // Cập nhật document summary tổng thể
        .set({
      'summary': { // Lưu vào subfield summary
        'totalTopics': allTopicsSnap.docs.length,
        'totalQuestions': totalQuestions,
        'totalCompletedQuestions': totalCompletedQuestions,
        'totalCorrectQuestions': totalCorrectQuestions,
        'overallProgress': overallProgress,
        'overallAccuracy': overallAccuracy,
        'topicsQuestions': topicsQuestions, // Lưu map tổng số câu mỗi chủ đề gốc
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