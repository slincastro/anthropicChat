import 'dart:convert';
import 'dart:html' as html; // Solo Flutter Web
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../components/claude_drop_zone.dart';

class ClaudeApiService {
  final String apiUrl;

  ClaudeApiService({String? apiUrl}) : apiUrl = apiUrl ?? AppConfig.apiBaseUrl;

  Future<html.EventSource> streamResponse({
    required String question,
    required bool extendedThinking,
    required int thinkingTokens,
    required List<UploadedFile> files,
    required void Function(String data) onChunk,
    required void Function() onDone,
    required void Function() onError,
  }) async {
    final encodedQuestion = Uri.encodeComponent(question);
    final streamUrl =
        '$apiUrl/stream?question=$encodedQuestion&thinking=$extendedThinking&tokens=$thinkingTokens';

    try {
      // If we have files, use POST request with multipart/form-data
      if (files.isNotEmpty) {
        // Create multipart request for file uploads
        final request =
            http.MultipartRequest('POST', Uri.parse('$apiUrl/stream'));

        // Add text fields
        request.fields['question'] = question;
        request.fields['thinking'] = extendedThinking.toString();
        request.fields['tokens'] = thinkingTokens.toString();

        // Add files
        for (var i = 0; i < files.length; i++) {
          final file = files[i];
          if (file.base64Data != null) {
            final bytes = base64Decode(file.base64Data!);
            final multipartFile = http.MultipartFile.fromBytes(
              'file_$i',
              bytes,
              filename: file.name,
            );
            request.files.add(multipartFile);
          }
        }

        // Send the request
        final streamedResponse = await request.send();
        final postResponse = await http.Response.fromStream(streamedResponse);

        if (postResponse.statusCode != 200) {
          throw Exception("POST failed: ${postResponse.body}");
        }

        // Parse the response and extract the chunks
        final responseText = postResponse.body;
        final lines = responseText.split('\n');

        for (var line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6); // Remove 'data: ' prefix
            print(
                "📥 [ClaudeApiService] Direct chunk: ${data.length > 60 ? data.substring(0, 60) + '...' : data}");
            onChunk(data);
          }
        }

        // Signal completion
        onDone();

        // Return a dummy EventSource that will be closed immediately
        final dummyEventSource =
            html.EventSource(streamUrl, withCredentials: true);
        dummyEventSource.close();
        return dummyEventSource;
      }

      // For requests without files, use EventSource (GET request)
      final eventSource = html.EventSource(streamUrl, withCredentials: true);

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

  void closeStream(html.EventSource? eventSource) {
    print("🛑 [ClaudeApiService] Closing SSE connection");
    eventSource?.close();
  }
}
