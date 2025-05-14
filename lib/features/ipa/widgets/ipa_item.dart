import 'package:flutter/material.dart';

import '../../../services/ipa_service.dart';
import '../screens/ipa_detail.dart';

class IPAItem extends StatelessWidget {
  final String ipaId;
  final String example;
  final String ipaType;
  final String ipaAudio;
  final List<String> allIpaIds;
  final AnimationController animationController;

  const IPAItem({
    super.key,
    required this.ipaId,
    required this.example,
    required this.ipaType,
    required this.ipaAudio,
    required this.animationController,
    required this.allIpaIds,
  });

  @override
  Widget build(BuildContext context) {
    final word = example.isNotEmpty ? example.split(' ')[0] : ipaId;
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        final scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeOut,
          ),
        );
        final opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeOut,
          ),
        );

        return Transform.scale(
          scale: scaleAnimation.value,
          child: Opacity(
            opacity: opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(38, 255, 255, 255),
              Color.fromARGB(13, 255, 255, 255),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IpaDetailScreen(
                        ipaId: ipaId,
                        allIpaIds: allIpaIds,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ipaId,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF00B7EB),
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 2,
                            color: Colors.black26,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      example,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFDCDCDC),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => IpaService().playSound(ipaAudio),
                  tooltip: 'Phát âm $ipaId',
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF3498DB), Color(0xFF8E44AD)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.volume_up,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => IpaService().playWord(word),
                  tooltip: "Phát từ '$word'",
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF3498DB), Color(0xFF8E44AD)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}