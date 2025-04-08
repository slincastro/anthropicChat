import 'package:flutter/material.dart';

class ClaudeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isStreaming;
  final VoidCallback onReset;

  const ClaudeAppBar({
    super.key,
    required this.isStreaming,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Claude 3 Streaming POC 🌐'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: isStreaming ? null : onReset,
          tooltip: 'Reset Chat',
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
