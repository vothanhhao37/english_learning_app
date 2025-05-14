import 'dart:async';
import 'package:flutter/material.dart';

import '../../common/audio_visuallizer.dart';


class SingleSentenceLesson extends StatefulWidget {
  final String sentence;
  final String correctTranscript;
  final String topicId;
  final String lessonId;
  final VoidCallback onNext;
  final Function(String) speakCallback;
  final Future<String> Function() startRecordingCallback;
  final Future<void> Function() stopRecordingCallback;
  final Future<String> Function(String) transcribeAudioCallback;
  final Future<void> Function(String) playAudioCallback;
  final List<String> Function(String, String) evaluatePronunciationCallback;
  final int Function(String, String) calculateScoreCallback;
  final Future<void> Function(String, String, String, int) saveSentenceScoreCallback;

  const SingleSentenceLesson({
    Key? key,
    required this.sentence,
    required this.correctTranscript,
    required this.topicId,
    required this.lessonId,
    required this.onNext,
    required this.speakCallback,
    required this.startRecordingCallback,
    required this.stopRecordingCallback,
    required this.transcribeAudioCallback,
    required this.playAudioCallback,
    required this.evaluatePronunciationCallback,
    required this.calculateScoreCallback,
    required this.saveSentenceScoreCallback,
  }) : super(key: key);

  @override
  State<SingleSentenceLesson> createState() => _SingleSentenceLessonState();
}

class _SingleSentenceLessonState extends State<SingleSentenceLesson> {
  static const double minCorrectThreshold = 0.5;

  String _spokenText = '';
  bool _isListening = false;
  bool _canContinue = false;
  String? _recordedPath;
  List<String> _resultWords = [];
  List<double> _audioLevels = List.filled(12, 0.0);
  Timer? _levelTimer;
  int _sessionHighestScore = 0;

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

  @override
  void initState() {
    super.initState();
    _speak();
  }

  Future<void> _speak() async {
    widget.speakCallback(widget.sentence);
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
    setState(() => _isListening = !_isListening);
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
    setState(() {
      _audioLevels = List.filled(12, 0.0);
    });

    if (_recordedPath != null) {
      try {
        final result = await widget.transcribeAudioCallback(_recordedPath!);
        setState(() => _spokenText = result);
        _checkResult();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi phân tích phát âm: $e')),
        );
      }
    }
  }

  void _checkResult() async {
    final resultWords = widget.evaluatePronunciationCallback(widget.correctTranscript, _spokenText);
    final score = widget.calculateScoreCallback(widget.correctTranscript, _spokenText);

    if (score > _sessionHighestScore) {
      _sessionHighestScore = score;
      await widget.saveSentenceScoreCallback(widget.lessonId, widget.correctTranscript, _spokenText, score);
    }

    setState(() {
      _resultWords = resultWords;
      _canContinue = _sessionHighestScore >= (minCorrectThreshold * 100);
    });

    if (score < (minCorrectThreshold * 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bạn cần đạt ít nhất ${(minCorrectThreshold * 100).toInt()}% để tiếp tục.')),
      );
    }
  }

  Future<void> _playUserAudio() async {
    if (_recordedPath != null) {
      widget.playAudioCallback(_recordedPath!);
    }
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.sentence, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _speak,
              icon: const Icon(Icons.volume_up),
              label: const Text('Nghe câu mẫu'),
            ),
            const SizedBox(width: 12),
            if (_recordedPath != null)
              ElevatedButton.icon(
                onPressed: _playUserAudio,
                icon: const Icon(Icons.replay),
                label: const Text("Nghe lại bạn nói"),
              ),
          ],
        ),
        const SizedBox(height: 16),
        buildAudioVisualizer(levels: _audioLevels, barColors: _barColors),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _isListening ? Colors.redAccent : Colors.blueAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _isListening ? Colors.redAccent.withOpacity(0.6) : Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(Icons.mic, size: 40, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_spokenText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Bạn đã nói: "$_spokenText"',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        Wrap(
          spacing: 8,
          children: _resultWords.map((word) {
            final isCorrect = word.startsWith('✔');
            return Chip(
              label: Text(word.substring(1)),
              backgroundColor: isCorrect ? Colors.green[200] : Colors.red[200],
            );
          }).toList(),
        ),
        if (_canContinue) ...[
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: widget.onNext,
            child: const Text("Tiếp tục"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ],
    );
  }
}