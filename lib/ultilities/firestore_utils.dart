import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/profile_service.dart';

class FirestoreUtils {

  // Hàm lưu điểm cho một câu hỏi trong IPA
  static Future<void> saveIpaScore({
    required String ipaId,
    required String lessonId,
    required bool isCorrect,
    required String lessonType,
    required String userAnswer,
    int scorePerQuestion = 10, // Điểm mặc định cho mỗi câu đúng
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Vui lòng đăng nhập để lưu điểm');
      return;
    }

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final quizResultsRef = userDocRef
        .collection('learningProgress')
        .doc('ipa')
        .collection(ipaId)
        .doc('summary')
        .collection('quizResults')
        .doc(lessonId);

    try {
      // 1. Lưu một attempt mới vào collection con 'attempts'
      final attemptsCol = quizResultsRef.collection('attempts');
      await attemptsCol.add({
        'isCorrect': isCorrect,
        'score': isCorrect ? scorePerQuestion : 0,
        'timestamp': FieldValue.serverTimestamp(),
        'userAnswer': userAnswer,
      });

      // 2. Tính toán bestResult: true nếu có ít nhất một attempt đúng
      final attemptsSnapshot = await attemptsCol.where('isCorrect', isEqualTo: true).limit(1).get();
      final bool bestResult = attemptsSnapshot.docs.isNotEmpty;

      // 3. Cập nhật các trường tổng hợp ở document cha quizResults/{lessonId}
      await quizResultsRef.set({
        'type': lessonType,
        'bestResult': bestResult,
        'updatedAt': FieldValue.serverTimestamp(),
        'attemptCount': FieldValue.increment(1),
        'lastAttemptTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Cập nhật summary cho ipaId
      await updateIpaSummary(userDocRef, ipaId);

      // 5. Sau khi cập nhật Firestore, lấy lại tiến trình IPA mới nhất và lưu vào cache
      try {
        await ProfileService().getPronunciationProgress(forceRefresh: true);
      } catch (e) {
        print('Lỗi khi cập nhật cache IPA progress: $e');
      }

      print('Đã lưu kết quả bài tập IPA (attempt) cho lesson: $lessonId, đúng: $isCorrect, bestResult: $bestResult');
    } catch (e) {
      print('Lỗi khi lưu điểm IPA: $e');
    }
  }

  // Hàm cập nhật tổng quan tiến trình (cho IPA)
  static Future<void> updateIpaSummary(DocumentReference userDocRef, String ipaId) async {
    try {
      // Lấy tổng số bài tập từ collection lessons
      final ipaLessonsSnapshot = await FirebaseFirestore.instance
          .collection('ipa_pronunciation')
          .doc(ipaId)
          .collection('lessons')
          .get();

      final int totalQuestions = ipaLessonsSnapshot.docs.length;

      // Lấy kết quả các bài tập đã làm
      final quizResultsSnapshot = await userDocRef
          .collection('learningProgress')
          .doc('ipa')
          .collection(ipaId)
          .doc('summary')
          .collection('quizResults')
          .get();

      final int completedQuestions = quizResultsSnapshot.docs.length;
      final int correctQuestions = quizResultsSnapshot.docs
          .where((doc) => doc['bestResult'] == true)
          .length;

      // Tính toán các chỉ số
      final double accuracy = completedQuestions > 0
          ? correctQuestions / completedQuestions
          : 0.0;

      final double completionRate = totalQuestions > 0
          ? completedQuestions / totalQuestions
          : 0.0;

      // Cập nhật summary cho từng IPA
      await userDocRef
          .collection('learningProgress')
          .doc('ipa')
          .collection(ipaId)
          .doc('summary')
          .set({
        'ipaId': ipaId,
        'totalQuestions': totalQuestions,
        'completedQuestions': completedQuestions,
        'correctQuestions': correctQuestions,
        'accuracy': accuracy,
        'completionRate': completionRate,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Cập nhật tổng quan trong document ipa
      await updateOverallIpaProgress(userDocRef,ipaId);

      print('Đã cập nhật summary cho IPA: $ipaId');
    } catch (e) {
      print('Lỗi khi cập nhật IPA summary: $e');
    }
  }

  // Hàm cập nhật tổng quan tất cả các IPA
  static Future<void> updateOverallIpaProgress(DocumentReference userDocRef, String currentIpaId) async {
    try {
      // Lấy tất cả IPA có sẵn
      final allIpasSnapshot = await FirebaseFirestore.instance
          .collection('ipa_pronunciation')
          .get();

      // Tạo Map lưu tổng số câu hỏi cho từng IPA
      Map<String, int> allIpasQuestions = {};
      int totalTopics = 0;
      int totalQuestions = 0;

      // Tính tổng số câu hỏi cho từng IPA
      for (var ipaDoc in allIpasSnapshot.docs) {
        final String ipaId = ipaDoc.id;

        final lessonsSnapshot = await FirebaseFirestore.instance
            .collection('ipa_pronunciation')
            .doc(ipaId)
            .collection('lessons')
            .get();

        final int ipaQuestions = lessonsSnapshot.docs.length;
        allIpasQuestions[ipaId] = ipaQuestions;

        totalQuestions += ipaQuestions;
        totalTopics++;
      }

      // Lấy danh sách IPA từ user progress
      final ipaSummaryDoc = await userDocRef
          .collection('learningProgress')
          .doc('ipa')
          .get();

      List<String> userIpas = [];
      if (ipaSummaryDoc.exists) {
        userIpas = List<String>.from(ipaSummaryDoc.data()?['summary']?['topics'] ?? []);
      }

      // Thêm IPA hiện tại vào danh sách nếu chưa có
      if (!userIpas.contains(currentIpaId)) {
        userIpas.add(currentIpaId);
      }

      // Tính tổng số câu đã làm và đúng
      int totalCorrectQuestions = 0;
      int totalCompletedQuestions = 0;

      for (String ipaId in userIpas) {
        final ipaSummaryDoc = await userDocRef
            .collection('learningProgress')
            .doc('ipa')
            .collection(ipaId)
            .doc('summary')
            .get();

        if (ipaSummaryDoc.exists) {
          totalCorrectQuestions += (ipaSummaryDoc.data()?['correctQuestions'] as int? ?? 0);
          totalCompletedQuestions += (ipaSummaryDoc.data()?['completedQuestions'] as int? ?? 0);
        }
      }

      // Tính độ chính xác tổng thể
      double overallAccuracy = totalCompletedQuestions > 0
          ? totalCorrectQuestions / totalCompletedQuestions
          : 0.0;

      // Cập nhật tổng quan
      await userDocRef
          .collection('learningProgress')
          .doc('ipa')
          .set({
        'summary': {
          'totalTopics': totalTopics,
          'totalQuestions': totalQuestions,
          'totalCorrectQuestions': totalCorrectQuestions,
          'totalCompletedQuestions': totalCompletedQuestions,
          'overallAccuracy': overallAccuracy,
          'topics': userIpas,
          'lastUpdated': FieldValue.serverTimestamp(),
          'topicsQuestions': allIpasQuestions,
        }
      }, SetOptions(merge: true));

      print('Đã cập nhật tổng quan IPA');
    } catch (e) {
      print('Lỗi khi cập nhật tổng quan IPA: $e');
    }
  }
}