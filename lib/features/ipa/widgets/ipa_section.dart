import 'package:flutter/material.dart';

import 'ipa_subsection.dart';

class IPASection extends StatelessWidget {
  final String title;
  final List<IPASubsection> subsections;

  const IPASection({super.key, required this.title, required this.subsections});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3498DB), Color(0xFF8E44AD)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...subsections,
      ],
    );
  }
}