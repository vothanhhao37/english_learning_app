import 'dart:math';
import 'package:flutter/cupertino.dart';

Widget buildAudioVisualizer({
  required List<double> levels,
  required List<Color> barColors,
}) {
  return Container(
    height: 180,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(12, (index) {
        final barHeight = max(10.0, levels[index] * 160 - 60);
        final color = barColors[index % barColors.length];
        final opacity = 0.6 + levels[index] * 0.4;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                width: 14,
                height: barHeight,
                decoration: BoxDecoration(
                  color: color.withOpacity(opacity),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(opacity * 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                width: 14,
                height: barHeight,
                decoration: BoxDecoration(
                  color: color.withOpacity(opacity),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(opacity * 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    ),
  );
}
