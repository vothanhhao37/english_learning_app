import 'package:flutter/material.dart';
import '../../common/constants.dart';
import '../../../services/grammar_service.dart';
import '../../../services/firebase_service.dart';
import '../../common/custom_snackbar.dart';
import '../../common/congrationlation_popup.dart';

class GrammarRewriteExercises extends StatefulWidget {
  final String grammarId;

  const GrammarRewriteExercises({Key? key, required this.grammarId}) : super(key: key);

  @override
  _GrammarRewriteExercisesState createState() => _GrammarRewriteExercisesState();
}

class _GrammarRewriteExercisesState extends State<GrammarRewriteExercises> {
  late GrammarService _grammarService;
  bool _isLoading = true;
  final TextEditingController _answerController = TextEditingController();
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
      await _grammarService.setExercises(widget.grammarId, 'rewrite');
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
      _answerController.clear();
      _isWrong = false;
      _errorMessage = '';
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
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
          'Viết lại câu',
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
          'Không có bài tập viết lại câu nào được tìm thấy',
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
                child: Icon(Icons.edit, color: Colors.white, size: 30),
              ),
              SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Viết lại câu',
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
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _answerController,
                    enabled: !_grammarService.isAnswered,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nhập câu trả lời của bạn',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      border: InputBorder.none,
                    ),
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: (!_grammarService.isAnswered && _answerController.text.isNotEmpty) ? 1.0 : 0.5,
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        width: 140,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: (!_grammarService.isAnswered && _answerController.text.isNotEmpty)
                              ? () {
                                  _grammarService.checkAnswer(_answerController.text, exercise, widget.grammarId);
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
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                            shadowColor: Colors.black.withOpacity(0.1),
                          ),
                          child: const Text(
                            'Kiểm tra',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                const SizedBox(height: 16),
                AnimatedOpacity(
                  opacity: _grammarService.isAnswered ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                  width: double.infinity,
                    height: 48,
                  child: ElevatedButton(
                    onPressed: _grammarService.isAnswered
                        ? () {
                      if (_grammarService.currentQuestionIndex < _grammarService.exercises.length - 1) {
                        _grammarService.nextQuestion();
                        _resetState();
                      } else {
                                LessonCompletionPopup.show(
                                  context,
                                  lessonTitle: 'Viết lại câu',
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
                          : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                      ),
                        elevation: 0,
                        shadowColor: Colors.black.withOpacity(0.1),
                    ),
                      child: const Text(
                        'Tiếp tục',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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