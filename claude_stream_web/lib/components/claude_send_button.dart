import 'package:flutter/material.dart';

class ClaudeSendButton extends StatelessWidget {
  final bool isStreaming;
  final VoidCallback onPressed;
  final String label;
  final Color? buttonColor;

  const ClaudeSendButton({
    super.key,
    required this.isStreaming,
    required this.onPressed,
    this.label = "Send",
    this.buttonColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isStreaming ? null : onPressed,
      icon: const Icon(Icons.send),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor ?? Colors.white24,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
