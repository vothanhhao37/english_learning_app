import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'topic_detail.dart';

class ConversationTopicListScreen extends StatefulWidget {
  const ConversationTopicListScreen({Key? key}) : super(key: key);

  @override
  State<ConversationTopicListScreen> createState() => _ConversationTopicListScreenState();
}

class _ConversationTopicListScreenState extends State<ConversationTopicListScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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
                stream: FirebaseFirestore.instance.collection('conversation').snapshots(),
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
                          animation: _controller,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Opacity(
                                opacity: _fadeAnimation.value,
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
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Background Image
                                        imageUrl.isNotEmpty
                                            ? Image.asset(
                                                'assets/images/conversation/$imageUrl',
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _placeholderImage(),
                                              )
                                            : _placeholderImage(),
                                        // Semi-transparent overlay for text area
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 80,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Colors.black.withOpacity(0.4),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Content
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  shadows: [
                                                    Shadow(
                                                      blurRadius: 6,
                                                      color: Colors.black,
                                                      offset: Offset(0, 2),
                                                    ),
                                                    Shadow(
                                                      blurRadius: 6,
                                                      color: Colors.black,
                                                      offset: Offset(0, -2),
                                                    ),
                                                    Shadow(
                                                      blurRadius: 6,
                                                      color: Colors.black,
                                                      offset: Offset(2, 0),
                                                    ),
                                                    Shadow(
                                                      blurRadius: 6,
                                                      color: Colors.black,
                                                      offset: Offset(-2, 0),
                                                    ),
                                                  ],
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                description,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontStyle: FontStyle.italic,
                                                  shadows: [
                                                    Shadow(
                                                      blurRadius: 6,
                                                      color: Colors.black,
                                                      offset: Offset(0, 2),
                                                    ),
                                                    Shadow(
                                                      blurRadius: 6,
                                                      color: Colors.black,
                                                      offset: Offset(0, -2),
                                                    ),
                                                    Shadow(
                                                      blurRadius: 6,
                                                      color: Colors.black,
                                                      offset: Offset(2, 0),
                                                    ),
                                                    Shadow(
                                                      blurRadius: 6,
                                                      color: Colors.black,
                                                      offset: Offset(-2, 0),
                                                    ),
                                                  ],
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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