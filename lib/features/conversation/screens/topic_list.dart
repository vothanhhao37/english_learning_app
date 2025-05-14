import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'topic_detail.dart';

class ConversationTopicListScreen extends StatefulWidget {
  const ConversationTopicListScreen({Key? key}) : super(key: key);

  @override
  State<ConversationTopicListScreen> createState() => _ConversationTopicListScreenState();
}

class _ConversationTopicListScreenState extends State<ConversationTopicListScreen> with TickerProviderStateMixin {
  final Map<int, AnimationController> _animationControllers = {};

  @override
  void dispose() {
    for (var controller in _animationControllers.values) {
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('pronunciation_topics').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Đã có lỗi xảy ra.'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('Chưa có chủ đề nào.'));
                  }

                  for (int i = 0; i < docs.length; i++) {
                    if (!_animationControllers.containsKey(i)) {
                      _animationControllers[i] = AnimationController(
                        vsync: this,
                        duration: const Duration(milliseconds: 600),
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Future.delayed(Duration(milliseconds: i * 100), () {
                          if (mounted && _animationControllers[i] != null && !_animationControllers[i]!.isAnimating) {
                            _animationControllers[i]!.forward(from: 0.0);
                          }
                        });
                      });
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 3 / 4,
                      ),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final title = data['title'] ?? '';
                        final description = data['description'] ?? '';
                        final imageUrl = data['imageUrl'] ?? '';

                        return AnimatedBuilder(
                          animation: _animationControllers[index]!,
                          builder: (context, child) {
                            final scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _animationControllers[index]!,
                                curve: Curves.easeOut,
                              ),
                            );
                            final opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _animationControllers[index]!,
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
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ConversationTopicDetailScreen(
                                    topicId: docs[index].id,
                                    topicName: title,
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                              clipBehavior: Clip.hardEdge,
                              child: Container(
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, progress) => progress == null
                                            ? child
                                            : Center(
                                          child: CircularProgressIndicator(
                                            value: progress.expectedTotalBytes != null
                                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                        errorBuilder: (_, __, ___) => _placeholderImage(),
                                      )
                                          : _placeholderImage(),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF00B7EB),
                                          shadows: [
                                            Shadow(
                                              blurRadius: 2,
                                              color: Colors.black26,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text(
                                        description,
                                        style: const TextStyle(
                                          color: Color(0xFFDCDCDC),
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Text(
            'CHỦ ĐỀ PHÁT ÂM HỘI THOẠI',
            style: TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: 8.0,
                  color: Colors.black45,
                  offset: Offset(0, 4),
                ),
              ],
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 32,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Text(
              "Khám phá các chủ đề phát âm tiếng Anh thú vị",
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(
        Icons.image_not_supported,
        size: 48,
        color: Colors.grey,
      ),
    );
  }
}