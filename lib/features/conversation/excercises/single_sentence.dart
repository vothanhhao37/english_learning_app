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

class _SingleSentenceLessonState extends State<SingleSentenceLesson> with SingleTickerProviderStateMixin {
  static const double minCorrectThreshold = 0.5;

  String _spokenText = '';
  bool _isListening = false;
  bool _canContinue = false;
  String? _recordedPath;
  List<String> _resultWords = [];
  List<double> _audioLevels = List.filled(12, 0.0);
  Timer? _levelTimer;
  int _sessionHighestScore = 0;

  late AnimationController _animController;
  late Animation<double> _micScaleAnim;

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
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _micScaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    widget.speakCallback(widget.sentence);
  }

  Future<void> _toggleListening() async {
    try {
    if (_isListening) {
        setState(() => _isListening = false);
      await _stopRecording();
        _animController.reverse();
    } else {
        setState(() => _isListening = true);
      await _startRecording();
        _animController.forward();
      }
    } catch (e) {
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi ghi âm: $e')),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
    _recordedPath = await widget.startRecordingCallback();
      _levelTimer?.cancel(); // Cancel any existing timer
      _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted) {
      setState(() {
        final randomLevel = (0.1 + 0.7 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000);
            _audioLevels = List.from(_audioLevels)..removeAt(_audioLevels.length - 1);
            _audioLevels.insert(0, randomLevel);
          });
        }
      });
    } catch (e) {
      _levelTimer?.cancel();
      rethrow;
    }
  }

  Future<void> _stopRecording() async {
    _levelTimer?.cancel();
    try {
    await widget.stopRecordingCallback();
      if (mounted) {
    setState(() {
      _audioLevels = List.filled(12, 0.0);
    });
      }

    if (_recordedPath != null) {
      try {
        final result = await widget.transcribeAudioCallback(_recordedPath!);
          if (mounted) {
        setState(() => _spokenText = result);
        _checkResult();
          }
      } catch (e) {
          if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi phân tích phát âm: $e')),
        );
      }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi dừng ghi âm: $e')),
        );
      }
      rethrow;
    }
  }

  void _checkResult() async {
    final resultWords = widget.evaluatePronunciationCallback(widget.correctTranscript, _spokenText);
    final score = widget.calculateScoreCallback(widget.correctTranscript, _spokenText);

    setState(() {
      _resultWords = resultWords;
      _canContinue = score >= (minCorrectThreshold * 100);
    });

    if (score > _sessionHighestScore) {
      _sessionHighestScore = score;
      await widget.saveSentenceScoreCallback(widget.lessonId, widget.correctTranscript, _spokenText, score);
    }

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mainColor = const Color(0xFF6C4EE3);
    final accentColor = const Color(0xFF3A2B71);
    final bgGradient = const LinearGradient(
      colors: [Color(0xFF3A2B71), Color(0xFF8A4EFC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: SingleChildScrollView(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.sentence,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _speak,
                  icon: const Icon(Icons.volume_up, color: Color(0xFF6C4EE3)),
              label: const Text('Nghe câu mẫu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: mainColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
            ),
            const SizedBox(width: 12),
            if (_recordedPath != null)
              ElevatedButton.icon(
                onPressed: _playUserAudio,
                    icon: const Icon(Icons.replay, color: Color(0xFF3A2B71)),
                label: const Text("Nghe lại bạn nói"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accentColor,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        buildAudioVisualizer(levels: _audioLevels, barColors: _barColors),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _toggleListening,
                child: ScaleTransition(
                  scale: _micScaleAnim,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
                    width: 110,
                    height: 110,
              decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isListening
                            ? [Colors.redAccent, Colors.pinkAccent]
                            : [mainColor, accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                          color: _isListening ? Colors.redAccent.withOpacity(0.3) : mainColor.withOpacity(0.25),
                          blurRadius: 18,
                    spreadRadius: 4,
                  ),
                ],
              ),
                    child: const Icon(
                      Icons.mic,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
            ),
          ),
        ),
            if (_spokenText.isNotEmpty) ...[
        const SizedBox(height: 16),
              Text(
              'Bạn đã nói: "$_spokenText"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  color: Colors.white70
                ),
              textAlign: TextAlign.center,
            ),
            ],
            const SizedBox(height: 12),
        Wrap(
          spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
          children: _resultWords.map((word) {
            final isCorrect = word.startsWith('✔');
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: Chip(
              label: Text(word.substring(1)),
                    backgroundColor: isCorrect ? Colors.green[300] : Colors.red[300],
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
            );
          }).toList(),
        ),
        if (_canContinue) ...[
          const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AnimatedOpacity(
                  opacity: _canContinue ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: ElevatedButton(
            onPressed: widget.onNext,
            child: const Text("Tiếp tục"),
            style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: accentColor,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
            ),
          ),
        ],
      ],
        ),
      ),
    );
  }
}