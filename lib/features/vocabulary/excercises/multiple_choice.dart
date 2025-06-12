import 'package:flutter/material.dart';


class MultipleChoiceExercise extends StatefulWidget {
  final String topicId;
  final String wordId;
  final Map<String, dynamic> exerciseData;
  final Function(bool isCorrect, String userAnswer) onCompleted;

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

class _MultipleChoiceExerciseState extends State<MultipleChoiceExercise> with SingleTickerProviderStateMixin {
  int? selectedIndex;
  int? correctIndex;
  bool showResult = false;
  List<String> options = [];
  String? question;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool isProcessing = false;
  bool continueEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        isProcessing = false;
      });
      _loadData();
      _animationController.forward(from: 0.0);
    }
  }

  void _loadData() {
    final data = widget.exerciseData;
    options = List<String>.from(data['options'] ?? []);
    options.shuffle();
    correctIndex = data['correct_answer'] != null
        ? options.indexOf(data['correct_answer'])
        : data['answer'];
    question = data['question'] ?? "📝 Chọn đáp án đúng:";
  }

  void _checkAnswer(int index) async {
    if (showResult || isProcessing) return;
    setState(() {
      isProcessing = true;
      selectedIndex = index;
      showResult = true;
    });

    final isCorrect = index == correctIndex;
    final userAnswer = selectedIndex != null ? options[selectedIndex!] : '';

    widget.onCompleted(isCorrect, userAnswer);

    setState(() {
      isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6A3DE8), Color(0xFF5035BE)],
          ),
        ),
        child: SafeArea(
          child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
            question ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
            textAlign: TextAlign.center,
          ),
                ),
                const SizedBox(height: 30),
                Column(
            children: List.generate(options.length, _buildOptionListTile),
          ),
        ],
      ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionListTile(int index) {
    final isCorrect = index == correctIndex;
    final isSelected = index == selectedIndex;
    final isWrong = isSelected && !isCorrect;
    
    Color backgroundColor;
    Color borderColor;
    Widget? trailingIcon;

    if (showResult) {
      if (isCorrect) {
        backgroundColor = const Color(0xFF4CAF50);
        borderColor = Colors.green.shade700;
        trailingIcon = const Icon(Icons.check_circle, color: Colors.white, size: 24);
      } else if (isWrong) {
        backgroundColor = const Color(0xFFF44336);
        borderColor = Colors.red.shade700;
        trailingIcon = const Icon(Icons.cancel, color: Colors.white, size: 24);
      } else {
        backgroundColor = Colors.white.withOpacity(0.15);
        borderColor = Colors.white.withOpacity(0.3);
        trailingIcon = null;
      }
    } else {
      backgroundColor = Colors.white.withOpacity(0.15);
      borderColor = Colors.white.withOpacity(0.3);
      trailingIcon = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: showResult ? null : () => _checkAnswer(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF6A3DE8),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
          options[index],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
        ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 16),
                  trailingIcon,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}