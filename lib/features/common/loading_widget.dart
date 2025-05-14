import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';

Widget buildLoadingIndicator() {
  return const Center(
    child: SizedBox(
      width: 100,
      height: 60,
      child: LoadingIndicator(
        indicatorType: Indicator.lineScalePulseOutRapid, // Loại thứ 31
        colors: [
          Colors.green,
          Colors.red,
          Colors.yellow,
          Colors.blue,
          Colors.white
        ],
        strokeWidth: 2,
        backgroundColor: Colors.transparent,
        pathBackgroundColor: Colors.black,
      ),
    ),
  );
}
