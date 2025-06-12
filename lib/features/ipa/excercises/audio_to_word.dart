import 'package:flutter/material.dart';

import '../../../services/ipa_service.dart';

class IpaAudioToWordQuiz extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final void Function(bool, String, String) onAnswer;

  const IpaAudioToWordQuiz({
    Key? key,
    required this.lesson,
    required this.onAnswer,
  }) : super(key: key);

  @override
  State<IpaAudioToWordQuiz> createState() => _IpaAudioToWordQuizState();
}

class _IpaAudioToWordQuizState extends State<IpaAudioToWordQuiz> with TickerProviderStateMixin {
  bool isPlaying = false;
  String? selectedAnswer;
  bool hasAnswered = false;
  bool isCorrect = false;
  final IpaService _ipaService = IpaService();

  late AnimationController _appearController;
  late AnimationController _optionsController;
  late Animation<double> _appearAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    Future.delayed(const Duration(milliseconds: 800), () {
      _playAudio(widget.lesson['question_word'] ?? '');
    });
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

  Future<void> _playAudio(String word) async {
    if (isPlaying) return;
    setState(() {
      isPlaying = true;
    });
    await _ipaService.playQuizAudio(word);
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      isPlaying = false;
    });
  }

  void _checkAnswer(String answer) {
    if (hasAnswered) return;
    final correctAnswer = widget.lesson['correct_answer'] ?? '';
    final isCorrectAnswer = answer == correctAnswer;
    setState(() {
      hasAnswered = true;
      selectedAnswer = answer;
      isCorrect = isCorrectAnswer;
    });
    if (isCorrectAnswer) {
      _ipaService.playCorrectSound();
    } else {
      _ipaService.playIncorrectSound();
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
    final options = List<String>.from(widget.lesson['options'] ?? []);
    final correctAnswer = widget.lesson['correct_answer'] ?? '';

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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              _buildAudioButton(),
              const SizedBox(height: 24),
              _buildInstructionText(),
              const SizedBox(height: 24),
              _buildOptions(options, correctAnswer),
              const Spacer(),
              _buildFeedbackArea(),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioButton() {
    return GestureDetector(
      onTap: isPlaying ? null : () => _playAudio(widget.lesson['question_word'] ?? ''),
      child: Column(
        children: [
        Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8D61FF), Color(0xFF5D41B0)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isPlaying
                ? const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          )
              : const Icon(
          Icons.volume_up,
          size: 48,
          color: Colors.white,
        ),
      ),
    ),
    ),
    const SizedBox(height: 8),
    AnimatedOpacity(
    opacity: isPlaying ? 0.0 : 1.0,
    duration: const Duration(milliseconds: 300),
    child: Text(
    'Nhấn để nghe lại',
    style: TextStyle(
    color: Colors.white.withValues(alpha: 0.8),
    fontSize: 14,
    ),
    ),
    ),
    ],
    ),
    );
  }

  Widget _buildInstructionText() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: const Text(
        'Chọn từ bạn vừa nghe',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOptions(List<String> options, String correctAnswer) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        bool isSelected = selectedAnswer == option;
        bool isCorrect = option == correctAnswer;
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
                    isCorrect: isCorrect,
                    showResult: showResult,
                    index: index + 1,
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
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
      backgroundColor = Colors.white.withValues(alpha: 0.15);
      borderColor = Colors.white.withValues(alpha: 0.3);
      trailingIcon = null;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasAnswered ? null : () => _checkAnswer(option),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
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
                      color: Colors.black.withValues(alpha: 0.1),
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
              const SizedBox(width: 12),
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
              if (trailingIcon != null) trailingIcon,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackArea() {
    if (!hasAnswered) return const SizedBox.shrink();

    final isAnswerCorrect = selectedAnswer == widget.lesson['correct_answer'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAnswerCorrect ? Colors.green.shade600 : Colors.red.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isAnswerCorrect ? Icons.check_circle : Icons.error,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAnswerCorrect ? 'Chính xác!' : 'Chưa chính xác!',
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

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton(
        onPressed: hasAnswered ? _continueToNextQuestion : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFC107),
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Tiếp tục',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}