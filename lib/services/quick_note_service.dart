import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_item.dart';
 
class QuickNoteService {
  static const platform = MethodChannel('com.example.qsidian/vault');
  static const nativeQuickNoteChannel = MethodChannel('com.example.qsidian/native_quick_note');
 
  // SharedPreferences keys
  static const String _lastSelectedFolderUriKey = 'quick_note_last_folder_uri';
  static const String _lastSelectedFolderNameKey =
      'quick_note_last_folder_name';
  static const String _recentNotesKey = 'quick_note_recent_notes';
  static const int _maxRecentNotes = 5;
 
  QuickNoteService() {
    // Set up method handler for native quick note calls
    nativeQuickNoteChannel.setMethodCallHandler(_handleNativeQuickNoteCall);
  }
 
  Future<dynamic> _handleNativeQuickNoteCall(MethodCall call) async {
    switch (call.method) {
      case 'saveQuickNote':
        final Map<dynamic, dynamic> args = call.arguments;
        final String title = args['title'];
        final String content = args['content'];
        // Assuming a default vault URI or loading it from preferences if needed
        // For simplicity, let's use a dummy URI or a predefined one for now.
        // In a real app, you'd load the default vault URI here.
        final prefs = await SharedPreferences.getInstance();
        final defaultVaultUri = prefs.getString(_lastSelectedFolderUriKey);
 
        if (defaultVaultUri != null && defaultVaultUri.isNotEmpty) {
          await createNote(defaultVaultUri, title, content);
          return true; // Indicate success
        } else {
          throw PlatformException(
            code: 'NO_DEFAULT_VAULT',
            message: 'No default vault selected for saving quick notes.',
          );
        }
      default:
        throw PlatformException(
          code: 'NOT_IMPLEMENTED',
          message: 'Method ${call.method} not implemented.',
        );
    }
  }

  // File operations

  /// Creates a new note file in the specified folder
  /// Returns the URI of the created note
  Future<String> createNote(
    String folderUri,
    String title,
    String content,
  ) async {
    try {
      final String noteUri = await platform.invokeMethod('createFile', {
        'parentUri': folderUri,
        'fileName': '${_sanitizeFileName(title)}.md',
        'content': content,
      });

      // Add to recent notes after successful creation
      await addToRecentNotes(noteUri, title);

      return noteUri;
    } on PlatformException catch (e) {
      throw QuickNoteException('Failed to create note: ${e.message}', e.code);
    }
  }

  /// Deletes a note file
  Future<void> deleteNote(String noteUri) async {
    try {
      await platform.invokeMethod('deleteFile', {'uri': noteUri});

      // Remove from recent notes after successful deletion
      await _removeFromRecentNotes(noteUri);
    } on PlatformException catch (e) {
      throw QuickNoteException('Failed to delete note: ${e.message}', e.code);
    }
  }

  /// Reads the content of a note file
  Future<String> readNoteContent(String noteUri) async {
    try {
      final String content = await platform.invokeMethod('readFileContent', {
        'fileUri': noteUri,
      });

      // Update recent notes access time
      await _updateRecentNoteAccess(noteUri);

      return content;
    } on PlatformException catch (e) {
      throw QuickNoteException('Failed to read note: ${e.message}', e.code);
    }
  }

  /// Updates an existing note file
  Future<void> updateNote(String noteUri, String content) async {
    try {
      await platform.invokeMethod('writeFileContent', {
        'fileUri': noteUri,
        'content': content,
      });

      // Update recent notes access time
      await _updateRecentNoteAccess(noteUri);
    } on PlatformException catch (e) {
      throw QuickNoteException('Failed to update note: ${e.message}', e.code);
    }
  }

  // Folder operations

  /// Gets the folder structure for the vault
  Future<List<FileItem>> getFolderStructure(String vaultUri) async {
    try {
      final List<dynamic> result = await platform.invokeMethod(
        'listFolderContents',
        {'folderUri': vaultUri},
      );

      return result
          .map(
            (item) => FileItem(
              uri: item['uri'],
              name: item['name'],
              isDirectory: item['isDirectory'],
              displayPath: item['displayPath'] ?? item['name'],
            ),
          )
          .where((item) => item.isDirectory) // Only return directories
          .toList();
    } on PlatformException catch (e) {
      throw QuickNoteException(
        'Failed to get folder structure: ${e.message}',
        e.code,
      );
    }
  }

  /// Gets all files in a folder (for finding markdown files)
  Future<List<FileItem>> getFilesInFolder(String folderUri) async {
    try {
      final List<dynamic> result = await platform.invokeMethod(
        'listFolderContents',
        {'folderUri': folderUri},
      );

      return result
          .map(
            (item) => FileItem(
              uri: item['uri'],
              name: item['name'],
              isDirectory: item['isDirectory'],
              displayPath: item['displayPath'] ?? item['name'],
            ),
          )
          .where(
            (item) => !item.isDirectory && item.isMarkdownFile,
          ) // Only markdown files
          .toList();
    } on PlatformException catch (e) {
      throw QuickNoteException(
        'Failed to get files in folder: ${e.message}',
        e.code,
      );
    }
  }

  // Recent notes management

  /// Gets the list of recent notes
  Future<List<FileItem>> getRecentNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? recentNotesJson = prefs.getString(_recentNotesKey);

      if (recentNotesJson == null) return [];

      final List<dynamic> recentNotesList = jsonDecode(recentNotesJson);
      final List<FileItem> recentNotes = recentNotesList
          .map((item) => FileItem.fromJson(item))
          .toList();

      // Sort by lastAccessed in descending order (most recent first)
      recentNotes.sort((a, b) {
        if (a.lastAccessed == null && b.lastAccessed == null) return 0;
        if (a.lastAccessed == null) return 1;
        if (b.lastAccessed == null) return -1;
        return b.lastAccessed!.compareTo(a.lastAccessed!);
      });

      return recentNotes.take(_maxRecentNotes).toList();
    } catch (e) {
      // If there's an error reading recent notes, return empty list
      return [];
    }
  }

  /// Adds a note to the recent notes list
  Future<void> addToRecentNotes(String noteUri, String noteName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<FileItem> recentNotes = await getRecentNotes();

      // Remove existing entry if it exists
      recentNotes.removeWhere((note) => note.uri == noteUri);

      // Add new entry at the beginning
      final newNote = FileItem(
        uri: noteUri,
        name: noteName.endsWith('.md') ? noteName : '$noteName.md',
        isDirectory: false,
        displayPath: noteName,
        lastAccessed: DateTime.now(),
      );

      recentNotes.insert(0, newNote);

      // Keep only the most recent notes
      final limitedNotes = recentNotes.take(_maxRecentNotes).toList();

      // Save to preferences
      final String recentNotesJson = jsonEncode(
        limitedNotes.map((note) => note.toJson()).toList(),
      );

      await prefs.setString(_recentNotesKey, recentNotesJson);
    } catch (e) {
      // Silently fail if we can't save recent notes
    }
  }

  /// Updates the access time for a recent note
  Future<void> _updateRecentNoteAccess(String noteUri) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<FileItem> recentNotes = await getRecentNotes();

      // Find and update the note
      final noteIndex = recentNotes.indexWhere((note) => note.uri == noteUri);
      if (noteIndex != -1) {
        final updatedNote = recentNotes[noteIndex].copyWith(
          lastAccessed: DateTime.now(),
        );

        recentNotes[noteIndex] = updatedNote;

        // Save updated list
        final String recentNotesJson = jsonEncode(
          recentNotes.map((note) => note.toJson()).toList(),
        );

        await prefs.setString(_recentNotesKey, recentNotesJson);
      }
    } catch (e) {
      // Silently fail if we can't update recent notes
    }
  }

  /// Removes a note from the recent notes list
  Future<void> _removeFromRecentNotes(String noteUri) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<FileItem> recentNotes = await getRecentNotes();

      // Remove the note
      recentNotes.removeWhere((note) => note.uri == noteUri);

      // Save updated list
      final String recentNotesJson = jsonEncode(
        recentNotes.map((note) => note.toJson()).toList(),
      );

      await prefs.setString(_recentNotesKey, recentNotesJson);
    } catch (e) {
      // Silently fail if we can't update recent notes
    }
  }

  // Preferences management

  /// Saves the last selected folder
  Future<void> saveLastSelectedFolder(
    String folderUri,
    String folderName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSelectedFolderUriKey, folderUri);
      await prefs.setString(_lastSelectedFolderNameKey, folderName);
    } catch (e) {
      // Silently fail if we can't save preferences
    }
  }

  /// Gets the last selected folder
  Future<Map<String, String>> getLastSelectedFolder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? folderUri = prefs.getString(_lastSelectedFolderUriKey);
      final String? folderName = prefs.getString(_lastSelectedFolderNameKey);

      return {'uri': folderUri ?? '', 'name': folderName ?? 'Root'};
    } catch (e) {
      return {'uri': '', 'name': 'Root'};
    }
  }

  /// Clears all recent notes
  Future<void> clearRecentNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentNotesKey);
    } catch (e) {
      // Silently fail if we can't clear recent notes
    }
  }

  /// Clears all preferences
  Future<void> clearAllPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSelectedFolderUriKey);
      await prefs.remove(_lastSelectedFolderNameKey);
      await prefs.remove(_recentNotesKey);
    } catch (e) {
      // Silently fail if we can't clear preferences
    }
  }

  // Utility methods

  /// Sanitizes a file name by removing invalid characters
  String _sanitizeFileName(String fileName) {
    // Remove or replace invalid characters for file names
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Extracts the title from note content (first line or filename)
  String extractTitleFromContent(String content, String fileName) {
    if (content.isEmpty) return fileName.replaceAll('.md', '');

    final lines = content.split('\n');
    final firstLine = lines.first.trim();

    // Check if first line is a markdown header
    if (firstLine.startsWith('#')) {
      return firstLine.replaceAll(RegExp(r'^#+\s*'), '').trim();
    }

    // Return first non-empty line or filename
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isNotEmpty) {
        return trimmedLine.length > 50
            ? '${trimmedLine.substring(0, 50)}...'
            : trimmedLine;
      }
    }

    return fileName.replaceAll('.md', '');
  }
}

/// Custom exception for QuickNoteService operations
class QuickNoteException implements Exception {
  final String message;
  final String? code;

  const QuickNoteException(this.message, [this.code]);

  @override
  String toString() =>
      'QuickNoteException: $message${code != null ? ' (Code: $code)' : ''}';
}
