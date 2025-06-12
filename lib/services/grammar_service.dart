import '../models/grammar_model.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../services/profile_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class GrammarService {
  final FirebaseService _firebaseService;
  List<Exercise> _exercises = [];
  int _currentQuestionIndex = 0;
  bool _isAnswered = false;
  bool _isCorrect = false;
  int _correctAnswers = 0;
  dynamic _userAnswer;

  GrammarService(this._firebaseService);

  List<Exercise> get exercises => _exercises;
  int get currentQuestionIndex => _currentQuestionIndex;
  bool get isAnswered => _isAnswered;
  bool get isCorrect => _isCorrect;
  int get correctAnswers => _correctAnswers;
  dynamic get userAnswer => _userAnswer;

  static const _grammarTopicsQuestionsCacheKey = 'grammar_topics_questions_cache';
  static const _grammarTopicsQuestionsCacheTTL = Duration(hours: 24); // cache 1 ngày

  static Future<Map<String, dynamic>> getGrammarTopicsQuestionsCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheString = prefs.getString(_grammarTopicsQuestionsCacheKey);
    if (cacheString == null) return {};
    final cache = jsonDecode(cacheString);
    final timestamp = DateTime.tryParse(cache['timestamp'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (DateTime.now().difference(timestamp) > _grammarTopicsQuestionsCacheTTL) {
      return {};
    }
    return cache['data'] ?? {};
  }

  static Future<void> setGrammarTopicsQuestionsCache(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = {
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };
    await prefs.setString(_grammarTopicsQuestionsCacheKey, jsonEncode(cache));
  }

  static Future<void> saveGrammarScore({
    required String topicId,
    required String exerciseId,
    required String exerciseType,
    required String userAnswer,
    required bool isCorrect,
    int scorePerQuestion = 10,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Vui lòng đăng nhập để lưu điểm');
      return;
    }

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      // 1. Lưu attempt và cập nhật exercise (dùng batch)
      final batch = FirebaseFirestore.instance.batch();
      final exerciseRef = userDocRef
          .collection('learningProgress')
          .doc('grammar')
          .collection('topics')
          .doc(topicId)
          .collection('exercises')
          .doc(exerciseId);

      final exerciseSnap = await exerciseRef.get();
      final currentData = exerciseSnap.exists ? exerciseSnap.data()! : {};

      final uuid = Uuid();
      final attemptRef = exerciseRef.collection('attempts').doc(uuid.v4());
      batch.set(attemptRef, {
        'userAnswer': userAnswer,
        'isCorrect': isCorrect,
        'score': isCorrect ? scorePerQuestion : 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final newBestScore = isCorrect ? scorePerQuestion : (currentData['bestScore'] ?? 0);
      final newTotalAttempts = (currentData['totalAttempts'] ?? 0) + 1;
      final isCompleted = isCorrect || (currentData['isCompleted'] ?? false);
      final hasCorrectAttempt = (currentData['hasCorrectAttempt'] == true) || isCorrect;

      batch.set(exerciseRef, {
        'type': exerciseType,
        'bestScore': newBestScore,
        'totalAttempts': newTotalAttempts,
        'isCompleted': isCompleted,
        'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
        'lastAttemptAt': FieldValue.serverTimestamp(),
        'hasCorrectAttempt': hasCorrectAttempt,
      }, SetOptions(merge: true));

      await batch.commit();

      // 2. Sau khi batch xong, lấy lại exercises và cập nhật progress topic
      final topicDocRef = userDocRef
          .collection('learningProgress')
          .doc('grammar')
          .collection('topics')
          .doc(topicId);
      final topicDocSnap = await topicDocRef.get();
      final topicData = topicDocSnap.exists ? topicDocSnap.data()! : {};
      final totalQuestions = topicData['totalQuestions'] as int? ?? 0;

      final exercisesSnap = await topicDocRef.collection('exercises').get();
      int completedQuestions = 0;
      int correctQuestions = 0;
      for (final ex in exercisesSnap.docs) {
        final exData = ex.data();
        completedQuestions++;
        if (exData['hasCorrectAttempt'] == true) correctQuestions++;
      }
      final progress = totalQuestions > 0 ? correctQuestions / totalQuestions : 0.0;
      final accuracy = completedQuestions > 0 ? correctQuestions / completedQuestions : 0.0;
      await topicDocRef.set({
        'completedQuestions': completedQuestions,
        'correctQuestions': correctQuestions,
        'progress': progress,
        'accuracy': accuracy,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Cập nhật summary tổng cho user
      await updateGrammarOverallSummary(user.uid, {});

      // Xóa cache grammar progress để lần sau vào profile sẽ lấy dữ liệu mới nhất
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('grammar_progress_cache');

      // Debounce cập nhật cache grammar progress sau khi user dừng thao tác 500ms
      final profileService = ProfileService();
      cacheDebouncer.run(() async {
        await profileService.getGrammarProgress();
      });

      print('Đã lưu điểm cho câu hỏi grammar và cập nhật progress topic');
    } catch (e) {
      print('Lỗi khi lưu điểm: $e');
      throw Exception('Failed to save score: $e');
    }
  }

  static Future<void> updateGrammarSummaryForTopic(String userId, String topicId) async {
    final startTime = DateTime.now();
    print('[SUMMARY] Bắt đầu cập nhật summary cho topic $topicId lúc: [${startTime.toIso8601String()}');
    try {
      Map<String, dynamic> topicsMeta = await getGrammarTopicsQuestionsCache();
      if (!topicsMeta.containsKey(topicId)) {
        final topicDoc = await FirebaseFirestore.instance.collection('grammar').doc(topicId).get();
        final topicTitle = topicDoc.data()?['title'] ?? '';
        final exercisesRootSnap = await FirebaseFirestore.instance
            .collection('grammar')
            .doc(topicId)
            .collection('exercises')
            .get();
        int topicTotalQuestions = exercisesRootSnap.docs.length;
        topicsMeta[topicId] = {
          'totalQuestions': topicTotalQuestions,
          'topicTitle': topicTitle,
        };
        await setGrammarTopicsQuestionsCache(topicsMeta);
      }
      final topicTotalQuestions = topicsMeta[topicId]['totalQuestions'] ?? 0;
      final topicTitle = topicsMeta[topicId]['topicTitle'] ?? '';

      final userExercisesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('learningProgress')
          .doc('grammar')
          .collection('topics')
          .doc(topicId)
          .collection('exercises')
          .get();
      int topicCompletedQuestions = userExercisesSnap.docs.length;
      int topicCorrectQuestions = 0;
      for (final ex in userExercisesSnap.docs) {
        final data = ex.data();
        if (data['hasCorrectAttempt'] == true) topicCorrectQuestions++;
      }
      final progress = topicTotalQuestions > 0 ? topicCorrectQuestions / topicTotalQuestions : 0.0;
      final accuracy = topicCompletedQuestions > 0 ? topicCorrectQuestions / topicCompletedQuestions : 0.0;

      final topicSummaryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('learningProgress')
          .doc('grammar')
          .collection('topics')
          .doc(topicId)
          .collection('summary')
          .doc('summary');
      await topicSummaryRef.set({
        'topicId': topicId,
        'topicTitle': topicTitle,
        'totalQuestions': topicTotalQuestions,
        'completedQuestions': topicCompletedQuestions,
        'correctQuestions': topicCorrectQuestions,
        'progress': progress,
        'accuracy': accuracy,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await updateGrammarOverallSummary(userId, topicsMeta);
      final endTime = DateTime.now();
      final elapsed = endTime.difference(startTime).inMilliseconds;
      print('[SUMMARY] Đã cập nhật summary cho topic $topicId thành công! Thời gian: ${elapsed} ms');
    } catch (e) {
      print('Lỗi khi cập nhật summary topic: $e');
    }
  }

  static Future<void> updateGrammarOverallSummary(String userId, Map<String, dynamic> topicsMeta) async {
    final startTime = DateTime.now();
    print('[SUMMARY] Bắt đầu cập nhật overall summary grammar lúc: ${startTime.toIso8601String()}');
    try {
      final topicsCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('learningProgress')
          .doc('grammar')
          .collection('topics');
      final topicsSnap = await topicsCollection.get();

      int totalTopics = topicsSnap.docs.length;
      int totalQuestions = 0;
      int totalCompletedQuestions = 0;
      int totalCorrectQuestions = 0;
      Map<String, int> topicsQuestions = {};

      for (final doc in topicsSnap.docs) {
        final data = doc.data();
        final topicId = data['topicId'] ?? doc.id;
        final tq = data['totalQuestions'] as int? ?? 0;
        final completed = data['completedQuestions'] as int? ?? 0;
        final correct = data['correctQuestions'] as int? ?? 0;
        topicsQuestions[topicId] = tq;
        totalQuestions += tq;
        totalCompletedQuestions += completed;
        totalCorrectQuestions += correct;
        }

      final overallProgress = totalQuestions > 0 ? totalCorrectQuestions / totalQuestions : 0.0;
      final overallAccuracy = totalCompletedQuestions > 0 ? totalCorrectQuestions / totalCompletedQuestions : 0.0;

      final overallSummaryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('learningProgress')
          .doc('grammar')
          .collection('summary')
          .doc('summary');
      await overallSummaryRef.set({
        'totalTopics': totalTopics,
        'totalQuestions': totalQuestions,
        'totalCompletedQuestions': totalCompletedQuestions,
        'totalCorrectQuestions': totalCorrectQuestions,
        'overallProgress': overallProgress,
        'overallAccuracy': overallAccuracy,
        'topicsQuestions': topicsQuestions,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final endTime = DateTime.now();
      final elapsed = endTime.difference(startTime).inMilliseconds;
      print('[SUMMARY] Đã cập nhật overall summary grammar thành công! Thời gian: ${elapsed} ms');
    } catch (e) {
      print('Lỗi khi cập nhật overall summary: $e');
    }
  }

  static Future<void> syncGrammarTopicSummariesForUser(String userId) async {
    final startTime = DateTime.now();
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final grammarRootSnap = await FirebaseFirestore.instance.collection('grammar').get();

    final futures = grammarRootSnap.docs.map((doc) async {
      final topicId = doc.id;
      final topicTitle = doc.data()['title']?.toString() ?? topicId;
      final exercisesSnap = await FirebaseFirestore.instance
          .collection('grammar')
          .doc(topicId)
          .collection('exercises')
          .get();
      final totalQuestions = exercisesSnap.docs.length;
      final topicDocRef = userDocRef
          .collection('learningProgress')
          .doc('grammar')
          .collection('topics')
          .doc(topicId);
      final topicSnap = await topicDocRef.get();
      if (!topicSnap.exists) {
        await topicDocRef.set({
          'topicId': topicId,
          'topicTitle': topicTitle,
          'totalQuestions': totalQuestions,
          'completedQuestions': 0,
          'correctQuestions': 0,
          'progress': 0.0,
          'accuracy': 0.0,
          'lastUpdated': null,
        });
      } else {
        // Nếu đã tồn tại, chỉ update title/totalQuestions nếu cần
        await topicDocRef.set({
          'topicTitle': topicTitle,
          'totalQuestions': totalQuestions,
        }, SetOptions(merge: true));
      }
    }).toList();

    await Future.wait(futures);

    final endTime = DateTime.now();
    final elapsed = endTime.difference(startTime).inMilliseconds;
    print('[SYNC] syncGrammarTopicSummariesForUser executed in ${elapsed} ms');
  }

  // Debounce cập nhật cache grammar progress
  static final CacheDebouncer cacheDebouncer = CacheDebouncer();

  Future<void> setExercises(String grammarId, String type) async {
    _exercises = await _firebaseService.grammar_fetchExercises(grammarId, type);
    _currentQuestionIndex = 0;
    _isAnswered = false;
    _isCorrect = false;
    _correctAnswers = 0;
    _userAnswer = null;
  }

  Future<void> checkAnswer(dynamic userAnswer, Exercise exercise, String topicId) async {
    _isAnswered = true;
    _userAnswer = userAnswer;
    _isCorrect = userAnswer.toString().toLowerCase() == exercise.answer.toLowerCase();
    if (_isCorrect) _correctAnswers++;

    await saveGrammarScore(
      topicId: topicId,
      exerciseId: exercise.id,
      exerciseType: exercise.type,
      userAnswer: userAnswer.toString(),
      isCorrect: _isCorrect,
    );
  }

  void nextQuestion() {
    if (_currentQuestionIndex < _exercises.length - 1) {
      _currentQuestionIndex++;
      _isAnswered = false;
      _isCorrect = false;
      _userAnswer = null;
    }
  }

  void reset() {
    _currentQuestionIndex = 0;
    _isAnswered = false;
    _isCorrect = false;
    _correctAnswers = 0;
    _userAnswer = null;
    _exercises = [];
  }

  Future<GrammarModel> fetchGrammarLesson(String grammarId) async {
    return await _firebaseService.grammar_fetchGrammarLesson(grammarId);
  }

  Stream<List<Map<String, dynamic>>> fetchGrammarPoints() {
    return _firebaseService.grammar_fetchGrammarPoints();
  }
}

class CacheDebouncer {
  Timer? _timer;
  void run(VoidCallback action, {Duration delay = const Duration(milliseconds: 500)}) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }
}