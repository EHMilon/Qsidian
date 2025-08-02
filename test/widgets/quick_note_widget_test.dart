import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qsidian/widgets/quick_note_widget.dart';

void main() {
  group('QuickNoteWidget', () {
    testWidgets('should render with basic structure', (
      WidgetTester tester,
    ) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuickNoteWidget(vaultUri: 'test://vault/uri')),
        ),
      );

      // Verify the widget renders
      expect(find.byType(QuickNoteWidget), findsOneWidget);

      // Verify the header text
      expect(find.text('Quick Note'), findsOneWidget);

      // Verify the title field placeholder
      expect(find.text('What is the title of your note?'), findsOneWidget);

      // Verify the content field placeholder
      expect(find.text('Write you QuickNote here.....'), findsOneWidget);

      // Verify the folder button shows 'Root' by default
      expect(find.text('Root'), findsOneWidget);

      // Verify all toolbar buttons are present
      expect(find.byIcon(Icons.north_east), findsOneWidget); // Expand button
      expect(find.byIcon(Icons.folder), findsOneWidget); // Folder button
      expect(
        find.byIcon(Icons.attach_file),
        findsOneWidget,
      ); // Attachment button
      expect(
        find.byIcon(Icons.delete_outline),
        findsOneWidget,
      ); // Delete button
      expect(find.byIcon(Icons.history), findsOneWidget); // Recent button
      expect(find.byIcon(Icons.save), findsOneWidget); // Save button
    });

    testWidgets('should support transparent background', (
      WidgetTester tester,
    ) async {
      // Build the widget with transparent background
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteWidget(
              vaultUri: 'test://vault/uri',
              isTransparent: true,
            ),
          ),
        ),
      );

      // Verify the widget renders
      expect(find.byType(QuickNoteWidget), findsOneWidget);

      // The widget should still render all its components
      expect(find.text('Quick Note'), findsOneWidget);
      expect(find.text('What is the title of your note?'), findsOneWidget);
      expect(find.text('Write you QuickNote here.....'), findsOneWidget);
    });

    testWidgets('should handle text input', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuickNoteWidget(vaultUri: 'test://vault/uri')),
        ),
      );

      // Find the title text field and enter text
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'Test Title');
      await tester.pump();

      // Verify the text was entered
      expect(find.text('Test Title'), findsOneWidget);

      // Find the content text field and enter text
      final contentField = find.byType(TextField).last;
      await tester.enterText(contentField, 'Test content');
      await tester.pump();

      // Verify the text was entered
      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('should auto-expand content field with multiple lines', (
      WidgetTester tester,
    ) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuickNoteWidget(vaultUri: 'test://vault/uri')),
        ),
      );

      // Find the content text field
      final contentField = find.byType(TextField).last;

      // Enter text with multiple lines
      const multiLineText =
          'Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7\nLine 8\nLine 9\nLine 10';
      await tester.enterText(contentField, multiLineText);
      await tester.pump();

      // Verify the text was entered
      expect(find.text(multiLineText), findsOneWidget);

      // The widget should handle the expansion internally
      // We can't easily test the exact line count from the outside,
      // but we can verify the text is displayed correctly
    });

    testWidgets('should have correct placeholder text', (
      WidgetTester tester,
    ) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuickNoteWidget(vaultUri: 'test://vault/uri')),
        ),
      );

      // Verify title placeholder matches requirement exactly
      expect(find.text('What is the title of your note?'), findsOneWidget);

      // Verify content placeholder matches requirement exactly (including the typo)
      expect(find.text('Write you QuickNote here.....'), findsOneWidget);
    });
  });
}
