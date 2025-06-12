import 'package:flutter/material.dart';

import '../../../services/ipa_service.dart';
import '../../common/congrationlation_popup.dart';
import '../excercises/audio_to_word.dart';
import '../excercises/match_ipa.dart';
import '../excercises/speech_practice.dart';
import '../excercises/word_to_audio.dart';


class IpaQuizScreen extends StatefulWidget {
  final String ipaId;

  const IpaQuizScreen({Key? key, required this.ipaId}) : super(key: key);

  @override
  State<IpaQuizScreen> createState() => _IpaQuizScreenState();
}

class _IpaQuizScreenState extends State<IpaQuizScreen> with SingleTickerProviderStateMixin {
  bool isLoading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> lessons = [];
  int currentLessonIndex = 0;
  double progressValue = 0.0;
  int correctAnswers = 0;
  int totalQuestions = 0;
  final IpaService _ipaService = IpaService();

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      final allLessons = await _ipaService.loadLessons(widget.ipaId);
      setState(() {
        lessons = allLessons;
        totalQuestions = allLessons.length;
        progressValue = totalQuestions > 0 ? 1.0 / totalQuestions : 0;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  void nextLesson() {
    if (currentLessonIndex < lessons.length - 1) {
      setState(() {
        currentLessonIndex++;
        progressValue = (currentLessonIndex + 1) / lessons.length;
      });
    } else {
      LessonCompletionPopup.show(
        context,
        lessonTitle: 'Luyện phát âm IPA',
        correctAnswers: correctAnswers,
        totalQuestions: totalQuestions,
        assessment: 'Bạn đã hoàn thành bài học!',
        onContinue: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onRestart: () {
          Navigator.pop(context);
          setState(() {
            currentLessonIndex = 0;
            correctAnswers = 0;
          });
        },
      );
    }
  }

  void handleQuizAnswer(bool isCorrect, String lessonType, String userAnswer) {
    if (isCorrect) {
      setState(() {
        correctAnswers++;
      });
    }
    final lesson = lessons[currentLessonIndex];
    final lessonId = lesson['id'];
    _ipaService.saveScore(
      ipaId: widget.ipaId,
      lessonId: lessonId,
      isCorrect: isCorrect,
      lessonType: lessonType,
      userAnswer: userAnswer,
    );
    nextLesson();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6A3DE8), Color(0xFF5035BE)],
          ),
        ),
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6937A1)),
          ),
        )
            : errorMessage.isNotEmpty
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        )
            : Column(
          children: [
            _buildLessonHeader(),
            Expanded(child: _buildLessonContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonHeader() {
    final current = currentLessonIndex + 1;
    final total = totalQuestions;
    final type = lessons[currentLessonIndex]['type'];
    final title = _getLessonTitle(type);
    final progressWidth = total > 0 ? (current / total) * 120 : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.book, size: 20, color: Colors.black87),
                    SizedBox(width: 6),
                    Text(
                      'Bài tập',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text('Câu $current/$total', style: const TextStyle(color: Colors.white)),
              const Spacer(),
              Container(
                width: 120,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: progressWidth,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLessonTitle(String type) {
    switch (type) {
      case 'audio_to_word':
        return 'Nghe chọn từ';
      case 'word_to_audio':
        return 'Chọn phát âm đúng';
      case 'match_ipa':
        return 'Trắc nghiệm IPA';
      case 'speech_practice':
        return 'Luyện phát âm';
      default:
        return 'Bài học';
    }
  }

  Widget _buildLessonContent() {
    if (lessons.isEmpty) {
      return const Center(child: Text('Không có bài tập nào.'));
    }

    final lesson = lessons[currentLessonIndex];
    final lessonType = lesson['type'];

    if (lesson == null || !lesson.containsKey('type')) {
      return Center(child: Text('Dữ liệu bài tập không hợp lệ: $lesson'));
    }

    switch (lessonType) {
      case 'audio_to_word':
        if (!lesson.containsKey('options') || !lesson.containsKey('correct_answer')) {
          return Center(child: Text('Thiếu dữ liệu cho audio_to_word: $lesson'));
        }
        return IpaAudioToWordQuiz(
          key: ValueKey(currentLessonIndex),
          lesson: lesson,
          onAnswer: (isCorrect, lessonType, userAnswer) => handleQuizAnswer(isCorrect, lessonType, userAnswer),
        );
      case 'word_to_audio':
        if (!lesson.containsKey('options') || !lesson.containsKey('correct_answer')) {
          return Center(child: Text('Thiếu dữ liệu cho word_to_audio: $lesson'));
        }
        return IpaWordToAudioQuiz(
          key: ValueKey(currentLessonIndex),
          lesson: lesson,
          onAnswer: (isCorrect, lessonType, userAnswer) => handleQuizAnswer(isCorrect, lessonType, userAnswer),
        );
      case 'match_ipa':
        if (!lesson.containsKey('options') || !lesson.containsKey('correct_answer')) {
          return Center(child: Text('Thiếu dữ liệu cho match_ipa: $lesson'));
        }
        return IpaMatchingQuiz(
          key: ValueKey(currentLessonIndex),
          lesson: lesson,
          onAnswer: (isCorrect, lessonType, userAnswer) => handleQuizAnswer(isCorrect, lessonType, userAnswer),
        );
      case 'speech_practice':
        if (!lesson.containsKey('word') || !lesson.containsKey('ipa')) {
          return Center(child: Text('Thiếu dữ liệu cho speech_practice: $lesson'));
        }
        return IpaSpeechPractice(
          key: ValueKey(currentLessonIndex),
          lesson: lesson,
          onAnswer: (isCorrect, lessonType, userAnswer) => handleQuizAnswer(isCorrect, lessonType, userAnswer),
        );
      default:
        return Center(child: Text('Không hỗ trợ loại bài tập: $lessonType'));
    }
  }
}