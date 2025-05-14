import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreUtils {
  // Hàm lưu điểm cho một câu hỏi trong grammar
  static Future<void> saveGrammarScore({
    required String topicId,
    required String exerciseId,
    required bool isCorrect,
    required String exerciseType,
    int scorePerQuestion = 10, // Điểm mặc định cho mỗi câu đúng
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Vui lòng đăng nhập để lưu điểm');
      return;
    }

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final grammarRef = userDocRef.collection('learningProgress').doc('grammar').collection('grammar').doc(topicId);

    try {
      // Kiểm tra dữ liệu hiện tại của câu hỏi
      final docSnapshot = await grammarRef.get();
      Map<String, dynamic> existingQuestions = docSnapshot.exists && docSnapshot.data() != null
          ? Map<String, dynamic>.from(docSnapshot.data()!['questions'] ?? {})
          : {};

      // Kiểm tra trạng thái hiện tại của câu hỏi
      bool currentStatus = existingQuestions.containsKey(exerciseId)
          ? existingQuestions[exerciseId]['status'] ?? false
          : false;
      int currentAttempts = existingQuestions.containsKey(exerciseId)
          ? existingQuestions[exerciseId]['attempts'] ?? 0
          : 0;

      // Chỉ cập nhật nếu chưa đúng trước đó và người dùng làm đúng
      if (!currentStatus && isCorrect) {
        existingQuestions[exerciseId] = {
          'status': true,
          'type': exerciseType,
          'score': scorePerQuestion,
          'attempts': currentAttempts + 1,
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await grammarRef.set({
          'topic_id': topicId,
          'lastUpdated': FieldValue.serverTimestamp(),
          'questions': existingQuestions,
        }, SetOptions(merge: true));

        // Cập nhật summary
        await updateSummary(userDocRef, topicId);
        print('Điểm đã được cập nhật: $exerciseId');
      } else if (!existingQuestions.containsKey(exerciseId)) {
        // Nếu câu hỏi chưa tồn tại, tạo mới
        existingQuestions[exerciseId] = {
          'status': isCorrect,
          'type': exerciseType,
          'score': isCorrect ? scorePerQuestion : 0,
          'attempts': 1,
          'completedAt': isCorrect ? FieldValue.serverTimestamp() : null,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await grammarRef.set({
          'topic_id': topicId,
          'lastUpdated': FieldValue.serverTimestamp(),
          'questions': existingQuestions,
        }, SetOptions(merge: true));

        // Cập nhật summary
        await updateSummary(userDocRef, topicId);
        print('Điểm đã được tạo mới: $exerciseId');
      } else {
        // Nếu câu hỏi đã làm đúng trước đó, không cập nhật status
        existingQuestions[exerciseId] = {
          ...existingQuestions[exerciseId],
          'attempts': currentAttempts + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await grammarRef.set({
          'topic_id': topicId,
          'lastUpdated': FieldValue.serverTimestamp(),
          'questions': existingQuestions,
        }, SetOptions(merge: true));

        print('Không cần cập nhật status, chỉ tăng attempts: $exerciseId');
      }
    } catch (e) {
      print('Lỗi khi lưu điểm: $e');
    }
  }

  // Hàm lưu điểm cho một câu hỏi trong IPA
  static Future<void> saveIpaScore({
    required String ipaId,
    required String lessonId,
    required bool isCorrect,
    required String lessonType,
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
      // Lưu kết quả bài tập
      await quizResultsRef.set({
        'type': lessonType,
        'status': isCorrect ? 'correct' : 'wrong',
        'updatedAt': FieldValue.serverTimestamp(),
        'attemptCount': FieldValue.increment(1),
        'lastAttemptTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Cập nhật summary cho ipaId
      await updateIpaSummary(userDocRef, ipaId);

      print('Đã lưu kết quả bài tập IPA: $lessonId, đúng: $isCorrect');
    } catch (e) {
      print('Lỗi khi lưu điểm IPA: $e');
    }
  }

  // Hàm cập nhật tổng quan tiến trình (cho grammar)
  static Future<void> updateSummary(DocumentReference userDocRef, String topicId) async {
    final grammarRef = userDocRef.collection('learningProgress').doc('grammar').collection('grammar').doc(topicId);
    final summaryRef = userDocRef.collection('learningProgress').doc('grammarSummary').collection('grammarSummary').doc(topicId);

    try {
      // Lấy dữ liệu chi tiết
      final docSnapshot = await grammarRef.get();
      if (!docSnapshot.exists) return;

      Map<String, dynamic> questions = docSnapshot.data()!['questions'] ?? {};
      int completedQuestions = questions.length; // Số câu đã làm (đúng/sai)

      // Lấy tổng số câu hỏi từ Firestore
      final exercisesSnapshot = await FirebaseFirestore.instance
          .collection('grammar')
          .doc(topicId)
          .collection('exercises')
          .get();
      int totalQuestions = exercisesSnapshot.docs.length;

      int totalCorrect = questions.values.where((q) => q['status'] == true).length;
      int totalScore = questions.values.fold<int>(0, (sum, q) => sum + ((q['score'] as num?)?.toInt() ?? 0));
      double progress = totalQuestions > 0 ? totalCorrect / totalQuestions : 0;

      // Cập nhật summary
      await summaryRef.set({
        'topic_id': topicId,
        'totalQuestions': totalQuestions,
        'completedQuestions': completedQuestions,
        'totalCorrect': totalCorrect,
        'totalScore': totalScore,
        'progress': progress,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Summary đã được cập nhật cho $topicId');
    } catch (e) {
      print('Lỗi khi cập nhật summary: $e');
    }
  }

  // Hàm cập nhật tổng quan tất cả các IPA
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
          .where((doc) => doc['status'] == 'correct')
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
}