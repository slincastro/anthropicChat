// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stream_web/main.dart';

void main() {
  testWidgets('Claude app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ClaudeApp());

    // Verify that the app title is displayed
    expect(find.text('Claude 3 Streaming 🌐'), findsOneWidget);

    // Verify that the text field for questions is present
    expect(find.widgetWithText(TextField, 'Ask something...'), findsOneWidget);

    // Verify that the send button is present
    expect(find.widgetWithText(ElevatedButton, 'Send'), findsOneWidget);
  });
}
