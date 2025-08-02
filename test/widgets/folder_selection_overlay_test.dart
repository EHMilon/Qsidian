import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qsidian/widgets/folder_selection_overlay.dart';

void main() {
  group('FolderSelectionOverlay', () {
    testWidgets('should render header correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderSelectionOverlay(
              vaultUri: 'test://vault',
              currentSelection: null,
              onFolderSelected: (uri, name) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Only pump once to avoid waiting for async operations
      await tester.pump();

      // Check if the header is rendered
      expect(find.text('Select Folder'), findsOneWidget);
      expect(find.byIcon(Icons.folder), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('should show loading indicator initially', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderSelectionOverlay(
              vaultUri: 'test://vault',
              currentSelection: null,
              onFolderSelected: (uri, name) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      // Only pump once to check initial state
      await tester.pump();

      // Should show loading indicator while folders are being loaded
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should call onDismiss when close button is tapped', (
      WidgetTester tester,
    ) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderSelectionOverlay(
              vaultUri: 'test://vault',
              currentSelection: null,
              onFolderSelected: (uri, name) {},
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, isTrue);
    });
  });
}
