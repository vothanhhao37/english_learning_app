import 'package:flutter/material.dart';
import '../../common/constants.dart';
import '../../../models/grammar_model.dart';
import '../../../services/grammar_service.dart';
import '../../../services/firebase_service.dart';
import '../widgets/result_dialog.dart';

class MultipleChoiceExercises extends StatefulWidget {
  final String grammarId;

  const MultipleChoiceExercises({Key? key, required this.grammarId}) : super(key: key);

  @override
  _MultipleChoiceExercisesState createState() => _MultipleChoiceExercisesState();
}

class _MultipleChoiceExercisesState extends State<MultipleChoiceExercises> {
  late GrammarService _grammarService;
  bool _isLoading = true;
  bool _isWrong = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _grammarService = GrammarService(FirebaseService());
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    try {
      await _grammarService.setExercises(widget.grammarId, 'multiple_choice');
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
      _isWrong = false;
      _errorMessage = '';
    });
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
          'Trắc nghiệm',
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
        Icon(
          Icons.assignment_late,
          color: Colors.white,
          size: 64,
        ),
        SizedBox(height: 16),
        Text(
          'Không có bài tập trắc nghiệm nào được tìm thấy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
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
    final options = exercise.options ?? [];

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.question_answer, color: Colors.white, size: 30),
              ),
              SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trắc nghiệm',
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
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
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
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    exercise.question,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = _grammarService.userAnswer == option;
                      final isCorrect = option == exercise.answer && _grammarService.isAnswered;

                      return GestureDetector(
                        onTap: () {
                          if (!_grammarService.isAnswered) {
                            _grammarService.checkAnswer(option, exercise, widget.grammarId);
                            setState(() {
                              _isWrong = !_grammarService.isCorrect;
                              _errorMessage = exercise.explanation;
                            });
                          }
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? isCorrect
                                ? Colors.green
                                : Colors.red.withOpacity(0.8)
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + index),
                                    style: TextStyle(
                                      color: isSelected
                                          ? isCorrect
                                          ? Colors.green
                                          : Colors.red
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  isCorrect ? Icons.check : Icons.close,
                                  color: Colors.white,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isWrong)
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.close, color: Colors.white),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${AppConstants.incorrectMessage}\n$_errorMessage',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _grammarService.isAnswered
                        ? () {
                      if (_grammarService.currentQuestionIndex < _grammarService.exercises.length - 1) {
                        _grammarService.nextQuestion();
                        _resetState();
                      } else {
                        showDialog(
                          context: context,
                          builder: (context) => ResultDialog(
                            correctAnswers: _grammarService.correctAnswers,
                            totalQuestions: _grammarService.exercises.length,
                            onRestart: () {
                              Navigator.of(context).pop();
                              _grammarService.reset();
                              _resetState();
                            },
                          ),
                        );
                      }
                    }
                        : (_grammarService.userAnswer != null
                        ? () {
                      _grammarService.checkAnswer(_grammarService.userAnswer, exercise, widget.grammarId);
                      if (!_grammarService.isCorrect) {
                        setState(() {
                          _isWrong = true;
                          _errorMessage = exercise.explanation;
                        });
                      }
                    }
                        : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFC107).withOpacity(
                          _grammarService.isAnswered || _grammarService.userAnswer != null ? 1.0 : 0.5),
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