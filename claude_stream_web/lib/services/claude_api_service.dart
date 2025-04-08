import 'dart:convert';
import 'dart:html'; // Solo Flutter Web
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ClaudeApiService {
  final String apiUrl;

  ClaudeApiService({String? apiUrl}) : apiUrl = apiUrl ?? AppConfig.apiBaseUrl;

  Future<EventSource> streamResponse({
    required String question,
    required bool extendedThinking,
    required int thinkingTokens,
    required void Function(String data) onChunk,
    required void Function() onDone,
    required void Function() onError,
  }) async {
    final encodedQuestion = Uri.encodeComponent(question);
    final streamUrl =
        '$apiUrl/stream?question=$encodedQuestion&thinking=$extendedThinking&tokens=$thinkingTokens';

    try {
      // Opción: quitar si no se necesita
      final postResponse = await http.post(
        Uri.parse('$apiUrl/stream'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': question,
          'thinking': extendedThinking,
          'tokens': thinkingTokens,
        }),
      );

      if (postResponse.statusCode != 200) {
        throw Exception("POST failed: ${postResponse.body}");
      }

      final eventSource = EventSource(streamUrl);

      eventSource.onOpen.listen((_) {
        print("✅ [ClaudeApiService] SSE connection opened");
      });

      eventSource.onMessage.listen((event) {
        final data = event.data ?? '';
        print(
            "📥 [ClaudeApiService] Chunk received: ${data.length > 60 ? data.substring(0, 60) + '...' : data}");
        onChunk(data);
      });

      eventSource.onError.listen((error) {
        print("❌ [ClaudeApiService] SSE error: $error");
        eventSource.close();
        onError();
      });

      return eventSource;
    } catch (e) {
      print("❌ [ClaudeApiService] Exception: $e");
      onError();
      rethrow;
    }
  }

  void closeStream(EventSource? eventSource) {
    print("🛑 [ClaudeApiService] Closing SSE connection");
    eventSource?.close();
  }
}
