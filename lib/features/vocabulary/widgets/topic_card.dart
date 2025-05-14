import 'package:flutter/material.dart';

class VocabularyTopicCard extends StatelessWidget {
  final String title;
  final String description;
  final String imageUrl;

  const VocabularyTopicCard({
    super.key,
    required this.title,
    required this.description,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final String assetPath = 'assets/images/vocab_topic/$imageUrl';
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 200,
      width: MediaQuery.of(context).size.width - 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isNotEmpty
                ? Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300]!.withValues(alpha: 0.7),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 50,
                    ),
                  ),
                );
              },
            )
                : Container(
              color: Colors.grey[300]!.withOpacity(0.7),
              child: const Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.grey,
                  size: 50,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
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
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFDCDCDC),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}