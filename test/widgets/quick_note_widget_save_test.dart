import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qsidian/widgets/quick_note_widget.dart';

void main() {
  group('QuickNoteWidget Save Functionality', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      // Mock the platform channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.example.qsidian/vault'),
            (MethodCall methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'createFile':
                  // Return a mock URI for successful file creation
                  return 'content://mock/note.md';
                case 'listFolderContents':
                  // Return empty list for folder contents
                  return [];
                default:
                  return null;
              }
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.example.qsidian/vault'),
            null,
          );
    });

    testWidgets('should show save button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteWidget(vaultUri: 'content://mock/vault'),
          ),
        ),
      );

      // Find the save button
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('should show error when trying to save empty note', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteWidget(vaultUri: 'content://mock/vault'),
          ),
        ),
      );

      // Tap the save button without entering any content
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      // Should show error message
      expect(
        find.text('Please enter a title or content for your note'),
        findsOneWidget,
      );
    });

    testWidgets('should save note with title and content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteWidget(vaultUri: 'content://mock/vault'),
          ),
        ),
      );

      // Enter title and content
      await tester.enterText(find.byType(TextField).first, 'Test Note Title');
      await tester.enterText(
        find.byType(TextField).last,
        'This is test content',
      );

      // Tap the save button
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      // Verify that createFile was called
      expect(methodCalls.any((call) => call.method == 'createFile'), isTrue);

      // Verify the method was called with correct parameters
      final createFileCall = methodCalls.firstWhere(
        (call) => call.method == 'createFile',
      );
      expect(createFileCall.arguments['fileName'], 'Test_Note_Title.md');
      expect(createFileCall.arguments['content'], 'This is test content');
    });
  });
}
