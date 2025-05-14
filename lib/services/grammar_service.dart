import '../models/grammar_model.dart';
import 'firebase_service.dart';

class GrammarService {
  final FirebaseService _firebaseService;
  List<Exercise> _exercises = [];
  int _currentQuestionIndex = 0;
  bool _isAnswered = false;
  bool _isCorrect = false;
  int _correctAnswers = 0;
  dynamic _userAnswer;

  GrammarService(this._firebaseService);

  List<Exercise> get exercises => _exercises;
  int get currentQuestionIndex => _currentQuestionIndex;
  bool get isAnswered => _isAnswered;
  bool get isCorrect => _isCorrect;
  int get correctAnswers => _correctAnswers;
  dynamic get userAnswer => _userAnswer;

  Future<void> setExercises(String grammarId, String type) async {
    _exercises = await _firebaseService.grammar_fetchExercises(grammarId, type);
    _currentQuestionIndex = 0;
    _isAnswered = false;
    _isCorrect = false;
    _correctAnswers = 0;
    _userAnswer = null;
  }

  Future<void> checkAnswer(dynamic userAnswer, Exercise exercise, String topicId) async {
    _isAnswered = true;
    _userAnswer = userAnswer;
    _isCorrect = userAnswer.toString().toLowerCase() == exercise.answer.toLowerCase();
    if (_isCorrect) _correctAnswers++;

    await _firebaseService.grammar_saveGrammarScore(
      topicId: topicId,
      exerciseId: exercise.id,
      isCorrect: _isCorrect,
      exerciseType: exercise.type,
    );
  }

  void nextQuestion() {
    if (_currentQuestionIndex < _exercises.length - 1) {
      _currentQuestionIndex++;
      _isAnswered = false;
      _isCorrect = false;
      _userAnswer = null;
    }
  }

  void reset() {
    _currentQuestionIndex = 0;
    _isAnswered = false;
    _isCorrect = false;
    _correctAnswers = 0;
    _userAnswer = null;
    _exercises = [];
  }

  Future<GrammarModel> fetchGrammarLesson(String grammarId) async {
    return await _firebaseService.grammar_fetchGrammarLesson(grammarId);
  }

  Stream<List<Map<String, dynamic>>> fetchGrammarPoints() {
    return _firebaseService.grammar_fetchGrammarPoints();
  }
}