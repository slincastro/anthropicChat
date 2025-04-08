import 'package:flutter/material.dart';

class ClaudeSendButton extends StatelessWidget {
  final bool isStreaming;
  final VoidCallback onPressed;
  final String label;

  const ClaudeSendButton({
    super.key,
    required this.isStreaming,
    required this.onPressed,
    this.label = 'Send',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isStreaming ? null : onPressed,
      child: Text(label),
    );
  }
}
