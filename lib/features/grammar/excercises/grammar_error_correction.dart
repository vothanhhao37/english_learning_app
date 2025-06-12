import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../models/grammar_model.dart';
import '../../../services/grammar_service.dart';
import '../../../services/firebase_service.dart';
import '../../common/custom_snackbar.dart';
import '../../common/congrationlation_popup.dart';

class GrammarErrorCorrectionExercises extends StatefulWidget {
  final String grammarId;

  const GrammarErrorCorrectionExercises({Key? key, required this.grammarId}) : super(key: key);

  @override
  _GrammarErrorCorrectionExercisesState createState() => _GrammarErrorCorrectionExercisesState();
}

class _GrammarErrorCorrectionExercisesState extends State<GrammarErrorCorrectionExercises> {
  late GrammarService _grammarService;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _grammarService = GrammarService(FirebaseService());
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    try {
      await _grammarService.setExercises(widget.grammarId, 'error_correction');
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<InlineSpan> _buildSentenceSpans(Exercise exercise) {
    List<String> words = exercise.options ?? [];
    List<InlineSpan> spans = [];

    for (int i = 0; i < words.length; i++) {
      String word = words[i];
      String wordId = "${i}_$word";

      bool isSelected = _grammarService.userAnswer == wordId;
      bool isCorrectAnswer = word == exercise.answer;

      Color textColor;
      TextDecoration decoration;
      Color decorationColor;
      double decorationThickness;
      FontWeight fontWeight;

      if (_grammarService.isAnswered) {
        if (isCorrectAnswer) {
          textColor = Colors.green;
          decoration = TextDecoration.underline;
          decorationColor = Colors.green;
          decorationThickness = 3.0;
          fontWeight = FontWeight.bold;
        } else if (isSelected && !isCorrectAnswer) {
          textColor = Colors.red;
          decoration = TextDecoration.lineThrough;
          decorationColor = Colors.red;
          decorationThickness = 3.0;
          fontWeight = FontWeight.normal;
        } else {
          textColor = Colors.white;
          decoration = TextDecoration.none;
          decorationColor = Colors.transparent;
          decorationThickness = 0.0;
          fontWeight = FontWeight.normal;
        }
      } else {
        if (isSelected) {
          textColor = Color(0xFFFFC107);
          decoration = TextDecoration.underline;
          decorationColor = Color(0xFFFFC107);
          decorationThickness = 3.0;
          fontWeight = FontWeight.bold;
        } else {
          textColor = Colors.white;
          decoration = TextDecoration.none;
          decorationColor = Colors.transparent;
          decorationThickness = 0.0;
          fontWeight = FontWeight.normal;
        }
      }

      final TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (!_grammarService.isAnswered) {
            _grammarService.checkAnswer(wordId, exercise, widget.grammarId);
            setState(() {});
            if (_grammarService.isCorrect) {
              CustomSnackBarClaude.show(
                context: context,
                message: 'Chính xác!',
                type: SnackBarType.success,
                duration: const Duration(seconds: 2),
                
              );
            } else {
              CustomSnackBarClaude.show(
                context: context,
                message: 'Chưa đúng, hãy thử lại!',
                type: SnackBarType.error,
                duration: const Duration(seconds: 2),
                
              );
            }
          }
        };

      spans.add(
        TextSpan(
          text: word,
          recognizer: recognizer,
          style: TextStyle(
            color: textColor,
            decoration: decoration,
            decorationColor: decorationColor,
            decorationThickness: decorationThickness,
            fontWeight: FontWeight.bold,
            fontSize: 30,
            height: 1.5,
            shadows: isSelected || (isCorrectAnswer && _grammarService.isAnswered)
                ? [
              Shadow(
                color: isSelected
                    ? Color(0xFFFFC107).withOpacity(0.7)
                    : Colors.green.withOpacity(0.7),
                blurRadius: 8,
              )
            ]
                : [
              Shadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 3,
              )
            ],
          ),
        ),
      );

      bool isPunctuation = word == "." || word == "," || word == "!" || word == "?" || word == ";";

      if (i < words.length - 1 && !isPunctuation) {
        spans.add(TextSpan(text: ' '));
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF673AB7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Tìm lỗi sai',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        )
            : _grammarService.exercises.isEmpty
            ? _buildEmptyState()
            : _buildExerciseContent(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.assignment_late,
          color: Colors.white,
          size: 64,
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Không có bài tập tìm lỗi sai nào được tìm thấy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'Quay lại',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseContent() {
    final exercise = _grammarService.exercises[_grammarService.currentQuestionIndex];

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.error_outline, color: Colors.white, size: 30),
              ),
              SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tìm lỗi sai',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Câu ${_grammarService.currentQuestionIndex + 1}/${_grammarService.exercises.length}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: 15),
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (_grammarService.currentQuestionIndex + 1) / _grammarService.exercises.length,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFFFC107),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  margin: EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Nhấn vào từ chứa lỗi sai trong câu sau:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 25, horizontal: 15),
                    decoration: BoxDecoration(
                      color: Color(0xFF673AB7),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(fontSize: 22, color: Colors.white, height: 1.5),
                            children: _buildSentenceSpans(exercise),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _grammarService.userAnswer == null
                        ? null
                        : (_grammarService.isAnswered
                        ? () {
                      if (_grammarService.currentQuestionIndex < _grammarService.exercises.length - 1) {
                        _grammarService.nextQuestion();
                        setState(() {});
                      } else {
                        LessonCompletionPopup.show(
                          context,
                          lessonTitle: 'Tìm lỗi sai',
                            correctAnswers: _grammarService.correctAnswers,
                            totalQuestions: _grammarService.exercises.length,
                          onContinue: () {
                            Navigator.of(context).pop();
                          },
                            onRestart: () {
                              Navigator.of(context).pop();
                              _grammarService.reset();
                              setState(() {});
                            },
                        );
                      }
                    }
                        : () {
                      _grammarService.checkAnswer(_grammarService.userAnswer, exercise, widget.grammarId);
                      setState(() {});
                      if (_grammarService.isCorrect) {
                        CustomSnackBarClaude.show(
                          context: context,
                          message: 'Chính xác!',
                          type: SnackBarType.success,
                          duration: const Duration(seconds: 2),
                          
                        );
                      } else {
                        CustomSnackBarClaude.show(
                          context: context,
                          message: 'Chưa đúng, hãy thử lại!',
                          type: SnackBarType.error,
                          duration: const Duration(seconds: 2),
                          
                        );
                      }
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _grammarService.userAnswer == null
                          ? Color(0xFFFFC107).withOpacity(0.5)
                          : Color(0xFFFFC107),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text(
                      _grammarService.isAnswered ? 'Câu tiếp theo' : 'Kiểm tra',
                      style: TextStyle(
                        color: Colors.white,
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
      ],
    );
  }
}