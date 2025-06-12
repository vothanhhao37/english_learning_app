
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class WhisperService {
  static const String _baseUrl = "http://172.16.2.139:8000";

  final String apiUrl;

  // Constructor với URL tùy chọn (mặc định sẽ dùng _baseUrl)
  WhisperService({String? customUrl})
      : apiUrl = customUrl ?? _baseUrl;

  Future<String> transcribeAudio(String filePath) async {
    try {
      final uri = Uri.parse("$apiUrl/transcribe");
      final request = http.MultipartRequest("POST", uri)
        ..files.add(await http.MultipartFile.fromPath(
          'audio',
          filePath,
          contentType: MediaType('audio', 'aac'),
        ));

      final response = await request.send();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final text = RegExp(r'"text":\s*"(.*?)"').firstMatch(body)?.group(1);

        return text ?? '';

      } else {
        throw Exception("Whisper API error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error calling Whisper API: $e");
      throw Exception("Failed to transcribe audio: $e");
    }
  }
}