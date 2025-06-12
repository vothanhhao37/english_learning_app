import 'package:flutter/material.dart';

import '../../common/custom_snackbar.dart';


class VocabReorderExercise extends StatefulWidget {
  final String topicId;
  final String wordId;
  final Map<String, dynamic> exerciseData;
  final void Function(bool isCorrect, String userAnswer) onCompleted;

  const VocabReorderExercise({
    super.key,
    required this.topicId,
    required this.wordId,
    required this.exerciseData,
    required this.onCompleted,
  });

  @override
  State<VocabReorderExercise> createState() => _VocabReorderExerciseState();
}

class _VocabReorderExerciseState extends State<VocabReorderExercise> with TickerProviderStateMixin {
  late List<String> pool;
  late List<String?> upperBoxes;
  late List<bool> isInLowerArea;
  late String correctAnswer;
  late String question;
  int nextUpperIndex = 0;
  bool completed = false;
  bool correct = false;
  final Map<String, AnimationController> animationControllers = {};
  final Map<String, Offset> currentPositions = {};
  final Map<String, Offset> targetPositions = {};
  final Map<String, GlobalKey> characterKeys = {};
  final Map<int, GlobalKey> upperBoxKeys = {};
  final Set<int> occupiedLowerIndexes = {};
  final Set<int> lockedUpperIndexes = {};
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePositions();
    });
  }

  @override
  void dispose() {
    for (var controller in animationControllers.values) {
      controller.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _loadData() {
    final data = widget.exerciseData;
    pool = List<String>.from(data['scrambled'] ?? []);
    pool.shuffle();
    correctAnswer = (data['correct_answer'] ?? '').toLowerCase().replaceAll(' ', '');
    question = data['question'] ?? '';
    upperBoxes = List<String?>.filled(correctAnswer.length, null);
    isInLowerArea = List<bool>.filled(pool.length, true);

    for (int i = 0; i < pool.length; i++) {
      characterKeys[pool[i] + i.toString()] = GlobalKey();
      animationControllers[pool[i] + i.toString()] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
    }

    for (int i = 0; i < correctAnswer.length; i++) {
      upperBoxKeys[i] = GlobalKey();
    }
  }

  void _updatePositions() {
    for (int i = 0; i < pool.length; i++) {
      final box = characterKeys[pool[i] + i.toString()]?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        currentPositions[pool[i] + i.toString()] = box.localToGlobal(Offset.zero);
      }
    }

    for (int i = 0; i < upperBoxes.length; i++) {
      final box = upperBoxKeys[i]?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        targetPositions["upper_$i"] = box.localToGlobal(Offset.zero);
      }
    }
  }

  void moveCharacterUp(int index) {
    if (!isInLowerArea[index]) return;

    int placeholderIndex = -1;
    for (int i = 0; i < upperBoxes.length; i++) {
      if ((upperBoxes[i] == null || upperBoxes[i]!.isEmpty) && !lockedUpperIndexes.contains(i)) {
        placeholderIndex = i;
        break;
      }
    }
    if (placeholderIndex == -1) return;

    final String character = pool[index];
    final AnimationController controller = animationControllers[character + index.toString()]!;

    _updatePositions();
    final Offset startPos = currentPositions[character + index.toString()] ?? Offset.zero;
    final Offset endPos = targetPositions["upper_$placeholderIndex"] ?? Offset.zero;

    controller.reset();
    controller.forward();

    setState(() {
      isInLowerArea[index] = false;
      lockedUpperIndexes.add(placeholderIndex);
    });

    final entry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final t = controller.value;
            final x = startPos.dx + (endPos.dx - startPos.dx) * t;
            final y = startPos.dy + (endPos.dy - startPos.dy) * t;

            return Positioned(
              left: x,
              top: y,
              child: _buildChar(character, Colors.white, Color(0xFF6A3DE8)),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(entry);

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        entry.remove();
        setState(() {
          lockedUpperIndexes.remove(placeholderIndex);
          upperBoxes[placeholderIndex] = character;
          _checkAnswer();
        });
      }
    });
  }

  void moveCharacterDown(int upperIndex) {
    if (upperBoxes[upperIndex] != null) {
      final String character = upperBoxes[upperIndex]!;
      int? charIndex;
      for (int i = 0; i < pool.length; i++) {
        if (!isInLowerArea[i] && !occupiedLowerIndexes.contains(i) && pool[i] == character) {
          charIndex = i;
          break;
        }
      }
      if (charIndex == null) return;

      occupiedLowerIndexes.add(charIndex);

      final AnimationController controller = animationControllers[character + charIndex.toString()]!;
      _updatePositions();

      final Offset startPos = targetPositions["upper_$upperIndex"] ?? Offset.zero;
      final Offset endPos = currentPositions[character + charIndex.toString()] ?? Offset.zero;

      controller.reset();
      controller.forward();

      setState(() {
        upperBoxes[upperIndex] = null;
        nextUpperIndex--;
      });

      OverlayEntry entry = OverlayEntry(
        builder: (context) {
          return AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final t = controller.value;
              final x = startPos.dx + (endPos.dx - startPos.dx) * t;
              final y = startPos.dy + (endPos.dy - startPos.dy) * t;

              return Positioned(
                left: x,
                top: y,
                child: _buildChar(character, Colors.white, Color(0xFF6A3DE8)),
              );
            },
          );
        },
      );

      Overlay.of(context).insert(entry);

      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          entry.remove();
          setState(() {
            isInLowerArea[charIndex!] = true;
            occupiedLowerIndexes.remove(charIndex);
          });
        }
      });
    }
  }

  void _checkAnswer() {
    if (!upperBoxes.contains(null)) {
      final userAnswer = upperBoxes.join().toLowerCase().replaceAll(' ', '');
      final isCorrect = userAnswer == correctAnswer;
      setState(() {
        completed = true;
        correct = isCorrect;
      });

      widget.onCompleted(isCorrect, upperBoxes.join());
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
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
        child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          question,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                            width: 1.5,
                          ),
                        ),
                    child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(
                        upperBoxes.length,
                            (index) => GestureDetector(
                              onTap: () => moveCharacterDown(index),
                          child: Container(
                            key: upperBoxKeys[index],
                                width: 40,
                                height: 40,
                            decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF6A3DE8).withOpacity(0.25),
                                    width: 1.5,
                                  ),
                            ),
                            child: upperBoxes[index] != null
                                    ? _buildChar(upperBoxes[index]!, Colors.white, Color(0xFF6A3DE8))
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                      const SizedBox(height: 40),
                  Container(
                        padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                            width: 1.5,
                          ),
                    ),
                    child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(
                        pool.length,
                            (index) => GestureDetector(
                              onTap: () => moveCharacterUp(index),
                              child: Container(
                                key: characterKeys[pool[index] + index.toString()],
                          child: isInLowerArea[index]
                                    ? _buildChar(pool[index], Colors.white, Color(0xFF6A3DE8))
                                    : const SizedBox(width: 40, height: 40),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChar(String char, Color bgColor, Color textColor) {
    return Container(
      width: 40,
      height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6A3DE8).withOpacity(0.25),
          width: 1.5,
                            ),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        char,
        style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
          color: textColor,
          decoration: TextDecoration.none,
          height: 1.0,
        ),
      ),
    );
  }
}