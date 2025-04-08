import 'dart:convert';
import 'dart:html'; // SSE support for Flutter Web
import 'package:flutter/material.dart';

import 'services/claude_api_service.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'components/claude_app_bar.dart';
import 'components/claude_input_field.dart';
import 'components/claude_send_button.dart';
import 'components/claude_response_box.dart';

void main() {
  runApp(const ClaudeApp());
}

class ClaudeApp extends StatelessWidget {
  const ClaudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: const ClaudeHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ClaudeHome extends StatefulWidget {
  const ClaudeHome({super.key});

  @override
  State<ClaudeHome> createState() => _ClaudeHomeState();
}

class _ClaudeHomeState extends State<ClaudeHome> {
  final TextEditingController _controller = TextEditingController();
  final ClaudeApiService _apiService = ClaudeApiService();

  StringBuffer _responseBuffer = StringBuffer();
  int _thinkingTokens = 100; // default value

  EventSource? _eventSource;

  bool _isStreaming = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _extendedThinkingEnabled = false;

  List<Map<String, dynamic>> _thinkingChunks = [];

  void _sendQuestion() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _responseBuffer.clear();
      _thinkingChunks.clear();
      _isStreaming = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      _eventSource = await _apiService.streamResponse(
        question: question,
        extendedThinking: _extendedThinkingEnabled,
        thinkingTokens: _thinkingTokens,
        onChunk: (chunk) {
          try {
            // Skip empty chunks
            if (chunk.isEmpty) {
              print('Received empty chunk, skipping');
              return;
            }

            print(
                'Received chunk: ${chunk.substring(0, chunk.length > 50 ? 50 : chunk.length)}...');

            final json = Map<String, dynamic>.from(
                jsonDecode(chunk) as Map<String, dynamic>);

            if (json['type'] == 'text') {
              setState(() {
                _responseBuffer.write(json['text']);
              });
            } else if (json['type'] == 'thinking') {
              // Immediately update UI with thinking data
              print('🧠 Received thinking chunk at ${json['timestamp']}s');
              setState(() {
                // Add to thinking chunks for display
                _thinkingChunks.add({
                  'timestamp': json['timestamp'],
                  'thinking': json['thinking']
                });
              });
            }
          } catch (e) {
            // Fallback for plain text chunks
            print(
                'Error parsing JSON: $e, chunk: ${chunk.substring(0, chunk.length > 20 ? 20 : chunk.length)}');

            // Only try to append if it looks like valid text
            if (chunk.isNotEmpty &&
                !chunk.startsWith('{') &&
                !chunk.startsWith('[')) {
              setState(() {
                _responseBuffer.write(chunk);
              });
            }
          }
        },
        onDone: () {
          setState(() {
            _isStreaming = false;
          });
        },
        onError: () {
          setState(() {
            _isStreaming = false;
            _hasError = _responseBuffer.isEmpty;
            _errorMessage = _responseBuffer.isEmpty
                ? "Connection error occurred"
                : "Stream closed unexpectedly";
          });
        },
      );
    } catch (e) {
      _handleError('Failed to connect: ${e.toString()}');
    }
  }

  void _handleError(String message) {
    _apiService.closeStream(_eventSource);
    setState(() {
      _isStreaming = false;
      _hasError = true;
      _errorMessage = message;
    });
  }

  void _resetChat() {
    _apiService.closeStream(_eventSource);
    setState(() {
      _responseBuffer.clear();
      _thinkingChunks.clear();
      _isStreaming = false;
      _hasError = false;
      _errorMessage = '';
    });
  }

  @override
  void dispose() {
    _apiService.closeStream(_eventSource);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ClaudeAppBar(
        isStreaming: _isStreaming,
        onReset: _resetChat,
      ),
      body: Padding(
        padding: EdgeInsets.all(AppConfig.defaultPadding),
        child: Column(
          children: [
            ClaudeInputField(
              controller: _controller,
              isStreaming: _isStreaming,
              onSubmitted: _sendQuestion,
            ),
            const SizedBox(height: 16),
            ClaudeSendButton(
              isStreaming: _isStreaming,
              onPressed: _sendQuestion,
            ),
            const SizedBox(height: 16),

            // 🧠 Toggle extended thinking
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text("🧠 Extended Thinking"),
                Switch(
                  value: _extendedThinkingEnabled,
                  onChanged: (val) {
                    setState(() {
                      _extendedThinkingEnabled = val;
                    });
                  },
                ),
                if (_extendedThinkingEnabled)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(" Thinking Tokens #"),
                      Slider(
                        value: _thinkingTokens.toDouble(),
                        min: 10,
                        max: 32000,
                        divisions: 99,
                        label: '$_thinkingTokens',
                        onChanged: (double value) {
                          setState(() {
                            _thinkingTokens = value.toInt();
                          });
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // 📥 Status + Error message
            Row(
              children: [
                const Text('💬 Response:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_isStreaming)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Streaming...'),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_hasError)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),

            // Thinking steps are now displayed in the ClaudeResponseBox

            // 💬 Final response
            ClaudeResponseBox(
              responseBuffer: _responseBuffer,
              isStreaming: _isStreaming,
              hasError: _hasError,
              thinkingChunks: _thinkingChunks,
            )
          ],
        ),
      ),
    );
  }
}
