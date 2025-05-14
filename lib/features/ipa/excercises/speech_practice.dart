import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../../services/ipa_service.dart';
import '../../../services/whisper_api_service.dart';
import '../../common/audio_visuallizer.dart';
import '../../common/loading_widget.dart';

class IpaSpeechPractice extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final void Function(bool, String) onAnswer;

  const IpaSpeechPractice({
    Key? key,
    required this.lesson,
    required this.onAnswer,
  }) : super(key: key);

  @override
  State<IpaSpeechPractice> createState() => _IpaSpeechPracticeState();
}

class _IpaSpeechPracticeState extends State<IpaSpeechPractice> with TickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final WhisperService _whisperService = WhisperService();
  final IpaService _ipaService = IpaService();

  late AnimationController _appearController;
  late Animation<double> _appearAnimation;

  bool isPlaying = false;
  bool isRecording = false;
  bool isProcessingResult = false;
  bool hasAnswered = false;
  bool isCorrect = false;
  bool hasError = false;
  String? recordedPath;
  String spokenText = '';
  String errorMessage = '';
  bool isRecorderInitialized = false;

  List<double> _audioLevels = List.filled(8, 0.0);
  Timer? _silenceTimer;
  double _maxLevel = 0.0;
  final List<Color> _barColors = [
    Colors.blue[400]!,
    Colors.red[400]!,
    Colors.yellow[600]!,
    Colors.green[400]!,
    Colors.blue[500]!,
    Colors.red[500]!,
    Colors.yellow[700]!,
    Colors.green[500]!,
  ];

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _setupAnimations();
  }

  void _setupAnimations() {
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _appearAnimation = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOut,
    );
    _appearController.forward();
  }

  Future<void> _initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần quyền truy cập microphone để luyện phát âm')),
        );
        return;
      }

      await _recorder.openRecorder();
      _recorder.setSubscriptionDuration(const Duration(milliseconds: 50));

      setState(() {
        isRecorderInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing recorder: $e');
    }
  }

  Future<void> _playTargetWord() async {
    if (isPlaying || isRecording) return;

    setState(() {
      isPlaying = true;
    });

    try {
      final word = widget.lesson['word'] ?? '';
      await _ipaService.playWord(word);
      await Future.delayed(const Duration(milliseconds: 1500));
      setState(() {
        isPlaying = false;
      });
    } catch (e) {
      setState(() {
        isPlaying = false;
      });
      debugPrint('Error playing target word: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (!isRecorderInitialized) {
      await _initRecorder();
      if (!isRecorderInitialized) return;
    }

    if (isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (isPlaying) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/ipa_record_${DateTime.now().millisecondsSinceEpoch}.aac';

    try {
      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.aacADTS,
      );

      setState(() {
        isRecording = true;
        recordedPath = path;
        spokenText = '';
        hasError = false;
        errorMessage = '';
        _audioLevels = List.filled(12, 0.0);
      });

      _recorder.onProgress!.listen((event) {
        if (!mounted) return;
        final level = (event.decibels ?? 0.0).abs() / 100;
        _processAudioLevel(level);
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      setState(() {
        hasError = true;
        errorMessage = 'Không thể bắt đầu ghi âm';
      });
    }
  }

  void _processAudioLevel(double level) {
    if (!mounted) return;

    if (level > _maxLevel) _maxLevel = level;

    setState(() {
      for (int i = _audioLevels.length - 1; i > 0; i--) {
        _audioLevels[i] = _audioLevels[i - 1];
      }
      _audioLevels[0] = level;
    });

    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && isRecording) {
        setState(() {
          for (int i = 0; i < _audioLevels.length; i++) {
            _audioLevels[i] = math.max(0.0, _audioLevels[i] * 0.9);
          }
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!isRecording) return;

    _silenceTimer?.cancel();

    try {
      await _recorder.stopRecorder();

      setState(() {
        isRecording = false;
        isProcessingResult = true;
        _audioLevels = List.filled(12, 0.0);
      });

      await _analyzeAudioWithWhisper();
    } catch (e) {
      setState(() {
        isRecording = false;
        isProcessingResult = false;
        hasError = true;
        errorMessage = 'Đã có lỗi, không thể phân tích giọng nói của bạn';
        hasAnswered = true;
        isCorrect = false;
      });
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _analyzeAudioWithWhisper() async {
    if (recordedPath == null) {
      setState(() {
        isProcessingResult = false;
        hasError = true;
        errorMessage = "Không thể phân tích bản ghi âm";
        hasAnswered = true;
        isCorrect = false;
      });
      _ipaService.playIncorrectSound();
      return;
    }

    try {
      print("Gọi API với file: $recordedPath");
      final transcribedText = await _whisperService.transcribeAudio(recordedPath!);
      print("Kết quả từ API: '$transcribedText'");

      if (transcribedText.isEmpty) {
        print("API trả về kết quả trống");
        setState(() {
          isProcessingResult = false;
          hasError = true;
          errorMessage = "Không nhận diện được giọng nói";
          hasAnswered = true;
          isCorrect = false;
        });
        _ipaService.playIncorrectSound();
        return;
      }

      final targetWord = widget.lesson['word']?.toString().toLowerCase() ?? '';
      final processedTarget = _preprocessText(targetWord);
      final processedTranscribed = _preprocessText(transcribedText);

      print("So sánh: '$processedTarget' với '$processedTranscribed'");
      isCorrect = processedTranscribed.contains(processedTarget);
      print("Kết quả so sánh: $isCorrect");

      setState(() {
        spokenText = transcribedText;
        isProcessingResult = false;
        hasAnswered = true;
        hasError = false;
      });

      if (isCorrect) {
        _ipaService.playCorrectSound();
      } else {
        _ipaService.playIncorrectSound();
      }
    } catch (e) {
      print("Lỗi khi gọi Whisper API: $e");
      setState(() {
        isProcessingResult = false;
        hasError = true;
        errorMessage = "Đã có lỗi, không thể phân tích giọng nói của bạn";
        hasAnswered = true;
        isCorrect = false;
      });
      _ipaService.playIncorrectSound();
    }
  }

  String _preprocessText(String text) {
    String processed = text.toLowerCase();
    processed = processed.replaceAll(RegExp(r'[^\w\s]'), '');
    processed = processed.trim();
    return processed;
  }

  void _continueToNextQuestion() {
    if (hasAnswered) {
      widget.onAnswer(isCorrect, widget.lesson['type']);
    }
  }

  @override
  void dispose() {
    _appearController.dispose();
    if (isRecording) {
      _recorder.stopRecorder().then((_) {
        _recorder.closeRecorder();
      });
    } else {
      _recorder.closeRecorder();
    }
    _silenceTimer?.cancel();
    _ipaService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.lesson['word'] ?? '';
    final ipa = widget.lesson['ipa'] ?? '';

    return FadeTransition(
      opacity: _appearAnimation,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6A3DE8), Color(0xFF5035BE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTargetWordCard(word, ipa),
              const SizedBox(height: 16),
              Expanded(
                child: _buildRecordingArea(),
              ),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetWordCard(String word, String ipa) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF5D43CC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'Phát âm từ sau:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    word,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5035BE),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: isPlaying || isRecording ? null : _playTargetWord,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isPlaying
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Color(0xFF5035BE),
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.volume_up,
                        color: Color(0xFF5035BE),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (ipa.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  '/$ipa/',
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF5D43CC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Expanded(
              child: _buildRecordingContent(),
            ),
            if (hasAnswered && (hasError || spokenText.isNotEmpty)) _buildResultArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingContent() {
    if (isProcessingResult) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildLoadingIndicator(),
            const SizedBox(height: 16),
          ],
        ),
      );
    } else if (isRecording) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          buildAudioVisualizer(
            levels: _audioLevels,
            barColors: _barColors,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.stop,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nhấn để dừng ghi âm',
            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else if (!hasAnswered) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mic_none,
              size: 70,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nhấn nút micro để bắt đầu ghi âm',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            hasError
                ? Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade600,
            )
                : isCorrect
                ? Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade600,
            )
                : Icon(
              Icons.cancel_outlined,
              size: 64,
              color: Colors.red.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              hasError
                  ? 'Đã có lỗi xảy ra'
                  : isCorrect
                  ? 'Phát âm chính xác!'
                  : 'Phát âm chưa chính xác',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: hasError
                    ? Colors.red.shade600
                    : isCorrect
                    ? Colors.green.shade600
                    : Colors.red.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildResultArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasError
            ? const Color(0xFFFFF3E0)
            : (isCorrect ? const Color(0xFFE0F2F1) : const Color(0xFFFBE9E7)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: hasError
                ? Colors.orange.shade200
                : (isCorrect ? Colors.teal.shade200 : Colors.red.shade200),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn đã nói:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasError ? errorMessage : spokenText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: hasError
                  ? Colors.red.shade700
                  : isCorrect
                  ? Colors.teal.shade700
                  : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: hasAnswered ? _continueToNextQuestion : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasAnswered ? Colors.amber : Colors.grey.shade400,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tiếp tục',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward,
              color: Colors.black87,
            ),
          ],
        ),
      ),
    );
  }
}