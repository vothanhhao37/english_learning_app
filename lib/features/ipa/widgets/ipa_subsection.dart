import 'package:flutter/material.dart';

import 'ipa_item.dart';

class IPASubsection extends StatelessWidget {
  final String title;
  final List<IPAItem> items;

  const IPASubsection({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 10, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFFE0E0E0),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}