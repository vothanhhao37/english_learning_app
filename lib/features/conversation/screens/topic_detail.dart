import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/conversation_pronunciation_model.dart';
import '../../../services/conversation_pronunciation_service.dart';
import '../excercises/dialogue_lesson.dart';
import '../excercises/single_sentence.dart';


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
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      lessons = await _service.loadLessons(widget.topicId);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _service.initializeTopicData(uid, widget.topicId, widget.topicName, lessons.length);
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
    if (uid != null && needsTopicUpdate) {
      _service.updateTopic(uid, widget.topicId, lessons.length, lessons.length);
    }
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topicName),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
            minHeight: 4,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : lessons.isEmpty
          ? const Center(child: Text("Chưa có bài học nào 🙁"))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lessons[currentIndex].title ?? 'Bài học ${currentIndex + 1}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
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
                        if (score >= 50) {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null) {
                            await _service.updateTopic(uid, widget.topicId, lessons.length, currentIndex + 1);
                          }
                        }
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
                        final isCompleted = scores.values.every((score) => score >= 50);
                        if (isCompleted) {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null) {
                            await _service.updateTopic(uid, widget.topicId, lessons.length, currentIndex + 1);
                          }
                        }
                      },
                    );
                  } else {
                    return const Center(child: Text("Không rõ loại bài học 😕"));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}