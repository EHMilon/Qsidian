import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qsidian/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for the app to initialize
    await tester.pumpAndSettle();

    // Verify that the app title is displayed
    expect(find.text('Qsidian'), findsOneWidget);
  });
}
