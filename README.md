# Qsidian - Obsidian Helper App

Qsidian is a lightweight Flutter app designed to complement Obsidian by providing fast loading times and powerful home screen widget functionality for quick note access and management.

## Features

### Core Features
- **Fast Loading**: Optimized for quick startup and note access
- **Vault Management**: Select and manage multiple Obsidian-compatible vaults
- **Markdown Support**: Full markdown editing with live preview
- **File Compatibility**: Works with existing Obsidian vaults and markdown files
- **Real-time Sync**: Automatically detects changes to notes made externally

### Home Screen Widget (Core Feature)
- **Quick Note Creation**: Create notes directly from the home screen widget
- **Recent Notes Display**: View and access your most recent notes
- **Vault Information**: Display current vault stats and information
- **Quick Capture**: Capture thoughts instantly without opening the app
- **Configurable**: Customize widget appearance and functionality

### User Interface
- **Material Design 3**: Modern, clean interface with light/dark theme support
- **Tabbed Navigation**: Easy access to Home, Notes, and Settings
- **Search Functionality**: Quickly find notes by title, content, or tags
- **Note Editor**: Rich markdown editor with toolbar and live preview

## Screenshots

*Screenshots will be added once the app is fully tested*

## Installation

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Android Studio or VS Code with Flutter extensions
- Android device or emulator for testing

### Setup
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd qsidian
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Building APK
```bash
flutter build apk --release
```

## Usage

### Getting Started
1. **Select a Vault**: On first launch, select a folder to use as your vault
2. **Create Notes**: Use the floating action button or quick capture widget
3. **Edit Notes**: Tap any note to open the markdown editor
4. **Configure Widget**: Access settings to customize the home screen widget

### Vault Management
- Add multiple vaults for different projects or purposes
- Switch between vaults easily from the vault selection screen
- Vaults are compatible with existing Obsidian installations

### Note Management
- Create, edit, and delete markdown notes
- Automatic file watching for external changes
- Search through notes by title, content, or tags
- View recent notes for quick access

### Home Screen Widget
- Add the Qsidian widget to your home screen
- Configure widget settings in the app
- Use for quick note creation and access

## Architecture

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── note.dart            # Note model
│   └── vault.dart           # Vault model
├── providers/               # State management
│   ├── notes_provider.dart  # Notes state management
│   ├── vault_provider.dart  # Vault state management
│   └── theme_provider.dart  # Theme state management
├── screens/                 # UI screens
│   ├── home_screen.dart     # Main home screen
│   ├── notes_list_screen.dart
│   ├── note_editor_screen.dart
│   ├── vault_selection_screen.dart
│   └── settings_screen.dart
├── services/                # Business logic
│   ├── file_service.dart    # File operations
│   └── widget_service.dart  # Widget communication
├── widgets/                 # Reusable UI components
│   ├── note_card.dart
│   ├── vault_info_widget.dart
│   ├── quick_note_widget.dart
│   └── recent_notes_widget.dart
└── utils/
    └── app_theme.dart       # Theme configuration
```

### Key Technologies
- **Flutter**: Cross-platform mobile development
- **Provider**: State management
- **SharedPreferences**: Local data persistence
- **File System**: Direct file operations for Obsidian compatibility
- **Watcher**: Real-time file change detection
- **Flutter Markdown**: Markdown rendering and editing
- **Home Widget**: Android home screen widget support

## Development

### Code Style
- Follow Flutter/Dart conventions
- Use meaningful variable and function names
- Comment complex logic
- Maintain consistent formatting

### Testing
Run tests with:
```bash
flutter test
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Roadmap

### Phase 1 (Current)
- [x] Basic note management
- [x] Vault selection and management
- [x] Markdown editor with live preview
- [x] Home screen widget foundation
- [x] Material Design 3 UI

### Phase 2 (Planned)
- [ ] Enhanced widget functionality
- [ ] Advanced search and filtering
- [ ] Note templates
- [ ] Export/import features
- [ ] Performance optimizations

### Phase 3 (Future)
- [ ] Plugin system architecture
- [ ] Cloud sync integration
- [ ] Collaboration features
- [ ] Advanced markdown features
- [ ] iOS widget support

## Known Issues

1. **Android NDK Version**: The build process shows warnings about NDK versions. This doesn't affect functionality but may require updating the NDK version in the future.

2. **File Watcher**: On some devices, the file watcher may not detect external changes immediately. This is a limitation of the underlying file system monitoring.

3. **Widget Limitations**: Home screen widget functionality is currently Android-only. iOS support is planned for future releases.

## Troubleshooting

### Common Issues

**App won't start**
- Ensure Flutter SDK is properly installed
- Run `flutter doctor` to check for issues
- Clear build cache: `flutter clean && flutter pub get`

**Can't select vault folder**
- Check file permissions
- Ensure the folder exists and is accessible
- Try selecting a different folder

**Notes not syncing**
- Check if the vault folder is still accessible
- Restart the app to refresh file watchers
- Verify file permissions

**Widget not updating**
- Check widget configuration in settings
- Restart the app to refresh widget data
- Remove and re-add the widget

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Obsidian team for creating an amazing note-taking app
- Flutter team for the excellent framework
- Contributors to the open-source packages used in this project

## Support

For support, feature requests, or bug reports, please open an issue on the GitHub repository.

---

**Note**: Qsidian is designed to complement, not replace, Obsidian. It works best when used alongside the main Obsidian application for a complete note-taking workflow.