import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

import '../models/conversation_pronunciation_model.dart';
import '../../services/whisper_api_service.dart';

class ConversationPronunciationService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final WhisperService _whisperService = WhisperService();

  ConversationPronunciationService() {
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
  }

  Future<List<ConversationLesson>> loadLessons(String topicId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pronunciation_topics')
          .doc(topicId)
          .collection('lessons')
          .get();

      return snapshot.docs.map((doc) => ConversationLesson.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      print('Error loading lessons: $e');
      throw e;
    }
  }

  Future<void> initializeTopicData(String uid, String topicId, String topicName, int totalLessons) async {
    try {
      final topicRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation')
          .collection('topics')
          .doc(topicId);

      final topicSnap = await topicRef.get();

      if (!topicSnap.exists) {
        await topicRef.set({
          'topicName': topicName,
          'totalLessons': totalLessons,
          'completedLessons': 0,
          'averageScore': 0,
          'highestScore': 0,
          'lastAttempt': FieldValue.serverTimestamp(),
          'isCompleted': false,
          'completionPercentage': 0,
        });
      } else {
        final data = topicSnap.data()!;
        if (data['totalLessons'] != totalLessons) {
          await topicRef.update({
            'totalLessons': totalLessons,
            'lastAttempt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error initializing topic data: $e');
    }
  }

  Future<void> updateOverview(String uid, String topicId, String topicName) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation')
          .set({
        'lastActivity': FieldValue.serverTimestamp(),
        'lastTopicId': topicId,
        'lastTopicName': topicName,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating overview: $e');
    }
  }

  Future<void> updateTopicSummary(String uid, String topicId) async {
    final lessonsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('conversation')
        .collection('lessons')
        .where('topicId', isEqualTo: topicId)
        .get();

    int totalLessons = lessonsSnap.docs.length;
    int completedLessons = 0;
    int highestScore = 0;
    int totalScore = 0;

    for (var doc in lessonsSnap.docs) {
      final data = doc.data();
      if (data['completed'] == true) completedLessons++;
      if (data['type'] == 'sentence' || data['type'] == 'single_sentence') {
        highestScore += (data['bestScore'] is int)
            ? data['bestScore'] as int
            : (data['bestScore'] is num)
            ? (data['bestScore'] as num).toInt()
            : int.tryParse(data['bestScore']?.toString() ?? '0') ?? 0;
        totalScore += 100;
      } else if (data['type'] == 'dialogue') {
        final bestScores = data['bestScores'] as Map<String, dynamic>? ?? {};
        for (var score in bestScores.values) {
          highestScore += score is int ? score : score is num ? score.toInt() : int.tryParse(score.toString()) ?? 0;
          totalScore += 100;
        }
      }
    }

    double averageScore = totalLessons > 0 ? highestScore / totalLessons : 0;
    double completionPercentage = totalLessons > 0 ? (completedLessons / totalLessons) * 100 : 0;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('conversation')
        .collection('topics')
        .doc(topicId)
        .set({
      'completedLessons': completedLessons,
      'highestScore': highestScore,
      'averageScore': averageScore,
      'completionPercentage': completionPercentage,
      'isCompleted': completedLessons == totalLessons,
      'lastAttempt': FieldValue.serverTimestamp(),
      'totalLessons': totalLessons,
      'totalScore': totalScore,
    }, SetOptions(merge: true));
  }

  Future<void> updateOverallSummary(String uid) async {
    final allTopicsSnap = await FirebaseFirestore.instance
        .collection('pronunciation_topics')
        .get();

    int totalTopics = allTopicsSnap.docs.length;
    int totalLessons = 0;
    int totalBestScore = 0;
    int totalPossibleScore = 0;

    for (var topicDoc in allTopicsSnap.docs) {
      final topicId = topicDoc.id;
      final lessonsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation')
          .collection('lessons')
          .where('topicId', isEqualTo: topicId)
          .get();
      final topicLessonsSnap = await FirebaseFirestore.instance
          .collection('pronunciation_topics')
          .doc(topicId)
          .collection('lessons')
          .get();
      totalLessons += topicLessonsSnap.docs.length;
      totalPossibleScore += topicLessonsSnap.docs.length * 100;
      for (var doc in lessonsSnap.docs) {
        final data = doc.data();
        if (data['type'] == 'sentence' || data['type'] == 'single_sentence') {
          totalBestScore += (data['bestScore'] is int)
              ? data['bestScore'] as int
              : (data['bestScore'] is num)
              ? (data['bestScore'] as num).toInt()
              : int.tryParse(data['bestScore']?.toString() ?? '0') ?? 0;
        } else if (data['type'] == 'dialogue') {
          final bestScores = data['bestScores'] as Map<String, dynamic>? ?? {};
          for (var score in bestScores.values) {
            totalBestScore += score is int ? score : score is num ? score.toInt() : int.tryParse(score.toString()) ?? 0;
          }
        }
      }
    }

    double averageBestScore = totalLessons > 0 ? totalBestScore / totalLessons : 0;
    double overallCompletion = totalPossibleScore > 0 ? totalBestScore / totalPossibleScore : 0.0;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('conversation')
        .set({
      'summary': {
        'totalTopics': totalTopics,
        'totalLessons': totalLessons,
        'totalBestScore': totalBestScore,
        'averageBestScore': averageBestScore,
        'overallCompletion': overallCompletion,
        'lastUpdated': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> saveSentenceScore(String topicId, String lessonId, String text, String spokenText, int score) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final lessonRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation')
          .collection('lessons')
          .doc(lessonId);

      final attemptRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation')
          .collection('attempts')
          .doc(lessonId)
          .collection('attempt_details')
          .doc();

      final lessonSnap = await lessonRef.get();
      final bool isNewHighScore = !lessonSnap.exists || (lessonSnap.data()?['bestScore'] ?? 0) < score;

      batch.set(lessonRef, {
        'topicId': topicId,
        'type': 'sentence',
        'bestScore': isNewHighScore ? score : (lessonSnap.data()?['bestScore'] ?? 0),
        'attempts': FieldValue.increment(1),
        'lastAttempt': FieldValue.serverTimestamp(),
        'completed': score >= 50,
      }, SetOptions(merge: true));

      batch.set(attemptRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'score': score,
        'spokenText': spokenText,
        'correctText': text,
      });

      await batch.commit();
      await updateTopicSummary(uid, topicId);
      await updateOverallSummary(uid);
    } catch (e) {
      print('Error saving sentence score: $e');
    }
  }

  Future<void> saveDialogueScore(String topicId, String lessonId, List<Map<String, String>> dialogueTexts, List<String> spokenTexts, Map<int, int> scores) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final lessonRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation')
          .collection('lessons')
          .doc(lessonId);

      final attemptRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation')
          .collection('attempts')
          .doc(lessonId)
          .collection('attempt_details')
          .doc();

      final lessonSnap = await lessonRef.get();
      final currentBestScores = lessonSnap.exists ? (lessonSnap.data()?['bestScores'] as Map<String, dynamic>?) ?? {} : {};

      final newBestScores = Map<String, dynamic>.from(currentBestScores);
      scores.forEach((index, score) {
        final indexStr = index.toString();
        if (!newBestScores.containsKey(indexStr) || newBestScores[indexStr] < score) {
          newBestScores[indexStr] = score;
        }
      });

      bool isCompleted = true;
      for (int i = 0; i < dialogueTexts.length; i++) {
        final indexStr = i.toString();
        if (!newBestScores.containsKey(indexStr) || newBestScores[indexStr] < 50) {
          isCompleted = false;
          break;
        }
      }

      batch.set(lessonRef, {
        'topicId': topicId,
        'type': 'dialogue',
        'bestScores': newBestScores,
        'attempts': FieldValue.increment(1),
        'lastAttempt': FieldValue.serverTimestamp(),
        'completed': isCompleted,
      }, SetOptions(merge: true));

      final Map<String, dynamic> spokenMap = {};
      final Map<String, dynamic> correctMap = {};
      final Map<String, dynamic> scoresMap = {};
      for (int i = 0; i < dialogueTexts.length; i++) {
        spokenMap[i.toString()] = spokenTexts[i];
        correctMap[i.toString()] = dialogueTexts[i]['answer'] ?? '';
        if (scores.containsKey(i)) {
          scoresMap[i.toString()] = scores[i];
        }
      }

      batch.set(attemptRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'scores': scoresMap,
        'spokenTexts': spokenMap,
        'correctTexts': correctMap,
      });

      await batch.commit();
      await updateTopicSummary(uid, topicId);
      await updateOverallSummary(uid);
    } catch (e) {
      print('Error saving dialogue score: $e');
    }
  }

  Future<void> updateTopic(String uid, String topicId, int totalLessons, int completedLessons) async {
    try {
      final completionPercentage = totalLessons == 0 ? 0 : (completedLessons / totalLessons) * 100;
      final isCompleted = completedLessons == totalLessons && totalLessons > 0;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation')
          .collection('topics')
          .doc(topicId)
          .update({
        'completedLessons': completedLessons,
        'isCompleted': isCompleted,
        'completionPercentage': completionPercentage,
        'lastAttempt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating topic: $e');
    }
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<String> startRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/record_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
    return path;
  }

  Future<void> stopRecording() async {
    await _recorder.stopRecorder();
  }

  Future<String> transcribeAudio(String path) async {
    return await _whisperService.transcribeAudio(path);
  }

  Future<void> playAudio(String path) async {
    if (await File(path).exists()) {
      await _audioPlayer.play(DeviceFileSource(path));
    }
  }

  List<String> evaluatePronunciation(String correctText, String spokenText) {
    final correctWords = RegExp(r'\b\w+\b')
        .allMatches(correctText.toLowerCase())
        .map((e) => e.group(0)!)
        .toList();
    final userWords = RegExp(r'\b\w+\b')
        .allMatches(spokenText.toLowerCase())
        .map((e) => e.group(0)!)
        .toList();

    List<String> resultWords = [];
    for (int i = 0; i < correctWords.length; i++) {
      if (i < userWords.length && userWords[i] == correctWords[i]) {
        resultWords.add('✔${correctWords[i]}');
      } else {
        resultWords.add('✘${correctWords[i]}');
      }
    }
    return resultWords;
  }

  int calculateScore(String correctText, String spokenText) {
    final correctWords = RegExp(r'\b\w+\b')
        .allMatches(correctText.toLowerCase())
        .map((e) => e.group(0)!)
        .toList();
    final userWords = RegExp(r'\b\w+\b')
        .allMatches(spokenText.toLowerCase())
        .map((e) => e.group(0)!)
        .toList();

    int match = 0;
    for (int i = 0; i < correctWords.length; i++) {
      if (i < userWords.length && userWords[i] == correctWords[i]) {
        match++;
      }
    }

    final accuracy = correctWords.isEmpty ? 0.0 : match / correctWords.length;
    return (accuracy * 100).round();
  }

  void dispose() {
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    _flutterTts.stop();
  }
}