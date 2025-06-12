import 'package:flutter/material.dart';

class TypingExercise extends StatefulWidget {
  final String topicId;
  final String wordId;
  final Map<String, dynamic> exerciseData;
  final Function(bool isCorrect, String userAnswer) onCompleted;

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

class _TypingExerciseState extends State<TypingExercise> with SingleTickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  bool completed = false;
  bool correct = false;
  String? correctAnswer;
  String? question;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    _animationController.dispose();
    super.dispose();
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

    widget.onCompleted(isCorrect, controller.text);
  }

  @override
  void didUpdateWidget(covariant TypingExercise oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordId != widget.wordId) {
      controller.clear();
      completed = false;
      correct = false;
      _loadData();
      _animationController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6A3DE8), Color(0xFF5035BE)],
            ),
          ),
          child: SafeArea(
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
                const SizedBox(height: 100),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
            textAlign: TextAlign.center,
          ),
                  ),
                ),
                const SizedBox(height: 60),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
            ),
            child: TextField(
              controller: controller,
              enabled: !completed,
              textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Nhập từ tiếng Anh',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
              ),
              onSubmitted: (_) => _checkAnswer(),
            ),
          ),
                        const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkAnswer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            elevation: 0,
                            shadowColor: Colors.black.withOpacity(0.1),
                          ),
                          child: const Text(
                            'Kiểm tra',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
        ],
            ),
          ),
        ),
      ),
    );
  }
}