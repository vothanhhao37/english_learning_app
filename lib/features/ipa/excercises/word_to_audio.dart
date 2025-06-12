import 'package:flutter/material.dart';

import '../../../services/ipa_service.dart';

class IpaWordToAudioQuiz extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final void Function(bool, String, String) onAnswer;

  const IpaWordToAudioQuiz({
    Key? key,
    required this.lesson,
    required this.onAnswer,
  }) : super(key: key);

  @override
  State<IpaWordToAudioQuiz> createState() => _IpaWordToAudioQuizState();
}

class _IpaWordToAudioQuizState extends State<IpaWordToAudioQuiz> with TickerProviderStateMixin {
  String? selectedOption;
  bool hasAnswered = false;
  bool isCorrect = false;
  Map<String, bool> isPlaying = {};
  final IpaService _ipaService = IpaService();

  late AnimationController _appearController;
  late AnimationController _optionsController;
  late Animation<double> _appearAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    final options = List<String>.from(widget.lesson['options'] ?? []);
    for (var option in options) {
      isPlaying[option] = false;
    }
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
    if (isPlaying[word] == true) return;
    for (var key in isPlaying.keys) {
      isPlaying[key] = false;
    }
    setState(() {
      isPlaying[word] = true;
    });
    await _ipaService.playQuizAudio(word);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        isPlaying[word] = false;
      });
    }
  }

  void _checkAnswer(String option) {
    if (hasAnswered) return;
    final correctAnswer = widget.lesson['correct_answer'] ?? '';
    final isCorrectAnswer = option == correctAnswer;
    setState(() {
      hasAnswered = true;
      selectedOption = option;
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
      widget.onAnswer(isCorrect, widget.lesson['type'], selectedOption ?? '');
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
    final questionWord = widget.lesson['question_word'] ?? '';

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
              const SizedBox(height: 16),
              _buildWordCard(questionWord),
              const SizedBox(height: 16),
              _buildInstructionText(),
              const SizedBox(height: 24),
              _buildAudioOptions(options, correctAnswer),
              const Spacer(),
              _buildFeedbackArea(),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordCard(String word) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          word,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6A3DE8),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionText() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: const Column(
        children: [
          Text(
            'Chọn phát âm đúng cho từ trên',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'Nhấn vào biểu tượng loa để nghe từng phát âm',
            style: TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAudioOptions(List<String> options, String correctAnswer) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        bool isSelected = selectedOption == option;
        bool isCorrect = option == correctAnswer;
        bool showResult = hasAnswered;
        bool isCurrentlyPlaying = isPlaying[option] ?? false;

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
                  margin: const EdgeInsets.only(bottom: 16),
                  child: _buildAudioOptionButton(
                    option: option,
                    isSelected: isSelected,
                    isCorrect: isCorrect,
                    showResult: showResult,
                    isPlaying: isCurrentlyPlaying,
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

  Widget _buildAudioOptionButton({
    required String option,
    required bool isSelected,
    required bool isCorrect,
    required bool showResult,
    required bool isPlaying,
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
        onTap: hasAnswered ? null : () => _checkAnswer(option),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
                      color: Colors.black.withOpacity(0.1),
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
              const Spacer(),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: isPlaying ? null : () => _playAudio(option),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isPlaying
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Color(0xFF6A3DE8),
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.volume_up,
                      color: Color(0xFF6A3DE8),
                      size: 24,
                    ),
                  ),
                  tooltip: 'Nghe phát âm',
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
    );
  }

  Widget _buildFeedbackArea() {
    if (!hasAnswered) return const SizedBox.shrink();

    final isAnswerCorrect = selectedOption == widget.lesson['correct_answer'];

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