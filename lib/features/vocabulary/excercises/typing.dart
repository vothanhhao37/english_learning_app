import 'package:flutter/material.dart';

class TypingExercise extends StatefulWidget {
  final String topicId;
  final String wordId;
  final Map<String, dynamic> exerciseData;
  final Function(bool isCorrect) onCompleted;

  const TypingExercise({
    super.key,
    required this.topicId,
    required this.wordId,
    required this.exerciseData,
    required this.onCompleted,
  });

  @override
  State<TypingExercise> createState() => _TypingExerciseState();
}

class _TypingExerciseState extends State<TypingExercise> {
  final TextEditingController controller = TextEditingController();
  bool completed = false;
  bool correct = false;
  String? correctAnswer;
  String? question;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    correctAnswer = widget.exerciseData['correct_answer'] ?? '';
    question = widget.exerciseData['question'] ?? '✍️ Gõ lại từ đúng:';
  }

  void _checkAnswer() {
    final answer = (correctAnswer ?? '').toLowerCase().replaceAll(' ', '');
    final input = controller.text.toLowerCase().replaceAll(' ', '');

    final isCorrect = input == answer;
    setState(() {
      completed = true;
      correct = isCorrect;
    });

    widget.onCompleted(isCorrect);
  }

  @override
  void didUpdateWidget(covariant TypingExercise oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordId != widget.wordId) {
      controller.clear();
      completed = false;
      correct = false;
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            question ?? '',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: TextField(
              controller: controller,
              enabled: !completed,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Nhập từ tiếng Anh',
              ),
              onSubmitted: (_) => _checkAnswer(),
            ),
          ),
          const SizedBox(height: 20),
          if (!completed)
            ElevatedButton(
              onPressed: _checkAnswer,
              child: const Text('Kiểm tra'),
            ),
          if (completed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                correct ? '✅ Đúng rồi!' : '❌ Sai rồi! Đáp án: $correctAnswer',
                style: TextStyle(
                  fontSize: 18,
                  color: correct ? Colors.green[700] : Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}