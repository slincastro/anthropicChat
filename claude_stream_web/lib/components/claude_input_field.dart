import 'package:flutter/material.dart';

class ClaudeInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isStreaming;
  final VoidCallback onSubmitted;

  const ClaudeInputField({
    super.key,
    required this.controller,
    required this.isStreaming,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
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
    );
  }
}
