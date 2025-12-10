# Qsidian AI Agent Instructions

This document provides essential guidelines for AI coding agents working with the Qsidian Flutter codebase.

## 1. Project Overview

Qsidian is a Flutter application designed to complement Obsidian, focusing on fast note access, management, and home screen widget functionality. It supports multiple Obsidian-compatible vaults, markdown editing with live preview, and real-time synchronization with external changes.

## 2. Architecture and Key Components

The application follows a feature-driven architecture within the `lib/` directory:

-   **`lib/main.dart`**: The entry point of the Flutter application.
-   **`lib/models/`**: Contains data models like `file_item.dart` and `quick_note_data.dart`.
-   **`lib/core/utils/`**: Utility functions and helpers.
-   **`lib/data/`**: Data layer, likely handling data persistence and retrieval.
-   **`lib/features/`**: Organized by feature, e.g., `home/`, `note_editor/`. Each feature encapsulates its UI, business logic, and state.
-   **`lib/services/`**: Contains business logic and services, such as `quick_note_service.dart` for quick note operations.
-   **`lib/widgets/`**: Reusable UI components like `create_note_dialog.dart`, `quick_note_widget.dart`.

**State Management**: While not explicitly detailed in `README.md`, the presence of `providers/` in the `README.md`'s architecture section suggests a provider-based state management solution (e.g., `package:provider`). Look for `ChangeNotifier` and `Consumer` patterns.

**Data Flow**: The app interacts with local file systems for Obsidian vault management. `lib/services/` likely orchestrates file operations and data manipulation.

## 3. Developer Workflows

### Running the Application

To run the Flutter application on a connected device or emulator:
```bash
flutter run
```

### Installing Dependencies

To fetch all the project dependencies:
```bash
flutter pub get
```

### Building for Release (Android APK)

To build a release APK for Android:
```bash
flutter build apk --release
```

### Running Tests

Unit and widget tests are located in the `test/` directory.
To run all tests:
```bash
flutter test
```
To run specific tests, provide the file path:
```bash
flutter test test/widgets/quick_note_widget_save_test.dart
```

## 4. Project-Specific Conventions

-   **Feature-based Organization**: New features should ideally reside within `lib/features/<feature_name>/`.
-   **UI Components**: Reusable UI elements are in `lib/widgets/`.
-   **Service Layer**: Business logic and data interactions are abstracted into services in `lib/services/`.
-   **Obsidian Compatibility**: All file operations and markdown handling should ensure compatibility with Obsidian's file structure and markdown syntax.

## 5. Integration Points

-   **Obsidian Vaults**: The application directly interacts with user-selected directories as Obsidian vaults. File I/O operations are critical here.
-   **Home Screen Widget**: The `home_widget` package is used for implementing home screen widgets. Changes related to widget functionality will involve `lib/widgets/quick_note_widget.dart` and potentially platform-specific code in `android/` and `ios/`.

## 6. External Dependencies

Key dependencies can be found in `pubspec.yaml`. Notable ones include `home_widget` for home screen functionality and `file_picker` for vault selection.

---
Please provide feedback on any unclear or incomplete sections to help improve these instructions.
