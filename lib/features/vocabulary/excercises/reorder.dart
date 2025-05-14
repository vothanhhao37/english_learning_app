import 'package:flutter/material.dart';

import '../../common/custom_snackbar.dart';


class VocabReorderExercise extends StatefulWidget {
  final String topicId;
  final String wordId;
  final Map<String, dynamic> exerciseData;
  final void Function(bool isCorrect) onCompleted;

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

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePositions();
    });
  }

  void _loadData() {
    final data = widget.exerciseData;
    pool = List<String>.from(data['scrambled'] ?? []);
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
              child: _buildChar(character, Colors.green.shade300),
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
                child: _buildChar(character, Colors.blue.shade300),
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
      setState(() {
        completed = true;
        correct = userAnswer == correctAnswer;
      });

      showCustomSnackBar(
        context,
        correct,
        text: correct ? 'Chính xác!' : 'Sai rồi. Đáp án là: $correctAnswer',
      );
      widget.onCompleted(correct);
    }
  }

  Widget _buildChar(String char, Color color) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
          decoration: TextDecoration.none,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('📘 Hint: $question', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  Center(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: List.generate(
                        upperBoxes.length,
                            (index) => GestureDetector(
                          onTap: upperBoxes[index] != null ? () => moveCharacterDown(index) : null,
                          child: Container(
                            key: upperBoxKeys[index],
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue, width: 2),
                              borderRadius: BorderRadius.circular(8),
                              color: (upperBoxes[index] != null) ? Colors.blue.shade300 : Colors.white,
                            ),
                            child: upperBoxes[index] != null
                                ? Text(
                              upperBoxes[index]!,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: List.generate(
                        pool.length,
                            (index) => GestureDetector(
                          onTap: isInLowerArea[index] ? () => moveCharacterUp(index) : null,
                          child: isInLowerArea[index]
                              ? Container(
                            key: characterKeys[pool[index] + index.toString()],
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.green.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pool[index],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                              : const SizedBox(width: 40, height: 40),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}