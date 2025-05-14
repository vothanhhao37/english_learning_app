import 'package:flutter/material.dart';

import '../../../services/vocabulary_service.dart';

class ListeningChoiceExercise extends StatefulWidget {
  final String topicId;
  final String wordId;
  final Map<String, dynamic> exerciseData;
  final Function(bool isCorrect) onCompleted;

  const ListeningChoiceExercise({
    super.key,
    required this.topicId,
    required this.wordId,
    required this.exerciseData,
    required this.onCompleted,
  });

  @override
  State<ListeningChoiceExercise> createState() => _ListeningChoiceExerciseState();
}

class _ListeningChoiceExerciseState extends State<ListeningChoiceExercise> {
  int? selectedIndex;
  int? correctIndex;
  bool showResult = false;
  List<String> options = [];
  String? word;
  final VocabularyService _service = VocabularyService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ListeningChoiceExercise oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordId != widget.wordId) {
      setState(() {
        selectedIndex = null;
        correctIndex = null;
        showResult = false;
        options = [];
        word = null;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final data = widget.exerciseData;
    options = List<String>.from(data['options'] ?? []);
    correctIndex = data['correct_answer'] != null
        ? options.indexOf(data['correct_answer'])
        : data['answer'];
    word = data['audio'] ?? data['word'];

    await Future.delayed(const Duration(milliseconds: 300));
    _playAudio();
  }

  Future<void> _playAudio() async {
    if (word != null && word!.isNotEmpty) {
      await _service.speak(word!);
    }
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
          IconButton(
            onPressed: _playAudio,
            icon: const Icon(Icons.volume_up, size: 48),
            color: Colors.deepPurple,
            tooltip: "Phát âm thanh",
          ),
          const SizedBox(height: 20),
          const Text(
            "📝 Chọn từ đúng với âm thanh:",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildOptionListTile(int index) {
    final isCorrect = index == correctIndex;
    final isSelected = index == selectedIndex;
    final isWrong = isSelected && !isCorrect;
    final color = showResult
        ? (isCorrect ? Colors.green[200] : (isWrong ? Colors.red[200] : null))
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        title: Text(options[index]),
        onTap: () => _checkAnswer(index),
      ),
    );
  }
}