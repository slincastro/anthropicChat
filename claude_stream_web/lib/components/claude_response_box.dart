import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ClaudeResponseBox extends StatefulWidget {
  final StringBuffer responseBuffer;
  final bool isStreaming;
  final bool hasError;
  final List<Map<String, dynamic>> thinkingChunks;

  const ClaudeResponseBox({
    super.key,
    required this.responseBuffer,
    required this.isStreaming,
    required this.hasError,
    required this.thinkingChunks,
  });

  @override
  State<ClaudeResponseBox> createState() => _ClaudeResponseBoxState();
}

class _ClaudeResponseBoxState extends State<ClaudeResponseBox> {
  bool _showThinking = true;
  final ScrollController _thinkingScrollController = ScrollController();
  final ScrollController _responseScrollController = ScrollController();

  String _lastBuffer = '';
  bool _wasResponseEmpty = true;

  void _toggleThinking() {
    setState(() {
      _showThinking = !_showThinking;
    });
  }

  @override
  void didUpdateWidget(ClaudeResponseBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if response buffer was empty and now has content
    if (_wasResponseEmpty && widget.responseBuffer.isNotEmpty) {
      setState(() {
        _showThinking = false;
        _wasResponseEmpty = false;
      });
    }

    // Reset the flag if response buffer becomes empty again
    if (widget.responseBuffer.isEmpty) {
      _wasResponseEmpty = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = widget.responseBuffer.isNotEmpty ||
        widget.isStreaming ||
        widget.hasError ||
        widget.thinkingChunks.isNotEmpty;

    if (!hasContent) return const SizedBox.shrink();

    // Auto-scroll response if buffer changed
    if (_lastBuffer != widget.responseBuffer.toString()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_responseScrollController.hasClients) {
          _responseScrollController.animateTo(
            _responseScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      _lastBuffer = widget.responseBuffer.toString();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thinking toggle
          if (widget.thinkingChunks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Text(
                    "🧠 Thinking Steps",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showThinking ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: _toggleThinking,
                    tooltip: _showThinking ? "Hide thinking" : "Show thinking",
                  ),
                ],
              ),
            ),

          // Thinking steps section with auto-scroll
          if (_showThinking && widget.thinkingChunks.isNotEmpty)
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF162231),
                borderRadius: BorderRadius.circular(4),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.builder(
                controller: _thinkingScrollController,
                itemCount: widget.thinkingChunks.length,
                itemBuilder: (context, index) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_thinkingScrollController.hasClients) {
                      _thinkingScrollController.animateTo(
                        _thinkingScrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  final chunk = widget.thinkingChunks[index];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "[${chunk['timestamp']}s] ",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Expanded(
                          child: Text(
                            chunk['thinking'],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Spinner while streaming and no response yet
          if (widget.isStreaming && widget.responseBuffer.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white70,
                ),
              ),
            ),

          // Final response with auto-scroll
          if (widget.responseBuffer.isNotEmpty)
            SizedBox(
              height: 250,
              child: SingleChildScrollView(
                controller: _responseScrollController,
                child: MarkdownBody(
                  data: widget.responseBuffer.toString(),
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: const TextStyle(color: Colors.white70, height: 1.5),
                    h1: const TextStyle(color: Colors.white),
                    h2: const TextStyle(color: Colors.white),
                    h3: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
