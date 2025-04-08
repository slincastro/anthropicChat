import 'package:flutter/material.dart';
import 'claude_drop_zone.dart';

class ClaudeInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isStreaming;
  final VoidCallback onSubmitted;
  final List<UploadedFile> files;
  final Function(List<UploadedFile>) onFilesChanged;

  const ClaudeInputField({
    super.key,
    required this.controller,
    required this.isStreaming,
    required this.onSubmitted,
    required this.files,
    required this.onFilesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag and drop zone
        ClaudeDropZone(
          files: files,
          onFilesChanged: onFilesChanged,
          isStreaming: isStreaming,
        ),
        const SizedBox(height: 8),
        // Text input field
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Ask something...',
            hintText: 'Type your question here',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          minLines: 1,
          enabled: !isStreaming,
          onSubmitted: (_) => onSubmitted(),
        ),
      ],
    );
  }
}
