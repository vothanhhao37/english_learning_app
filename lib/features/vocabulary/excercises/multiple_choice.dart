import 'package:flutter/material.dart';

class MultipleChoiceExercise extends StatefulWidget {
  final String topicId;
  final String wordId;
  final Map<String, dynamic> exerciseData;
  final Function(bool isCorrect) onCompleted;

  const MultipleChoiceExercise({
    super.key,
    required this.topicId,
    required this.wordId,
    required this.exerciseData,
    required this.onCompleted,
  });

  @override
  State<MultipleChoiceExercise> createState() => _MultipleChoiceExerciseState();
}

class _MultipleChoiceExerciseState extends State<MultipleChoiceExercise> {
  int? selectedIndex;
  int? correctIndex;
  bool showResult = false;
  List<String> options = [];
  String? question;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant MultipleChoiceExercise oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordId != widget.wordId) {
      setState(() {
        selectedIndex = null;
        correctIndex = null;
        showResult = false;
        options = [];
      });
      _loadData();
    }
  }

  void _loadData() {
    final data = widget.exerciseData;
    options = List<String>.from(data['options'] ?? []);
    correctIndex = data['correct_answer'] != null
        ? options.indexOf(data['correct_answer'])
        : data['answer'];
    question = data['question'] ?? "📝 Chọn đáp án đúng:";
  }

  void _checkAnswer(int index) {
    if (showResult) return;
    setState(() {
      selectedIndex = index;
      showResult = true;
    });

    final isCorrect = index == correctIndex;
    widget.onCompleted(isCorrect);
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
          options.length == 4
              ? GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.8,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(options.length, _buildOptionBox),
          )
              : Column(
            children: List.generate(options.length, _buildOptionListTile),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionBox(int index) {
    final isCorrect = index == correctIndex;
    final isSelected = index == selectedIndex;
    final isWrong = isSelected && !isCorrect;
    final color = showResult
        ? (isCorrect ? Colors.green[200] : (isWrong ? Colors.red[200] : Colors.grey.shade200))
        : Colors.grey.shade200;

    final textColor = showResult && (isCorrect || isWrong) ? Colors.white : Colors.indigo[800];

    return GestureDetector(
      onTap: () => _checkAnswer(index),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        child: Text(
          options[index],
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
    );
  }

  Widget _buildOptionListTile(int index) {
    final isCorrect = index == correctIndex;
    final isSelected = index == selectedIndex;
    final isWrong = isSelected && !isCorrect;
    final color = showResult
        ? (isCorrect ? Colors.green[200] : (isWrong ? Colors.red[200] : Colors.grey.shade200))
        : Colors.grey.shade200;

    final textColor = showResult && (isCorrect || isWrong) ? Colors.white : Colors.indigo[800];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        title: Text(
          options[index],
          style: TextStyle(fontSize: 18, color: textColor, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        onTap: () => _checkAnswer(index),
      ),
    );
  }
}