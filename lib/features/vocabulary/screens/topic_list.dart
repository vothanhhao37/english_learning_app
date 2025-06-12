import 'package:flutter/material.dart';

import '../../../models/vocabulary_model.dart';
import '../widgets/topic_card.dart';
import 'topic_detail.dart';
import '../../../services/vocabulary_service.dart';

class VocabularyTopicListScreen extends StatefulWidget {
  const VocabularyTopicListScreen({super.key});

  @override
  State<VocabularyTopicListScreen> createState() => _VocabularyTopicListScreenState();
}

class _VocabularyTopicListScreenState extends State<VocabularyTopicListScreen> with TickerProviderStateMixin {
  final VocabularyService _service = VocabularyService();
  List<AnimationController> _controllers = [];
  List<Animation<double>> _scaleAnimations = [];
  List<Animation<double>> _fadeAnimations = [];

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
  }

  void _initializeAnimations() {
    _service.fetchTopics().first.then((topics) {
      setState(() {
        _controllers = List.generate(
          topics.length,
          (index) => AnimationController(
            duration: const Duration(milliseconds: 800),
            vsync: this,
          ),
        );

        _scaleAnimations = _controllers.map((controller) {
          return Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOut),
          );
        }).toList();

        _fadeAnimations = _controllers.map((controller) {
          return Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeIn),
          );
        }).toList();

        // Start animations with delay
        for (int i = 0; i < _controllers.length; i++) {
          Future.delayed(Duration(milliseconds: 70 * i), () {
            if (mounted) {
              _controllers[i].forward();
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298), Color(0xFF6B48FF)],
          ),
        ),
        child: StreamBuilder<List<VocabularyTopic>>(
          stream: _service.fetchTopics(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Không có chủ đề nào.'));
            }

            final topics = snapshot.data!;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
              itemCount: topics.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      'Danh sách chủ đề từ vựng',
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 8.0, color: Colors.black45, offset: Offset(0, 4)),
                        ],
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final topic = topics[index - 1];
                final animationIndex = index - 1;

                if (animationIndex >= _controllers.length) {
                  return const SizedBox.shrink();
                }

                return AnimatedBuilder(
                  animation: _controllers[animationIndex],
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimations[animationIndex].value,
                      child: Opacity(
                        opacity: _fadeAnimations[animationIndex].value,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VocabularyTopicDetailScreen(
                                  topicId: topic.id,
                                  title: topic.title,
                                ),
                              ),
                            );
                          },
                          child: VocabularyTopicCard(
                            title: topic.title,
                            description: topic.description,
                            imageUrl: topic.imageUrl,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}