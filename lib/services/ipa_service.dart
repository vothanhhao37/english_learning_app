import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/ipa_pronunciation_model.dart';
import '../ultilities/firestore_utils.dart';


class IpaService {
  final FlutterTts _flutterTts = FlutterTts();
  final Map<int, AudioPlayer> _audioPlayers = {};

  IpaService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<List<Map<String, dynamic>>> loadLessons(String ipaId) async {
    try {
      final lessonTypes = ['audio_to_word', 'word_to_audio', 'match_ipa', 'speech_practice'];
      List<Map<String, dynamic>> allLessons = [];

      for (String type in lessonTypes) {
        final snapshot = await FirebaseFirestore.instance
            .collection('ipa_pronunciation')
            .doc(ipaId)
            .collection('lessons')
            .where('type', isEqualTo: type)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          bool isValid = true;
          if (type == 'audio_to_word' || type == 'word_to_audio' || type == 'match_ipa') {
            if (!data.containsKey('options') || !data.containsKey('correct_answer')) {
              isValid = false;
            }
          } else if (type == 'speech_practice') {
            if (!data.containsKey('word') || !data.containsKey('ipa')) {
              isValid = false;
            }
          }
          if (isValid) {
            allLessons.add({'id': doc.id, 'type': type, ...data});
          } else {
            print('Dữ liệu không hợp lệ cho bài tập $type: $data');
          }
        }
      }
      return allLessons;
    } catch (e) {
      throw Exception('Lỗi khi tải bài tập: $e');
    }
  }

  Future<IpaPronunciation?> fetchIpaData(String ipaId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('ipa_pronunciation')
          .doc(ipaId)
          .get();

      if (docSnapshot.exists) {
        return IpaPronunciation.fromMap(ipaId, docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      print('Lỗi khi tải dữ liệu IPA: $e');
      return null;
    }
  }

  Future<void> preloadAudio(int index, String ipaAudio, {bool play = false}) async {
    if (!_audioPlayers.containsKey(index)) {
      _audioPlayers[index] = AudioPlayer();
    }
    try {
      if (ipaAudio.isNotEmpty) {
        await _audioPlayers[index]!.setAsset('assets/audio/ipaSound/$ipaAudio', preload: true);
        if (play) {
          await _audioPlayers[index]!.play();
        }
      }
    } catch (e) {
      print('Lỗi khi tải hoặc phát âm thanh: $e');
    }
  }

  Future<void> playSound(String audioFileName) async {
    if (audioFileName.isEmpty) {
      print('Không có file âm thanh.');
      return;
    }

    final AudioPlayer player = AudioPlayer();
    try {
      final assetPath = 'assets/audio/ipaSound/$audioFileName';
      final audioBytes = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$audioFileName');

      await tempFile.writeAsBytes(audioBytes.buffer.asUint8List(
        audioBytes.offsetInBytes,
        audioBytes.lengthInBytes,
      ));

      await player.setFilePath(tempFile.path);
      await player.play();
      print('Đang phát âm: $audioFileName');
    } catch (e) {
      print('Lỗi khi phát âm thanh: $e');
    } finally {
      await player.dispose();
    }
  }

  Future<void> playWord(String word) async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.speak(word);
    } catch (e) {
      print('Lỗi khi phát từ: $e');
    }
  }

  Future<void> playQuizAudio(String word) async {
    try {
      await _flutterTts.speak(word);
    } catch (e) {
      print('Lỗi khi phát âm thanh: $e');
    }
  }

  Future<void> playCorrectSound() async {
    final player = AudioPlayer();
    try {
      await player.setAsset('assets/audio/correct.mp3');
      await player.play();
    } catch (e) {
      print('Lỗi khi phát âm đúng: $e');
    } finally {
      await player.dispose();
    }
  }

  Future<void> playIncorrectSound() async {
    final player = AudioPlayer();
    try {
      await player.setAsset('assets/audio/incorrect.mp3');
      await player.play();
    } catch (e) {
      print('Lỗi khi phát âm sai: $e');
    } finally {
      await player.dispose();
    }
  }

  void saveScore({
    required String ipaId,
    required String lessonId,
    required bool isCorrect,
    required String lessonType,
    required String userAnswer,
  }) {
    FirestoreUtils.saveIpaScore(
      ipaId: ipaId,
      lessonId: lessonId,
      isCorrect: isCorrect,
      lessonType: lessonType,
      userAnswer: userAnswer,
    );
  }

  void dispose() {
    _flutterTts.stop();
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
  }
}