import 'package:flutter/material.dart';

class ClaudeSendButton extends StatelessWidget {
  final bool isStreaming;
  final VoidCallback onPressed;

  const ClaudeSendButton({
    super.key,
    required this.isStreaming,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: isStreaming ? null : onPressed,
          icon: const Icon(Icons.send),
          label: const Text('Send'),
        ),
      ],
    );
  }
}
