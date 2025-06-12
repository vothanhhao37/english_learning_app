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
  FlutterTts? _flutterTts;
  AudioPlayer? _audioPlayer;
  FlutterSoundRecorder? _recorder;
  final WhisperService _whisperService = WhisperService();

  ConversationPronunciationService() {
    // _initializeAudio(); // Khởi tạo âm thanh sẽ được gọi khi cần thiết trong UI
  }

  Future<void> initializeAudio() async {
    // Chỉ khởi tạo nếu chưa được khởi tạo
    if (_recorder == null) {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 100));
    }
    if (_flutterTts == null) {
       _flutterTts = FlutterTts();
       await _flutterTts!.setLanguage("en-US");
       await _flutterTts!.setPitch(1.0);
    }
    // AudioPlayer thường không cần open/initialize riêng biệt, chỉ cần dispose
    if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
    }
  }

  Future<List<ConversationLesson>> loadLessons(String topicId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('conversation')
          .doc(topicId)
          .collection('lessons')
          .get();

      List<ConversationLesson> lessons = snapshot.docs.map((doc) => ConversationLesson.fromMap(doc.id, doc.data())).toList();

      // --- Sắp xếp danh sách bài học theo type (sentence trước dialogue) --- 
      lessons.sort((a, b) {
        // Định nghĩa thứ tự ưu tiên: 'sentence' có ưu tiên cao hơn 'dialogue'
        int orderA = a.type == 'sentence' ? 0 : a.type == 'dialogue' ? 1 : 2; // Các type khác xếp sau
        int orderB = b.type == 'sentence' ? 0 : b.type == 'dialogue' ? 1 : 2;

        return orderA.compareTo(orderB);
      });
      // ----------------------------------------------------------------------

      return lessons;
    } catch (e) {
      print('Error loading lessons: $e');
      throw e; // Rethrow the error after logging
    }
  }

  Future<void> initializeNewTopicSummary(
      String uid, String topicId, String topicName, int totalLessons) async {
    try {
      final topicSummaryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation')
          .collection(topicId)
          .doc('summary');

      final topicSummarySnap = await topicSummaryRef.get();

      if (!topicSummarySnap.exists) {
        // Tạo document summary mới nếu chưa tồn tại
        await topicSummaryRef.set({
          'topicId': topicId,
          'topicName': topicName,
          'totalLessons': totalLessons,
          'completedLessons': 0,
          'bestScoreSum': 0,
          'averageScore': 0.0,
          'completionPercentage': 0.0,
          'isCompleted': false,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print('Initialized new conversation topic summary for $topicName ($topicId)');
      } else {
        // Cập nhật totalLessons nếu có thay đổi từ dữ liệu gốc
        final data = topicSummarySnap.data()!;
        if (data['totalLessons'] != totalLessons) {
          await topicSummaryRef.update({
            'totalLessons': totalLessons,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          print('Updated totalLessons for conversation topic summary $topicName ($topicId)');
        }
      }
    } catch (e) {
      print('Error initializing conversation topic summary data: $e');
    }
  }

  /// Cập nhật summary cho một chủ đề Conversation dựa trên các bài học đã hoàn thành
  Future<void> updateTopicSummary(String uid, String topicId, int totalLessons) async {
    try {
      // Đường dẫn đến subcollection lessonResults dưới document summary của chủ đề
      final lessonResultsCollectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress') // Subcollection
          .doc('conversation') // Document tổng quan
          .collection(topicId) // Subcollection cho từng topicId
          .doc('summary') // Document summary của chủ đề
          .collection('lessonResults'); // Subcollection lessonResults dưới summary

      // Lấy tất cả bài học đã làm của chủ đề này từ cấu trúc mới
      final lessonResultsSnap = await lessonResultsCollectionRef.get();

    int completedLessons = 0;
      int bestScoreSum = 0;
      int totalSubQuestionsWithResults = 0; // Tổng số câu/phần đã lưu kết quả trong topic

      for (var doc in lessonResultsSnap.docs) {
      final data = doc.data();
        String type = data['type'] ?? 'unknown';

        if (type == 'sentence') {
          final bestScore = (data['bestScore'] as num?)?.toInt() ?? 0;
          bestScoreSum += bestScore;
          totalSubQuestionsWithResults += 1; // Bài sentence chỉ có 1 câu
          // Đánh dấu hoàn thành nếu đạt điểm >= 50
          if (bestScore >= 50) {
            completedLessons++;
          }
        } else if (type == 'dialogue') {
        final bestScores = data['bestScores'] as Map<String, dynamic>? ?? {};
          int dialogueTotalScore = 0; // Tổng điểm cao nhất cho các câu trong dialogue này
          int dialogueCompletedCount = 0; // Số câu trong dialogue này đạt >= 50
          int dialogueQuestionCount = bestScores.length; // Số câu trong đoạn hội thoại đã lưu kết quả

          bestScores.values.forEach((scoreValue) {
            final score = (scoreValue as num?)?.toInt() ?? 0;
            dialogueTotalScore += score; // Cộng điểm cao nhất của từng câu trong dialogue
            if (score >= 50) {
              dialogueCompletedCount++;
            }
          });
          bestScoreSum += dialogueTotalScore; // Cộng tổng điểm cao nhất của đoạn dialogue vào tổng chung
          totalSubQuestionsWithResults += dialogueQuestionCount; // Cộng số câu đã lưu kết quả trong dialogue

          // Dialogue được coi là hoàn thành nếu tất cả các câu đã chấm điểm đều đạt điểm >= 50
          // Chúng ta đã kiểm tra điều kiện này khi lưu điểm, nên ở đây chỉ cần đếm bài có kết quả
          // Điều chỉnh: Đếm completedLessons dựa trên số bài có lessonResult document
          // completedLessons++; // Mỗi document trong lessonResults đại diện cho 1 bài hoàn thành (nếu điểm >= 50)

        } // Có thể thêm các loại bài học khác ở đây
      }

      // Đếm số bài học thực sự hoàn thành (có document trong lessonResults VÀ đạt điều kiện điểm)
       final actuallyCompletedLessonsSnap = await lessonResultsCollectionRef
           .where('isCompletedLesson', isEqualTo: true) // Sử dụng trường mới để đánh dấu bài hoàn thành
           .get();
       completedLessons = actuallyCompletedLessonsSnap.docs.length;

      // Tính toán các chỉ số summary chủ đề
      // Tính điểm trung bình trên TỔNG số câu/phần đã lưu kết quả
      double averageScore = totalSubQuestionsWithResults > 0 ? (bestScoreSum / (totalSubQuestionsWithResults * 100)) * 100 : 0.0;
      double completionPercentage = totalLessons > 0 ? (completedLessons / totalLessons) * 100 : 0.0;
      // bool isCompleted = totalLessons > 0 && completedLessons == totalLessons; // Bỏ trường này

      // Cập nhật document summary cho chủ đề
      final topicSummaryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
          .collection('learningProgress') // Subcollection
          .doc('conversation') // Document tổng quan
          .collection(topicId) // Subcollection cho từng topicId
          .doc('summary'); // Document summary cho chủ đề này

      await topicSummaryRef.set({
      'completedLessons': completedLessons,
        'bestScoreSum': bestScoreSum, // Tổng điểm cao nhất của TẤT CẢ các câu/phần đã lưu kết quả
        'averageScore': averageScore, // Trung bình điểm trên TỔNG số câu/phần đã lưu kết quả
      'completionPercentage': completionPercentage,
        // 'isCompleted': isCompleted, // Bỏ trường này
        'lastUpdated': FieldValue.serverTimestamp(),
        'totalSubQuestionsWithResults': totalSubQuestionsWithResults, // Lưu thêm tổng số câu/phần đã có kết quả để debug/kiểm tra
    }, SetOptions(merge: true));

      print('Updated conversation topic summary for topic: $topicId');

    } catch (e) {
      print('Error updating conversation topic summary: $e');
    }
  }

  /// Cập nhật summary tổng quan cho Conversation
  Future<void> updateOverallSummary(String uid) async {
    try {
      // Lấy tất cả các chủ đề Conversation từ root (để biết tổng số bài học)
    final allTopicsSnap = await FirebaseFirestore.instance
          .collection('conversation') // Collection gốc chứa định nghĩa các chủ đề
        .get();

    int totalTopics = allTopicsSnap.docs.length;
    int totalLessons = 0;
      Map<String, int> topicsLessonsCount = {};

      // Lấy tổng số bài học (theo định nghĩa gốc) cho từng chủ đề
    for (var topicDoc in allTopicsSnap.docs) {
      final topicId = topicDoc.id;
      final lessonsSnap = await FirebaseFirestore.instance
            .collection('conversation')
            .doc(topicId)
            .collection('lessons') // Subcollection lessons dưới document topic gốc
            .get();
        final lessonCount = lessonsSnap.docs.length;
        topicsLessonsCount[topicId] = lessonCount;
        totalLessons += lessonCount;
      }

      // Lấy document tổng quan conversation của user
      final overallDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress') // Subcollection
          .doc('conversation'); // Document tổng quan

      // Đọc danh sách các topicId mà người dùng đã tương tác từ trường 'topics' trong document tổng quan
       final overallDocSnap = await overallDocRef.get();
       final userTopicsIds = overallDocSnap.data()?['topics'] as List<dynamic>? ?? [];

       int totalLessonsCompletedOverall = 0;
       int totalBestScoreSumOverall = 0;
       int totalSubQuestionsWithResultsOverall = 0; // Tổng số câu/phần user đã làm trên toàn bộ Conversation
       List<String> userTopics = []; // Danh sách topicId thực tế có trong progress của user (đã lọc)

       // Duyệt qua từng topicId đã tương tác để lấy document summary của nó
       final futures = userTopicsIds.map((topicId) async {
         final topicIdStr = topicId.toString(); // Đảm bảo là String
         // Kiểm tra xem topicId này có tồn tại trong cấu trúc gốc không trước khi thêm vào userTopics
         if(topicsLessonsCount.containsKey(topicIdStr)) {
             userTopics.add(topicIdStr); // Chỉ thêm topicId nếu nó hợp lệ từ cấu trúc gốc

             // Đường dẫn đúng đến document summary của chủ đề dưới subcollection topicId
             final topicSummaryDoc = await overallDocRef.collection(topicIdStr).doc('summary').get();

             if(topicSummaryDoc.exists) {
               final data = topicSummaryDoc.data()!;
               totalLessonsCompletedOverall += (data['completedLessons'] as num?)?.toInt() ?? 0; // Tổng số bài hoàn thành
               totalBestScoreSumOverall += (data['bestScoreSum'] as num?)?.toInt() ?? 0; // Tổng điểm cao nhất (tổng của các câu/phần)
               totalSubQuestionsWithResultsOverall += (data['totalSubQuestionsWithResults'] as num?)?.toInt() ?? 0; // Tổng số câu/phần đã có kết quả
             }
         }
       }).toList();
      await Future.wait(futures);

      // Tính toán các chỉ số tổng quan toàn bộ Conversation
      // Tổng điểm có thể đạt được nếu hoàn thành tất cả bài học với 100 điểm trên TỔNG số câu/phần đã có kết quả
      int totalPossibleScoreOverall = totalSubQuestionsWithResultsOverall * 100; // Tổng số câu/phần user đã làm * 100

      // overallCompletionPercentage dựa trên TỔNG số bài học hoàn thành / TỔNG số bài học gốc
      double overallCompletionPercentage = totalLessons > 0 ? (totalLessonsCompletedOverall / totalLessons) * 100 : 0.0;

      // overallAverageScore dựa trên TỔNG điểm cao nhất / TỔNG số câu/phần đã có kết quả
      double overallAverageScore = totalPossibleScoreOverall > 0 ? (totalBestScoreSumOverall / totalPossibleScoreOverall) * 100 : 0.0;

      // Cập nhật document tổng quan 'conversation'
      await overallDocRef.set({
        // Giữ nguyên tổng số topic/lesson từ cấu trúc gốc để biết toàn bộ chương trình học
        'totalTopics': totalTopics, // Tổng số topic gốc
        'totalLessons': totalLessons, // Tổng số lesson gốc
        // Cập nhật các chỉ số dựa trên tiến trình của user
        'totalLessonsCompletedOverall': totalLessonsCompletedOverall, // Tổng số bài hoàn thành trên toàn bộ
        'totalBestScoreSumOverall': totalBestScoreSumOverall, // Tổng điểm cao nhất trên toàn bộ câu/phần đã làm
        'totalSubQuestionsWithResultsOverall': totalSubQuestionsWithResultsOverall, // Tổng số câu/phần đã làm
        'overallCompletionPercentage': overallCompletionPercentage,
        'overallAverageScore': overallAverageScore,
        'topics': userTopics, // Lưu danh sách các topicId mà người dùng đã tương tác (đã lọc)
        'topicsLessonsCount': topicsLessonsCount, // Giữ nguyên count từ gốc
        'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

      print('Updated overall conversation summary');

    } catch (e) {
      print('Error updating overall conversation summary: $e');
    }
  }

  /// Lưu điểm cho bài học dạng Sentence
  Future<void> saveSentenceScore(
      String topicId, String lessonId, String text, String spokenText, int score) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Kiểm tra điểm có đủ điều kiện lưu không (>= 50)
      if (score < 50) {
         print('Sentence score ([33m$score[0m) is below minimum threshold (50), not saving.');
         return; // Không lưu nếu điểm dưới 50
      }

      final batch = FirebaseFirestore.instance.batch();
      // Đường dẫn mới cho document bài học dưới lessonResults
      final lessonResultRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress') // Subcollection
          .doc('conversation') // Document tổng quan
          .collection(topicId) // Subcollection cho từng topicId
          .doc('summary') // Document summary của chủ đề
          .collection('lessonResults') // Subcollection lessonResults dưới summary
          .doc(lessonId); // Document cho bài học cụ thể

      // Đường dẫn mới cho chi tiết lần thử dưới lessonResults
      final attemptRef = lessonResultRef.collection('attempts').doc(); // attempts dưới document lessonId

      final lessonResultSnap = await lessonResultRef.get();
      final bool isNewHighScore = !lessonResultSnap.exists || (lessonResultSnap.data()?['bestScore'] ?? 0) < score;

      // Chỉ cập nhật bestScore và đánh dấu hoàn thành bài nếu là điểm mới cao hơn hoặc bài chưa có điểm
      if (isNewHighScore) {
           batch.set(lessonResultRef, {
        'topicId': topicId,
              'lessonId': lessonId,
        'type': 'sentence',
              'bestScore': score, // Lưu điểm cao nhất
              'attemptsCount': FieldValue.increment(1),
              'lastAttemptTime': FieldValue.serverTimestamp(),
              'isCompletedLesson': score >= 50, // Đánh dấu bài học hoàn thành nếu điểm >= 50
           }, SetOptions(merge: true));
      } else {
           // Nếu không phải high score mới, chỉ tăng attempt count và cập nhật thời gian
           batch.set(lessonResultRef, {
              'attemptsCount': FieldValue.increment(1),
              'lastAttemptTime': FieldValue.serverTimestamp(),
              'isCompletedLesson': lessonResultSnap.data()?['isCompletedLesson'] ?? false, // Giữ nguyên trạng thái hoàn thành
      }, SetOptions(merge: true));
      }

      batch.set(attemptRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'score': score,
        'spokenText': spokenText,
        'correctText': text,
      });

      await batch.commit();

      // Đảm bảo topicId được thêm vào summary.topics nếu chưa có
      final overallDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation');
      final overallDocSnap = await overallDocRef.get();
      final topics = List<String>.from(overallDocSnap.data()?['topics'] ?? []);
      if (!topics.contains(topicId)) {
        topics.add(topicId);
        await overallDocRef.set({
          ...overallDocSnap.data() ?? {},
          'topics': topics,
        }, SetOptions(merge: true));
      }

      // Sau khi lưu, cập nhật summary của chủ đề và tổng quan
      // Cần lấy lại totalLessons cho chủ đề để truyền vào updateTopicSummary (lấy từ cấu trúc gốc)
      final topicDoc = await FirebaseFirestore.instance
          .collection('conversation') // Collection gốc chứa định nghĩa chủ đề
          .doc(topicId)
          .get();
      // Lấy số lượng bài học từ subcollection 'lessons' dưới document topic gốc
      final lessonsSnapInRoot = await FirebaseFirestore.instance
          .collection('conversation')
          .doc(topicId)
          .collection('lessons')
          .get();
      final int totalLessonsInTopic = lessonsSnapInRoot.docs.length;

      // Chờ các cập nhật summary hoàn thành
      await Future.wait([
        updateTopicSummary(uid, topicId, totalLessonsInTopic),
        updateOverallSummary(uid),
      ]);

      print('Saved sentence score and updated summaries for lesson: $lessonId (Topic: $topicId)');

    } catch (e) {
      print('Error saving sentence score: $e');
    }
  }

  /// Lưu điểm cho bài học dạng Dialogue
  Future<void> saveDialogueScore(
      String topicId, String lessonId, List<Map<String, String>> dialogueTexts, List<String> spokenTexts, Map<int, int> scores) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. Kiểm tra xem người dùng đã thử tất cả các câu trong dialogue chưa
      if (scores.length != dialogueTexts.length) {
         print('Dialogue not fully attempted. Expected [33m${dialogueTexts.length}[0m scores, got ${scores.length}. Not saving.');
         return; // Không lưu nếu chưa thử hết các câu
      }

      // 2. Kiểm tra xem TẤT CẢ điểm số có >= 50 không
      bool allScoresMeetThreshold = true;
      scores.values.forEach((score) {
        if (score < 50) {
          allScoresMeetThreshold = false;
        }
      });

      if (!allScoresMeetThreshold) {
         print('Some dialogue scores are below minimum threshold (50), not saving.');
         return; // Không lưu nếu có bất kỳ điểm nào dưới 50
      }

      // Nếu đến đây, nghĩa là người dùng đã thử hết các câu và tất cả điểm đều >= 50
      // Tiến hành lưu kết quả cho bài dialogue này
      final batch = FirebaseFirestore.instance.batch();
      // Đường dẫn mới cho document bài học dưới lessonResults
      final lessonResultRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress') // Subcollection
          .doc('conversation') // Document tổng quan
          .collection(topicId) // Subcollection cho từng topicId
          .doc('summary') // Document summary của chủ đề
          .collection('lessonResults') // Subcollection lessonResults dưới summary
          .doc(lessonId); // Document cho bài học cụ thể

      // Đường dẫn mới cho chi tiết lần thử dưới lessonResults
      final attemptRef = lessonResultRef.collection('attempts').doc(); // attempts dưới document lessonId

      final lessonResultSnap = await lessonResultRef.get();
      // Kiểm tra nếu là lần đầu lưu hoặc có điểm cao hơn cho bất kỳ câu nào
      // Để đơn giản, chỉ cần kiểm tra nếu document chưa tồn tại (lần thử đầu tiên đạt yêu cầu)
      // hoặc nếu tổng điểm cao nhất mới lớn hơn tổng điểm cao nhất cũ (cần tính tổng điểm cao nhất)

      final currentBestScores = lessonResultSnap.exists ? (lessonResultSnap.data()?['bestScores'] as Map<String, dynamic>?) ?? {} : {};
      final newBestScores = Map<String, dynamic>.from(currentBestScores);
      bool isNewHighScoreOverall = false;
      int currentTotalBestScore = 0;
      currentBestScores.values.forEach((scoreValue) => currentTotalBestScore += (scoreValue as num?)?.toInt() ?? 0);

      int newTotalScore = 0;
      scores.forEach((index, score) {
        final indexStr = index.toString();
        if (!newBestScores.containsKey(indexStr) || newBestScores[indexStr] < score) {
          newBestScores[indexStr] = score; // Cập nhật điểm cao nhất cho câu con
          isNewHighScoreOverall = true; // Đánh dấu là có high score mới ở ít nhất 1 câu
        }
        // Tính tổng điểm cao nhất mới, đảm bảo chuyển đổi từ num sang int
        newTotalScore += (newBestScores[indexStr] as num?)?.toInt() ?? 0;
      });

      // Cập nhật document lessonResult
      if (!lessonResultSnap.exists || isNewHighScoreOverall) {
           batch.set(lessonResultRef, {
        'topicId': topicId,
              'lessonId': lessonId,
        'type': 'dialogue',
              'bestScores': newBestScores, // Lưu map điểm cao nhất cho từng câu
              'attemptsCount': FieldValue.increment(1), // Tăng attempt count chỉ khi lưu thành công
              'lastAttemptTime': FieldValue.serverTimestamp(),
              'isCompletedLesson': true, // Bài dialogue hoàn thành nếu tất cả điểm >= 50
           }, SetOptions(merge: true));
      } else {
           // Nếu không có high score mới tổng thể, chỉ tăng attempt count và cập nhật thời gian
            batch.set(lessonResultRef, {
              'attemptsCount': FieldValue.increment(1),
              'lastAttemptTime': FieldValue.serverTimestamp(),
               'isCompletedLesson': lessonResultSnap.data()?['isCompletedLesson'] as bool? ?? false, // Giữ nguyên trạng thái, đảm bảo đúng kiểu bool
      }, SetOptions(merge: true));
      }

      // Lưu chi tiết lần thử
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
        'scores': scoresMap, // Lưu điểm của lần thử này
        'spokenTexts': spokenMap,
        'correctTexts': correctMap,
      });

      await batch.commit();

      // Đảm bảo topicId được thêm vào summary.topics nếu chưa có
      final overallDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress')
          .doc('conversation');
      final overallDocSnap = await overallDocRef.get();
      final topics = List<String>.from(overallDocSnap.data()?['topics'] ?? []);
      if (!topics.contains(topicId)) {
        topics.add(topicId);
        await overallDocRef.set({
          ...overallDocSnap.data() ?? {},
          'topics': topics,
        }, SetOptions(merge: true));
      }

       // Sau khi lưu, cập nhật summary của chủ đề và tổng quan
      // Cần lấy lại totalLessons cho chủ đề để truyền vào updateTopicSummary (lấy từ cấu trúc gốc)
       final topicDoc = await FirebaseFirestore.instance
          .collection('conversation') // Collection gốc chứa định nghĩa chủ đề
          .doc(topicId)
          .get();
       // Lấy số lượng bài học từ subcollection 'lessons' dưới document topic gốc
       final lessonsSnapInRoot = await FirebaseFirestore.instance
           .collection('conversation')
           .doc(topicId)
           .collection('lessons')
           .get();
       final int totalLessonsInTopic = lessonsSnapInRoot.docs.length;

      // Chờ các cập nhật summary hoàn thành
      await Future.wait([
         updateTopicSummary(uid, topicId, totalLessonsInTopic),
         updateOverallSummary(uid),
      ]);

      print('Saved dialogue score and updated summaries for lesson: $lessonId (Topic: $topicId)');

    } catch (e) {
      print('Error saving dialogue score: $e');
    }
  }

  Future<void> speak(String text) async {
    await _flutterTts!.speak(text);
  }

  Future<String> startRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/record_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder!.startRecorder(toFile: path, codec: Codec.aacADTS);
    return path;
  }

  Future<void> stopRecording() async {
    await _recorder!.stopRecorder();
  }

  Future<String> transcribeAudio(String path) async {
    return await _whisperService.transcribeAudio(path);
  }

  Future<void> playAudio(String path) async {
    if (await File(path).exists()) {
      await _audioPlayer!.play(DeviceFileSource(path));
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
    // Giải phóng tài nguyên chỉ khi chúng đã được khởi tạo
    _recorder?.closeRecorder();
    _audioPlayer?.dispose();
    _flutterTts?.stop();
  }

  // Hàm đọc tiến trình Conversation cho ProfileService
  Future<Map<String, dynamic>> getConversationProgress(String uid) async {
     try {
      final startTime = DateTime.now();

      // Lấy document tổng quan conversation
      final overallDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learningProgress') // Subcollection
          .doc('conversation'); // Document tổng quan

      final overallSummaryDoc = await overallDocRef.get();
      final overallSummary = overallSummaryDoc.data() ?? {};

       // Lấy danh sách các topicId mà người dùng đã tương tác từ trường 'topics' trong document tổng quan
       final userTopicsIds = overallSummary['topics'] as List<dynamic>? ?? [];

       Map<String, dynamic> topicSummaries = {};

       // Duyệt qua từng topicId và lấy document summary của nó
       final futures = userTopicsIds.map((topicId) async {
         final topicIdStr = topicId.toString(); // Đảm bảo là String

         // Truy cập document summary dưới subcollection topicId
         // Đường dẫn: users/{uid}/learningProgress/conversation/{topicId}/summary
         final topicSummaryDoc = await overallDocRef.collection(topicIdStr).doc('summary').get();

         if(topicSummaryDoc.exists) {
           final data = topicSummaryDoc.data()!;
           // Chuyển đổi các giá trị num từ Firestore sang int
           topicSummaries[topicIdStr] = {
             'completedLessons': (data['completedLessons'] as num?)?.toInt() ?? 0,
             'bestScoreSum': (data['bestScoreSum'] as num?)?.toInt() ?? 0,
             'totalSubQuestionsWithResults': (data['totalSubQuestionsWithResults'] as num?)?.toInt() ?? 0,
             'averageScore': (data['averageScore'] as num?)?.toDouble() ?? 0.0, // averageScore là double
             'completionPercentage': (data['completionPercentage'] as num?)?.toDouble() ?? 0.0, // completionPercentage là double
             'lastUpdated': data['lastUpdated'], // Giữ nguyên timestamp
           };
         }
      }).toList();
      await Future.wait(futures);


      final endTime = DateTime.now();
      final elapsed = endTime.difference(startTime).inMilliseconds;

      return {
        'summary': overallSummary,
        'topicSummaries': topicSummaries, // Trả về map các summary theo topicId
      };

    } catch (e) {
       print('Error getting conversation progress: $e');
       return {}; // Trả về rỗng nếu có lỗi
    }
  }
}