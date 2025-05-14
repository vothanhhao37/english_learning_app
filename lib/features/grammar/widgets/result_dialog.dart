import 'package:flutter/material.dart';
import '../../common/constants.dart';

class ResultDialog extends StatelessWidget {
  final int correctAnswers;
  final int totalQuestions;
  final VoidCallback onRestart;

  const ResultDialog({
    required this.correctAnswers,
    required this.totalQuestions,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppConstants.primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Kết quả',
        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 40,
            child: Text(
              '${(correctAnswers / totalQuestions * 100).toInt()}%',
              style: TextStyle(
                color: AppConstants.primaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bạn đã trả lời đúng $correctAnswers/$totalQuestions câu hỏi',
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        Center(
          child: ElevatedButton(
            onPressed: onRestart,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            ),
            child: const Text(
              'Làm lại',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}