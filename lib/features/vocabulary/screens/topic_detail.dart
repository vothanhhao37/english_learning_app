import 'package:flutter/material.dart';

import '../../../services/vocabulary_service.dart';
import 'quiz.dart';
import '../../../models/vocabulary_model.dart';

class VocabularyTopicDetailScreen extends StatefulWidget {
  final String topicId;
  final String title;

  const VocabularyTopicDetailScreen({
    Key? key,
    required this.topicId,
    required this.title,
  }) : super(key: key);

  @override
  State<VocabularyTopicDetailScreen> createState() => _VocabularyTopicDetailScreenState();
}

class _VocabularyTopicDetailScreenState extends State<VocabularyTopicDetailScreen> {
  List<VocabWord> vocabItems = [];
  int currentWordIndex = 0;
  final PageController _pageController = PageController();
  bool loading = true;
  final VocabularyService _service = VocabularyService();

  @override
  void initState() {
    super.initState();
    _fetchWords();
  }

  Future<void> _fetchWords() async {
    final words = await _service.fetchWords(widget.topicId);
    setState(() {
      vocabItems = words;
      loading = false;
    });
  }

  void _goToQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VocabularyQuizScreen(topicId: widget.topicId, topicTitle: widget.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF8878E8),
        body: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF8878E8).withOpacity(0.9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9985F1),
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavButton(
                  onPressed: currentWordIndex > 0
                      ? () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut)
                      : null,
                  label: 'Trước',
                  icon: Icons.arrow_back_ios_rounded,
                  isForward: false,
                ),
                _buildNavButton(
                  onPressed: currentWordIndex < vocabItems.length - 1
                      ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut)
                      : null,
                  label: 'Sau',
                  icon: Icons.arrow_forward_ios_rounded,
                  isForward: true,
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: vocabItems.length,
              onPageChanged: (index) => setState(() => currentWordIndex = index),
              itemBuilder: (context, index) {
                final word = vocabItems[index];
                return _buildWordCard(word);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _goToQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9039CF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                minimumSize: const Size(double.infinity, 60),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'LUYỆN TẬP',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    required bool isForward,
  }) {
    final isDisabled = onPressed == null;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isForward ? const Color(0xFF4F7CFF) : const Color(0xFF6A6BB7),
        foregroundColor: Colors.white,
        elevation: isDisabled ? 0 : 3,
        disabledBackgroundColor: Colors.grey.withOpacity(0.3),
        disabledForegroundColor: Colors.grey.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isForward) Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          if (isForward) Icon(icon, size: 18),
        ],
      ),
    );
  }

  Widget _buildWordCard(VocabWord word) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3F3F7D), Color(0xFF262663)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF5B67CA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.word,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          word.ipa,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFFD6D6FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSpeakButton(word.word),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      icon: Icons.category,
                      label: 'Loại từ:',
                      content: word.type,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.search,
                      label: 'Nghĩa:',
                      content: word.meaning,
                      isImportant: true,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.chat_bubble_outline,
                      label: 'Ví dụ:',
                      content: '"${word.example}"',
                      isItalic: true,
                    ),
                    if (word.usage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.info_outline,
                        label: 'Cách dùng:',
                        content: word.usage,
                      ),
                    ],
                    Expanded(
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3F3F7D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5B67CA).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white70,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No image available',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildSpeakButton(String text) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF7884E0),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        iconSize: 32,
        padding: const EdgeInsets.all(12),
        onPressed: () => _service.speak(text),
        icon: const Icon(
          Icons.volume_up_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String content,
    bool isImportant = false,
    bool isItalic = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF5B67CA).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF94A0FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF94A0FF),
                  fontWeight: isImportant ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  fontSize: isImportant ? 18 : 16,
                  color: Colors.white,
                  fontWeight: isImportant ? FontWeight.w600 : FontWeight.normal,
                  fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _service.dispose();
    super.dispose();
  }
}