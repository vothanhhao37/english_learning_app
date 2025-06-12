import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/conversation_pronunciation_model.dart';
import '../../../services/conversation_pronunciation_service.dart';
import '../excercises/dialogue_lesson.dart';
import '../excercises/single_sentence.dart';
import '../../../services/profile_service.dart';


class ConversationTopicDetailScreen extends StatefulWidget {
  final String topicId;
  final String topicName;

  const ConversationTopicDetailScreen({
    Key? key,
    required this.topicId,
    required this.topicName,
  }) : super(key: key);

  @override
  State<ConversationTopicDetailScreen> createState() => _ConversationTopicDetailScreenState();
}

class _ConversationTopicDetailScreenState extends State<ConversationTopicDetailScreen> {
  List<ConversationLesson> lessons = [];
  int currentIndex = 0;
  bool isLoading = true;
  bool needsTopicUpdate = false;
  final ConversationPronunciationService _service = ConversationPronunciationService();

  @override
  void initState() {
    super.initState();
    _service.initializeAudio();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      lessons = await _service.loadLessons(widget.topicId);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _service.initializeNewTopicSummary(uid, widget.topicId, widget.topicName, lessons.length);
      }
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onNextLesson() {
    if (currentIndex < lessons.length - 1) {
      setState(() {
        currentIndex++;
      });
    } else {
      // Đã hoàn thành tất cả bài học, invalidate cache Conversation
      if (needsTopicUpdate) {
         ProfileService().invalidateConversationCache();
      }
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("🎉 Hoàn thành!"),
            content: Text("Bạn đã hoàn thành toàn bộ chủ đề \"${widget.topicName}\"!"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Quay về"),
              ),
            ],
          );
        },
      );
    }
  }

  double get progress => lessons.isEmpty ? 0 : (currentIndex + 1) / lessons.length;

  @override
  void dispose() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // Invalidate cache Conversation khi thoát màn hình nếu có cập nhật
    if (uid != null && needsTopicUpdate) {
       ProfileService().invalidateConversationCache();
    }
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3A2B71),
      appBar: AppBar(
        title: Text(
          widget.topicName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF3A2B71),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.amber),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : lessons.isEmpty
            ? const Center(
                child: Text(
                  "Chưa có bài học nào 🙁",
                  style: TextStyle(color: Colors.white),
                ))
            : Expanded(
                child: Builder(
                  builder: (_) {
                    final lesson = lessons[currentIndex];
                    if (lesson.type == 'sentence' || lesson.type == 'single_sentence') {
                      return SingleSentenceLesson(
                        key: ValueKey(lesson.id),
                        sentence: lesson.sentence ?? '',
                        correctTranscript: lesson.sentence ?? '',
                        topicId: widget.topicId,
                        lessonId: lesson.id,
                        onNext: _onNextLesson,
                        speakCallback: _service.speak,
                        startRecordingCallback: _service.startRecording,
                        stopRecordingCallback: _service.stopRecording,
                        transcribeAudioCallback: _service.transcribeAudio,
                        playAudioCallback: _service.playAudio,
                        evaluatePronunciationCallback: _service.evaluatePronunciation,
                        calculateScoreCallback: _service.calculateScore,
                        saveSentenceScoreCallback: (lessonId, text, spokenText, score) async {
                          await _service.saveSentenceScore(widget.topicId, lessonId, text, spokenText, score);
                          needsTopicUpdate = true;
                        },
                      );
                    } else if (lesson.type == 'dialogue') {
                      return DialogueLesson(
                        key: ValueKey(lesson.id),
                        dialogue: lesson.dialogue ?? [],
                        topicId: widget.topicId,
                        lessonId: lesson.id,
                        onNext: _onNextLesson,
                        onComplete: () => Navigator.pop(context),
                        isLastLesson: currentIndex == lessons.length - 1,
                        speakCallback: _service.speak,
                        startRecordingCallback: _service.startRecording,
                        stopRecordingCallback: _service.stopRecording,
                        transcribeAudioCallback: _service.transcribeAudio,
                        playAudioCallback: _service.playAudio,
                        evaluatePronunciationCallback: _service.evaluatePronunciation,
                        calculateScoreCallback: _service.calculateScore,
                        saveDialogueScoreCallback: (lessonId, dialogue, spokenTexts, scores) async {
                          await _service.saveDialogueScore(widget.topicId, lessonId, dialogue, spokenTexts, scores);
                          needsTopicUpdate = true;
                        },
                      );
                    } else {
                      return const Center(
                        child: Text(
                          "Không rõ loại bài học 😕",
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }
                  },
                ),
              ),
      ),
    );
  }
}