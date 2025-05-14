import 'dart:async';
import 'package:flutter/material.dart';

import '../../common/audio_visuallizer.dart';


class DialogueLesson extends StatefulWidget {
  final String topicId;
  final String lessonId;
  final List<Map<String, String>> dialogue;
  final bool isLastLesson;
  final VoidCallback onNext;
  final VoidCallback onComplete;
  final Function(String) speakCallback;
  final Future<String> Function() startRecordingCallback;
  final Future<void> Function() stopRecordingCallback;
  final Future<String> Function(String) transcribeAudioCallback;
  final Future<void> Function(String) playAudioCallback;
  final List<String> Function(String, String) evaluatePronunciationCallback;
  final int Function(String, String) calculateScoreCallback;
  final Future<void> Function(String, List<Map<String, String>>, List<String>, Map<int, int>) saveDialogueScoreCallback;

  const DialogueLesson({
    Key? key,
    required this.topicId,
    required this.lessonId,
    required this.dialogue,
    required this.onNext,
    required this.onComplete,
    required this.isLastLesson,
    required this.speakCallback,
    required this.startRecordingCallback,
    required this.stopRecordingCallback,
    required this.transcribeAudioCallback,
    required this.playAudioCallback,
    required this.evaluatePronunciationCallback,
    required this.calculateScoreCallback,
    required this.saveDialogueScoreCallback,
  }) : super(key: key);

  @override
  State<DialogueLesson> createState() => _DialogueLessonState();
}

class _DialogueLessonState extends State<DialogueLesson> {
  static const double minCorrectThreshold = 0.5;

  final ScrollController _scrollController = ScrollController();
  final List<DialogueMessage> _messages = [];
  final List<double> _audioLevels = List.filled(12, 0.0);
  final List<Color> _barColors = [
    Colors.blue[400]!,
    Colors.red[400]!,
    Colors.yellow[600]!,
    Colors.green[400]!,
    Colors.blue[500]!,
    Colors.red[500]!,
    Colors.yellow[700]!,
    Colors.green[500]!,
    Colors.blue[600]!,
    Colors.red[600]!,
    Colors.yellow[800]!,
    Colors.green[600]!,
  ];

  int _currentIndex = 0;
  bool _isListening = false;
  String? _recordedPath;
  Map<int, int> _highestScores = {};
  List<String> _spokenTexts = [];
  Timer? _levelTimer;

  @override
  void initState() {
    super.initState();
    _initMessages();
    _speak(widget.dialogue[0]['question']!);
    _spokenTexts = List.filled(widget.dialogue.length, '');
  }

  void _initMessages() {
    for (int i = 0; i < widget.dialogue.length; i++) {
      final pair = widget.dialogue[i];
      _messages.add(DialogueMessage(index: i, text: pair['question']!, isBot: true));
      _messages.add(DialogueMessage(index: i, text: pair['answer']!, isBot: false));
    }
  }

  Future<void> _speak(String text) async {
    widget.speakCallback(text);
  }

  Future<void> _startRecording() async {
    _recordedPath = await widget.startRecordingCallback();
    _levelTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        final randomLevel = (0.1 + 0.7 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000);
        for (int i = _audioLevels.length - 1; i > 0; i--) {
          _audioLevels[i] = _audioLevels[i - 1];
        }
        _audioLevels[0] = randomLevel;
      });
    });
  }

  Future<void> _stopRecording() async {
    _levelTimer?.cancel();
    await widget.stopRecordingCallback();
    setState(() => _audioLevels.fillRange(0, _audioLevels.length, 0));

    if (_recordedPath != null) {
      final result = await widget.transcribeAudioCallback(_recordedPath!);
      _evaluate(result);
    }
  }

  void _evaluate(String spoken) async {
    final correct = widget.dialogue[_currentIndex]['answer'] ?? '';
    _spokenTexts[_currentIndex] = spoken;

    final resultWords = widget.evaluatePronunciationCallback(correct, spoken);
    final score = widget.calculateScoreCallback(correct, spoken);

    final prevScore = _highestScores[_currentIndex] ?? 0;
    if (score > prevScore) {
      _highestScores[_currentIndex] = score;
      await widget.saveDialogueScoreCallback(widget.lessonId, widget.dialogue, _spokenTexts, Map<int, int>.from(_highestScores));
    }

    setState(() {
      _messages[_currentIndex * 2 + 1] = DialogueMessage(
        index: _currentIndex,
        text: correct,
        isBot: false,
        spokenText: spoken,
        resultWords: resultWords,
        score: score,
      );
    });

    if ((_highestScores[_currentIndex] ?? 0) < (minCorrectThreshold * 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bạn cần đạt ít nhất ${(minCorrectThreshold * 100).toInt()}% để tiếp tục.")),
      );
    }
  }

  Future<void> _playUserAudio() async {
    if (_recordedPath != null) {
      widget.playAudioCallback(_recordedPath!);
    }
  }

  void _next() {
    if (_currentIndex < widget.dialogue.length - 1) {
      setState(() {
        _currentIndex++;
        _recordedPath = null;
      });
      _speak(widget.dialogue[_currentIndex]['question']!);
      _scrollToEnd();
    } else {
      widget.isLastLesson ? widget.onComplete() : widget.onNext();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentScore = _highestScores[_currentIndex] ?? 0;
    final canContinue = currentScore >= (minCorrectThreshold * 100);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.all(16),
            itemCount: (_currentIndex + 1) * 2,
            itemBuilder: (context, index) {
              final m = _messages[index];
              final isUser = !m.isBot;
              final isCurrentPair = index ~/ 2 == _currentIndex;

              if (index ~/ 2 > _currentIndex) return SizedBox.shrink();

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isUser && isCurrentPair && index == _currentIndex * 2 + 1)
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.volume_up, size: 24),
                              onPressed: () => _speak(m.text),
                              padding: EdgeInsets.zero,
                            ),
                            if (m.resultWords.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.play_arrow, size: 24),
                                onPressed: _playUserAudio,
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ),
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.grey[200] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (m.spokenText != null)
                            Text('Bạn đã nói: "${m.spokenText}"', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(m.text),
                          if (m.resultWords.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: m.resultWords.map((word) {
                                final isCorrect = word.startsWith('✔');
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCorrect ? Colors.green[100] : Colors.red[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(word.substring(1),
                                      style: TextStyle(color: isCorrect ? Colors.green[800] : Colors.red[800])),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    if (!isUser && isCurrentPair && index == _currentIndex * 2)
                      IconButton(
                        icon: Icon(Icons.volume_up, size: 24),
                        onPressed: () => _speak(m.text),
                        padding: EdgeInsets.all(8),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        buildAudioVisualizer(levels: _audioLevels, barColors: _barColors),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            if (_isListening) {
              await _stopRecording();
            } else {
              await _startRecording();
            }
            setState(() => _isListening = !_isListening);
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _isListening ? Colors.redAccent : Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 12),
        if (canContinue)
          ElevatedButton(
            onPressed: _next,
            child: Text(_currentIndex == widget.dialogue.length - 1 ? 'Hoàn thành' : 'Tiếp tục'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class DialogueMessage {
  final int index;
  final String text;
  final bool isBot;
  final String? spokenText;
  final List<String> resultWords;
  final int? score;

  DialogueMessage({
    required this.index,
    required this.text,
    required this.isBot,
    this.spokenText,
    this.resultWords = const [],
    this.score,
  });
}