import 'package:flutter/material.dart';
import '../excercises/grammar_drag_and_drop.dart';
import '../excercises/grammar_error_correction.dart';
import '../excercises/grammar_fill_in_blank.dart';
import '../excercises/grammar_multiple_choice.dart';
import '../excercises/grammar_rewrite.dart';


class GrammarExerciseScreen extends StatelessWidget {
  final String type;
  final String grammarId;
  const GrammarExerciseScreen({Key? key, required this.type, required this.grammarId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget exerciseWidget;

    switch (type) {
      case 'multiple_choice':
        exerciseWidget = GrammarMultipleChoiceExercises(grammarId: grammarId);
        break;
      case 'rewrite':
        exerciseWidget = GrammarRewriteExercises(grammarId: grammarId);
        break;
      case 'error_correction':
        exerciseWidget = GrammarErrorCorrectionExercises(grammarId: grammarId);
        break;
      case 'drag_and_drop':
        exerciseWidget = GrammarDragAndDropExercises(grammarId: grammarId);
        break;
      case 'fill_in_blank':
        exerciseWidget = GrammarFillInBlankExercises(grammarId: grammarId);
        break;
      default:
        exerciseWidget = const Center(
          child: Text('Loại bài tập chưa được hỗ trợ'),
        );
    }

    return Scaffold(
      body: exerciseWidget,
    );
  }
}