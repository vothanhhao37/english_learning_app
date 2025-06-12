import 'package:flutter/material.dart';
import '../../../models/grammar_model.dart';
import '../../../services/grammar_service.dart';
import '../../../services/firebase_service.dart';
import '../../common/custom_snackbar.dart';
import '../../common/congrationlation_popup.dart';

class GrammarDragAndDropExercises extends StatefulWidget {
  final String grammarId;

  const GrammarDragAndDropExercises({required this.grammarId});

  @override
  _GrammarDragAndDropExercisesState createState() => _GrammarDragAndDropExercisesState();
}

class _GrammarDragAndDropExercisesState extends State<GrammarDragAndDropExercises> {
  late GrammarService _grammarService;
  bool _isLoading = true;
  List<String> _currentAnswer = [];


  @override
  void initState() {
    super.initState();
    _grammarService = GrammarService(FirebaseService());
    _loadQuestions();
  }

  void _loadQuestions() async {
    try {
      await _grammarService.setExercises(widget.grammarId, 'drag_and_drop');
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

  void _resetState() {
    setState(() {
      _currentAnswer = [];

    });
  }

  Widget _buildDragAndDropQuestion(Exercise exercise) {
    List<String> allOptions = exercise.options ?? [];
    List<String> availableOptions = allOptions.where((option) => !_currentAnswer.contains(option)).toList();
    bool allWordsUsed = availableOptions.isEmpty && _currentAnswer.length == allOptions.length;

    if (allWordsUsed && !_grammarService.isAnswered) {
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          String userAnswer = _currentAnswer.join(" ");
          _grammarService.checkAnswer(userAnswer, exercise, widget.grammarId);

          if (_grammarService.isCorrect) {
            setState(() {});
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
      });
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            exercise.question,
            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 120),
          child: _currentAnswer.isEmpty
              ? Center(
            child: Text(
              'Kéo các từ vào đây',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          )
              : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentAnswer.map((word) {
              return GestureDetector(
                onTap: () {
                  if (!_grammarService.isAnswered) {
                    setState(() {
                      _currentAnswer.remove(word);

                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    word,
                    style: TextStyle(color: Color(0xFF673AB7)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          constraints: BoxConstraints(minHeight: 100, maxHeight: 200),
          child: Wrap(
            spacing: 8,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: availableOptions.map((option) {
              return Draggable<String>(
                data: option,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    option,
                    style: TextStyle(color: Color(0xFF673AB7), fontWeight: FontWeight.w500),
                  ),
                ),
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      option,
                      style: TextStyle(color: Color(0xFF673AB7), fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      option,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                onDragCompleted: () {
                  setState(() {});
                },
              );
            }).toList(),
          ),
        ),
        DragTarget<String>(
          builder: (context, candidateData, rejectedData) {
            return Container(
              width: double.infinity,
              height: 70,
              margin: EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: candidateData.isNotEmpty
                    ? Colors.green.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? Colors.green
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  'Thả từ vào đây',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ),
            );
          },
          onAccept: (data) {
            if (!_grammarService.isAnswered) {
              setState(() {
                _currentAnswer.add(data);

              });
            }
          },
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: ElevatedButton(
            onPressed: _grammarService.isAnswered
                ? () {
              if (_grammarService.currentQuestionIndex < _grammarService.exercises.length - 1) {
                _grammarService.nextQuestion();
                _resetState();
              } else {
                LessonCompletionPopup.show(
                  context,
                  lessonTitle: 'Kéo và thả',
                  correctAnswers: _grammarService.correctAnswers,
                  totalQuestions: _grammarService.exercises.length,
                  onContinue: () {
                    Navigator.of(context).pop();
                  },
                  onRestart: () {
                    Navigator.of(context).pop();
                    _grammarService.reset();
                    _resetState();
                  },
                );
              }
            }
                : (allWordsUsed
                ? () {
              String userAnswer = _currentAnswer.join(" ");
              _grammarService.checkAnswer(userAnswer, exercise, widget.grammarId);

              if (_grammarService.isCorrect) {
                setState(() {});
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
                : null),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFFC107).withOpacity(_grammarService.isAnswered || allWordsUsed ? 1.0 : 0.5),
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
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF673AB7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Kéo và thả',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        )
            : Column(
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
                    child: Icon(
                      Icons.book,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bài tập',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        _grammarService.exercises.isEmpty
                            ? 'Không có câu hỏi'
                            : 'Câu ${_grammarService.currentQuestionIndex + 1}/${_grammarService.exercises.length}',
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
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _grammarService.exercises.isEmpty
                            ? 0
                            : (_grammarService.currentQuestionIndex + 1) / _grammarService.exercises.length,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFFFC107),
                            borderRadius: BorderRadius.circular(10),
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
                margin: EdgeInsets.all(10),
                child: _grammarService.exercises.isEmpty
                    ? Center(
                  child: Text(
                    'Không có câu hỏi nào được tìm thấy.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                )

                    : _buildDragAndDropQuestion(_grammarService.exercises[_grammarService.currentQuestionIndex])

              ),
            ),
          ],
        ),
      ),
    );
  }
}