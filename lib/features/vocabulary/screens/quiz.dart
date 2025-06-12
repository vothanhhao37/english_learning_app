import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/vocabulary_service.dart';
import '../../common/congrationlation_popup.dart';
import '../excercises/listening_choice.dart';
import '../excercises/multiple_choice.dart';
import '../excercises/reorder.dart';
import '../excercises/typing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/custom_snackbar.dart';


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
  int correctAnswers = 0;
  Set<int> answeredQuestions = {};
  final VocabularyService _service = VocabularyService();
  bool _currentQuestionIsCorrect = false;
  String _currentUserAnswer = '';
  bool _isUpdatingProgress = false;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    print('Starting _loadQuiz for topic: ${widget.topicId}');
    try {
      quizItems = await _service.loadQuiz(widget.topicId);
      print('Successfully loaded quiz items: ${quizItems.length}');
      setState(() {
        loading = false;
        quizCompleted = false;
        correctAnswers = 0;
        answeredQuestions.clear();
      });

      if (quizItems.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có bài tập nào khả dụng trong chủ đề này')),
        );
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error in _loadQuiz: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải bài tập: $e')),
      );
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _handleResult({
    required String wordId,
    required String quizKey,
    required String type,
    required bool isCorrect,
    required String userAnswer,
  }) async {
    if (answeredQuestions.contains(current)) return;

    setState(() {
      _currentQuestionIsCorrect = isCorrect;
      _currentUserAnswer = userAnswer;
    });

      setState(() {
      answeredQuestions.add(current);
        quizCompleted = true;
    });

      if (mounted) {
        CustomSnackBarClaude.show(
          context: context,
          message: isCorrect ? 'Chính xác!' : 'Chưa chính xác',
          type: isCorrect ? SnackBarType.success : SnackBarType.error,
          duration: const Duration(seconds: 2),
        );
    }
  }

  Future<void> _next() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    setState(() {
      quizCompleted = false;
    });

    final currentExercise = quizItems[current];
    final wordId = currentExercise['wordId'];
    final quizKey = currentExercise['key'];
    final type = currentExercise['type'];

    _service.saveQuizResult(
      topicId: widget.topicId,
      wordId: wordId,
      quizKey: quizKey,
      type: type,
      isCorrect: _currentQuestionIsCorrect,
      topicTitle: widget.topicTitle,
      userAnswer: _currentUserAnswer,
    ).catchError((e) {
      print('Lỗi khi lưu kết quả bài tập từ vựng (async): $e');
    });

    setState(() {
      quizItems[current]['status'] = _currentQuestionIsCorrect ? 'correct' : 'wrong';
      if (_currentQuestionIsCorrect) {
        correctAnswers++;
      }
    });

    if (current < quizItems.length - 1) {
      setState(() {
        current++;
        _currentQuestionIsCorrect = false;
        _currentUserAnswer = '';
      });
    } else {
      setState(() {
        _isUpdatingProgress = true;
      });
      _service.updateTopicProgress(widget.topicId, widget.topicTitle)
           .catchError((e) {
               print('Lỗi khi cập nhật tổng quan chủ đề (async): $e');
           }).whenComplete(() {
             if (mounted) {
               setState(() {
                 _isUpdatingProgress = false;
               });
             }
           });

      if (mounted) {
      LessonCompletionPopup.show(
        context,
        lessonTitle: widget.topicTitle,
        correctAnswers: correctAnswers,
        totalQuestions: quizItems.length,
          onContinue: () {
            Navigator.of(context).pop();
          },
          onRestart: () {
            Navigator.of(context).pop();
          },
      );
      }
    }
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
          onCompleted: (isCorrect, userAnswer) => _handleResult(
            wordId: wordId,
            quizKey: quizKey,
            type: type,
            isCorrect: isCorrect,
            userAnswer: userAnswer,
          ),
        );
      case 'listening_choice':
        return ListeningChoiceExercise(
          topicId: widget.topicId,
          wordId: wordId,
          exerciseData: exerciseData,
          onCompleted: (isCorrect, userAnswer) => _handleResult(
            wordId: wordId,
            quizKey: quizKey,
            type: type,
            isCorrect: isCorrect,
            userAnswer: userAnswer,
          ),
        );
      case 'vocab_reorder':
        return VocabReorderExercise(
          topicId: widget.topicId,
          wordId: wordId,
          exerciseData: exerciseData,
          onCompleted: (isCorrect, userAnswer) => _handleResult(
            wordId: wordId,
            quizKey: quizKey,
            type: type,
            isCorrect: isCorrect,
            userAnswer: userAnswer,
          ),
        );
      case 'typing':
        return TypingExercise(
          topicId: widget.topicId,
          wordId: wordId,
          exerciseData: exerciseData,
          onCompleted: (isCorrect, userAnswer) => _handleResult(
            wordId: wordId,
            quizKey: quizKey,
            type: type,
            isCorrect: isCorrect,
            userAnswer: userAnswer,
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

    return WillPopScope(
      onWillPop: () async {
        if (!mounted) return true;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        return true;
      },
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6A3DE8), Color(0xFF5035BE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, size: 28, color: Colors.white),
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          Navigator.pop(context);
                        },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7.5),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFC107)),
                          minHeight: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildExercise(quizItems[current])),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: quizCompleted && !_isUpdatingProgress ? _next : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (quizCompleted && !_isUpdatingProgress) ? const Color(0xFFFFC107) : Colors.grey[300],
                    foregroundColor: (quizCompleted && !_isUpdatingProgress) ? Colors.black87 : Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    elevation: 0,
                    shadowColor: Colors.black.withOpacity(0.1),
                    minimumSize: const Size(double.infinity, 60),
                  ),
                  child: Text(
                    current == quizItems.length - 1 ? 'Hoàn thành' : 'Tiếp tục',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}