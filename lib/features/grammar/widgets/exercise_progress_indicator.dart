import 'package:flutter/material.dart';

class ExerciseProgressIndicator extends StatelessWidget {
  final int currentIndex;
  final int total;

  const ExerciseProgressIndicator({required this.currentIndex, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Câu ${currentIndex + 1}/$total',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (currentIndex + 1) / total,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}