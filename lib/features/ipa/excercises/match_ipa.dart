import 'package:flutter/material.dart';

import '../../../services/ipa_service.dart';

class IpaMatchingQuiz extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final void Function(bool, String, String) onAnswer;

  const IpaMatchingQuiz({
    Key? key,
    required this.lesson,
    required this.onAnswer,
  }) : super(key: key);

  @override
  State<IpaMatchingQuiz> createState() => _IpaMatchingQuizState();
}

class _IpaMatchingQuizState extends State<IpaMatchingQuiz> with TickerProviderStateMixin {
  String? selectedAnswer;
  bool hasAnswered = false;
  bool isCorrect = false;
  List<String> options = [];
  final IpaService _ipaService = IpaService();

  late AnimationController _appearController;
  late AnimationController _optionsController;
  late Animation<double> _appearAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _prepareOptions();
  }

  void _setupAnimations() {
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _optionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _appearAnimation = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOut,
    );
    _appearController.forward();
    _optionsController.forward();
  }

  void _prepareOptions() {
    options = List<String>.from(widget.lesson['options'] ?? []);
  }

  void _selectAnswer(String answer) {
    if (!hasAnswered) {
      final correctAnswer = widget.lesson['correct_answer'] as String;
      setState(() {
        selectedAnswer = answer;
        hasAnswered = true;
        isCorrect = answer == correctAnswer;
      });
      if (isCorrect) {
        _ipaService.playCorrectSound();
      } else {
        _ipaService.playIncorrectSound();
      }
    }
  }

  void _continueToNextQuestion() {
    if (hasAnswered) {
      widget.onAnswer(isCorrect, widget.lesson['type'], selectedAnswer ?? '');
    }
  }

  @override
  void dispose() {
    _appearController.dispose();
    _optionsController.dispose();
    _ipaService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _appearAnimation,
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
                    'Chọn từ đúng của phiên âm sau ${widget.lesson['ipa']}',
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
                child: _buildQuizArea(),
              ),
              _buildFeedbackArea(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: hasAnswered ? _continueToNextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasAnswered ? const Color(0xFFFFC107) : Colors.grey,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                    'Tiếp tục',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizArea() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              bool isSelected = selectedAnswer == option;
              bool isOptionCorrect = option == widget.lesson['correct_answer'];
              bool showResult = hasAnswered;

              return AnimatedBuilder(
                animation: _optionsController,
                builder: (context, child) {
                  final delay = index * 0.2;
                  final start = delay;
                  final end = start + 0.4;

                  final curvedAnimation = CurvedAnimation(
                    parent: _optionsController,
                    curve: Interval(start, end, curve: Curves.easeOut),
                  );

                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - curvedAnimation.value)),
                    child: Opacity(
                      opacity: curvedAnimation.value.clamp(0.0, 1.0),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: _buildOptionButton(
                          option: option,
                          isSelected: isSelected,
                          isCorrect: isOptionCorrect,
                          showResult: showResult,
                          index: index + 1,
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String option,
    required bool isSelected,
    required bool isCorrect,
    required bool showResult,
    required int index,
  }) {
    Color backgroundColor;
    Color borderColor;
    Widget? trailingIcon;

    if (showResult && isCorrect) {
      backgroundColor = const Color(0xFF4CAF50);
      borderColor = Colors.green.shade700;
      trailingIcon = const Icon(Icons.check_circle, color: Colors.white, size: 24);
    } else if (showResult && isSelected && !isCorrect) {
      backgroundColor = const Color(0xFFF44336);
      borderColor = Colors.red.shade700;
      trailingIcon = const Icon(Icons.cancel, color: Colors.white, size: 24);
    } else if (isSelected) {
      backgroundColor = Colors.amber;
      borderColor = Colors.amber.shade700;
      trailingIcon = null;
    } else {
      backgroundColor = Colors.white.withOpacity(0.15);
      borderColor = Colors.white.withOpacity(0.3);
      trailingIcon = null;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectAnswer(option),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Color(0xFF6A3DE8),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (trailingIcon != null) const SizedBox(width: 12),
              if (trailingIcon != null) trailingIcon,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackArea() {
    if (!hasAnswered) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.shade600 : Colors.red.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.error,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCorrect ? 'Chính xác!' : 'Chưa chính xác! Đáp án đúng: ${widget.lesson['correct_answer']}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}