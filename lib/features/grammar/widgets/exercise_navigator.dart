import 'package:flutter/material.dart';

import '../excercises/drag_and_drop.dart';
import '../excercises/error_correction.dart';
import '../excercises/fill_in_blank.dart';
import '../excercises/multiple_choice.dart';
import '../excercises/rewrite.dart';


class GrammarExerciseScreen extends StatelessWidget {
  final String type;
  final String grammarId;
  const GrammarExerciseScreen({Key? key, required this.type, required this.grammarId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget exerciseWidget;

    switch (type) {
      case 'multiple_choice':
        exerciseWidget = MultipleChoiceExercises(grammarId: grammarId);
        break;
      case 'rewrite':
        exerciseWidget = RewriteExercises(grammarId: grammarId);
        break;
      case 'error_correction':
        exerciseWidget = ErrorCorrectionExercises(grammarId: grammarId);
        break;
      case 'drag_and_drop':
        exerciseWidget = DragAndDropExercises(grammarId: grammarId);
        break;
      case 'fill_in_blank':
        exerciseWidget = FillInBlankExercises(grammarId: grammarId);
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