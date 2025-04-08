import 'dart:convert';
import 'dart:html'; // SSE support for Flutter Web
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'services/claude_api_service.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'components/claude_app_bar.dart';
import 'components/claude_input_field.dart';
import 'components/claude_send_button.dart';
import 'components/claude_response_box.dart';
import 'components/claude_drop_zone.dart';

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
  final ScrollController _scrollController = ScrollController();
  final ClaudeApiService _apiService = ClaudeApiService();

  StringBuffer _responseBuffer = StringBuffer();
  int _thinkingTokens = 1024;

  final int _minTokens = 1024;
  final int _maxTokens = 32000;
  late final int _firstThreshold =
      _minTokens + ((_maxTokens - _minTokens) ~/ 3);
  late final int _secondThreshold =
      _minTokens + 2 * ((_maxTokens - _minTokens) ~/ 3);

  EventSource? _eventSource;

  bool _isStreaming = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _extendedThinkingEnabled = false;

  List<Map<String, dynamic>> _thinkingChunks = [];
  List<UploadedFile> _uploadedFiles = [];

  void _sendQuestion() async {
    final question = _controller.text.trim();
    if (question.isEmpty && _uploadedFiles.isEmpty) return;

    setState(() {
      _responseBuffer.clear();
      _thinkingChunks.clear();
      _isStreaming = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Always use POST for requests to maintain session
      _eventSource = await _apiService.streamResponse(
        question: question,
        files: _uploadedFiles,
        extendedThinking: _extendedThinkingEnabled,
        thinkingTokens: _thinkingTokens,
        onChunk: (chunk) {
          try {
            if (chunk.isEmpty) return;

            print(
                "Processing chunk: ${chunk.substring(0, math.min(30, chunk.length))}...");

            final json = Map<String, dynamic>.from(
                jsonDecode(chunk) as Map<String, dynamic>);

            if (json['type'] == 'text') {
              setState(() {
                _responseBuffer.write(json['text']);
              });
              _scrollToBottom();
            } else if (json['type'] == 'thinking') {
              setState(() {
                _thinkingChunks.add({
                  'timestamp': json['timestamp'],
                  'thinking': json['thinking']
                });
              });
            }
          } catch (e) {
            print("Error processing chunk: $e");
            if (chunk.isNotEmpty &&
                !chunk.startsWith('{') &&
                !chunk.startsWith('[')) {
              setState(() {
                _responseBuffer.write(chunk);
              });
              _scrollToBottom();
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
      _uploadedFiles = [];
      _isStreaming = false;
      _hasError = false;
      _errorMessage = '';
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color getButtonColor() {
    if (_thinkingTokens <= _firstThreshold) return const Color(0xFF39D2C0);
    if (_thinkingTokens <= _secondThreshold) return const Color(0xFFCA6C45);
    return const Color(0xFFE74852);
  }

  String getTokenLabel() {
    if (_thinkingTokens <= _firstThreshold) return 'Easy Tasks';
    if (_thinkingTokens <= _secondThreshold) return 'Medium Tasks';
    return 'Hard Tasks';
  }

  @override
  void dispose() {
    _apiService.closeStream(_eventSource);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ClaudeAppBar(
        isStreaming: _isStreaming,
        onReset: _resetChat,
      ),
      body: Column(
        children: [
          // 💬 Respuestas en scroll
          Flexible(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.all(AppConfig.defaultPadding),
              children: [
                if (_hasError)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74852).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ClaudeResponseBox(
                  responseBuffer: _responseBuffer,
                  isStreaming: _isStreaming,
                  hasError: _hasError,
                  thinkingChunks: _thinkingChunks,
                ),
              ],
            ),
          ),

          // 🧠 Opciones + Input abajo
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Switch de Extended Thinking
                Row(
                  children: [
                    const Icon(Icons.psychology_outlined,
                        color: Colors.white70),
                    const SizedBox(width: 8),
                    const Text("Extended Thinking"),
                    const Spacer(),
                    Switch(
                      value: _extendedThinkingEnabled,
                      onChanged: (val) {
                        setState(() {
                          _extendedThinkingEnabled = val;
                        });
                      },
                    ),
                  ],
                ),

                if (_extendedThinkingEnabled)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text("🧠 Thinking Tokens: "),
                          Text(
                            '$_thinkingTokens',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: getButtonColor(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            getTokenLabel(),
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: getButtonColor(),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _thinkingTokens.toDouble(),
                        min: _minTokens.toDouble(),
                        max: _maxTokens.toDouble(),
                        divisions: 100,
                        label: '$_thinkingTokens',
                        activeColor: getButtonColor(),
                        onChanged: (double value) {
                          setState(() {
                            _thinkingTokens = value.toInt();
                          });
                        },
                      ),
                      const Text(
                        "Higher token budgets may improve answers but also increase cost/time.",
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Input + botón
                Row(
                  children: [
                    Expanded(
                      child: ClaudeInputField(
                        controller: _controller,
                        isStreaming: _isStreaming,
                        onSubmitted: _sendQuestion,
                        files: _uploadedFiles,
                        onFilesChanged: (files) {
                          setState(() {
                            _uploadedFiles = files;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClaudeSendButton(
                      isStreaming: _isStreaming,
                      onPressed: () {
                        if (!_isStreaming) {
                          _sendQuestion();
                        }
                      },
                      label: _uploadedFiles.isNotEmpty ? 'Send' : 'Ask',
                      buttonColor: getButtonColor(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
