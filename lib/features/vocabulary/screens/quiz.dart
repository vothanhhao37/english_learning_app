import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/vocabulary_service.dart';
import '../../common/congrationlation_popup.dart';
import '../excercises/listening_choice.dart';
import '../excercises/multiple_choice.dart';
import '../excercises/reorder.dart';
import '../excercises/typing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class VocabularyQuizScreen extends StatefulWidget {
  final String topicId;
  final String topicTitle;

  const VocabularyQuizScreen({super.key, required this.topicId, required this.topicTitle});

  @override
  State<VocabularyQuizScreen> createState() => _VocabularyQuizScreenState();
}

class _VocabularyQuizScreenState extends State<VocabularyQuizScreen> {
  List<Map<String, dynamic>> quizItems = [];
  bool loading = true;
  int current = 0;
  bool quizCompleted = false;
  int totalQuestions = 0;
  int completedQuestions = 0;
  int correctQuestions = 0;
  final VocabularyService _service = VocabularyService();

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    try {
      quizItems = await _service.loadQuiz(widget.topicId);
      totalQuestions = quizItems.length;
      setState(() {
        loading = false;
        quizCompleted = false;
      });

      if (quizItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có bài tập nào khả dụng trong chủ đề này')),
        );
        Navigator.pop(context);
      }

      await _updateProgressFromFirestore();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải bài tập: $e')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _updateProgressFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _service.updateTopicProgress(widget.topicId, widget.topicTitle);
    await _service.updateOverallProgress(uid);

    // Đọc lại summary để cập nhật UI
    final summaryDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learningProgress')
        .doc('vocabulary')
        .collection(widget.topicId)
        .doc('summary')
        .get();
    if (summaryDoc.exists) {
      final data = summaryDoc.data()!;
      setState(() {
        completedQuestions = data['completedQuestions'] ?? 0;
        correctQuestions = data['correctQuestions'] ?? 0;
        totalQuestions = data['totalQuestions'] ?? 0;
      });
    }
  }

  void _handleResult({
    required String wordId,
    required String quizKey,
    required String type,
    required bool isCorrect,
  }) async {
    quizItems[current]['status'] = isCorrect ? 'correct' : 'wrong';
    await _service.saveQuizResult(
      topicId: widget.topicId,
      wordId: wordId,
      quizKey: quizKey,
      type: type,
      status: isCorrect ? 'correct' : 'wrong',
    );
    setState(() {
      if (isCorrect) correctQuestions++;
      completedQuestions++;
    });
    _markQuizCompleted();
  }

  // Khi hoàn thành quiz hoặc rời khỏi quiz, tổng hợp điểm
  Future<void> _finalizeProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _service.updateTopicProgress(widget.topicId, widget.topicTitle);
    await _service.updateOverallProgress(uid);
    await _updateProgressFromFirestore();
  }

  void _next() {
    if (current < quizItems.length - 1) {
      setState(() {
        current++;
        quizCompleted = false;
      });
    } else {
      _finalizeProgress();
      LessonCompletionPopup.show(
        context,
        lessonTitle: widget.topicTitle,
        correctAnswers: correctQuestions,
        totalQuestions: completedQuestions,
        onContinue: () => Navigator.of(context).pop(),
        onRestart: () => Navigator.of(context).pop(),
      );
    }
  }

  void _markQuizCompleted() {
    setState(() {
      quizCompleted = true;
    });
  }

  Widget _buildExercise(Map<String, dynamic> item) {
    final type = item['type'];
    final wordId = item['wordId'];
    final exerciseData = item['data'];
    final quizKey = item['key'];

    switch (type) {
      case 'multiple_choice':
        return MultipleChoiceExercise(
          topicId: widget.topicId,
          wordId: wordId,
          exerciseData: exerciseData,
          onCompleted: (isCorrect) => _handleResult(
            wordId: wordId,
            quizKey: quizKey,
            type: type,
            isCorrect: isCorrect,
          ),
        );
      case 'listening_choice':
        return ListeningChoiceExercise(
          topicId: widget.topicId,
          wordId: wordId,
          exerciseData: exerciseData,
          onCompleted: (isCorrect) => _handleResult(
            wordId: wordId,
            quizKey: quizKey,
            type: type,
            isCorrect: isCorrect,
          ),
        );
      case 'vocab_reorder':
        return VocabReorderExercise(
          topicId: widget.topicId,
          wordId: wordId,
          exerciseData: exerciseData,
          onCompleted: (isCorrect) => _handleResult(
            wordId: wordId,
            quizKey: quizKey,
            type: type,
            isCorrect: isCorrect,
          ),
        );
      case 'typing':
        return TypingExercise(
          topicId: widget.topicId,
          wordId: wordId,
          exerciseData: exerciseData,
          onCompleted: (isCorrect) => _handleResult(
            wordId: wordId,
            quizKey: quizKey,
            type: type,
            isCorrect: isCorrect,
          ),
        );
      default:
        return const Text("❌ Bài tập không được hỗ trợ.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    double progressValue = (current + 1) / quizItems.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 30),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7.5),
                child: LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  minHeight: 15,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(child: _buildExercise(quizItems[current])),
          if (quizCompleted)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _next,
                child: Text(current == quizItems.length - 1 ? 'Hoàn thành' : 'Tiếp tục'),
              ),
            ),
        ],
      ),
    );
  }
}