 import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
import 'package:qsidian/custom_markdown_controller.dart'; // Import CustomMarkdownController

class NoteEditorScreen
    extends
        StatefulWidget {
  final String noteFileUri;

  const NoteEditorScreen({
    super.key,
    required this.noteFileUri,
  });

  @override
  State<
    NoteEditorScreen
  >
  createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState
    extends
        State<NoteEditorScreen> {
  late CustomMarkdownController _controller;
  String _initialContent = '';
  static const platform = MethodChannel('com.example.qsidian/vault');
  // No longer needed for split view
  // late FocusNode _focusNode;
  // bool _isEditing = true; // State to manage visibility: true for editor, false for preview


  @override
  void initState() {
    super.initState();
    _controller = CustomMarkdownController(); // Initialize CustomMarkdownController
    // _focusNode = FocusNode(); // No longer needed for split view
    // _focusNode.addListener(() { // No longer needed for split view
    //   setState(() { // No longer needed for split view
    //     _isEditing = _focusNode.hasFocus; // No longer needed for split view
    //   }); // No longer needed for split view
    // }); // No longer needed for split view
    _controller.addListener(() {
      setState(() {
        // Rebuild the MarkdownBody when text changes
      });
    });
    _loadNoteContent();
  }

  Future<
    void
  >
  _loadNoteContent() async {
    try {
      final String? content = await platform.invokeMethod(
        'readFileContent',
        {
          'fileUri': widget.noteFileUri,
        },
      );
      _initialContent =
          content ??
          '';
      _controller.text = _initialContent; // Update controller's text
    } on PlatformException catch (
      e
    ) {
      print(
        "Failed to read file content: '${e.message}'.",
      );
      _initialContent = 'Error loading note: ${e.message}';
      _controller.text = _initialContent; // Update controller's text
    }
    setState(
      () {},
    );
  }

  Future<
    void
  >
  _saveNoteContent() async {
    try {
      await platform.invokeMethod(
        'writeFileContent',
        {
          'fileUri': widget.noteFileUri,
          'content': _controller.text,
        },
      );
      print(
        'Note saved: ${widget.noteFileUri}',
      );
    } on PlatformException catch (
      e
    ) {
      print(
        "Failed to save file content: '${e.message}'.",
      );
    }
  }

  String _getFileDisplayName(String fileUri) {
    try {
      final Uri parsedUri = Uri.parse(fileUri);
      if (parsedUri.pathSegments.isNotEmpty) {
        final String lastSegment = parsedUri.pathSegments.last;
        return Uri.decodeComponent(lastSegment);
      }
    } catch (e) {
      print("Error parsing URI for display name: $e");
      // Fallback: try to extract filename from the raw URI string
      final int lastSlashIndex = fileUri.lastIndexOf('/');
      if (lastSlashIndex != -1 && lastSlashIndex < fileUri.length - 1) {
        final String filename = fileUri.substring(lastSlashIndex + 1);
        try {
          return Uri.decodeComponent(filename);
        } catch (e2) {
          print("Error decoding filename: $e2");
          return filename; // Return raw filename if decoding fails
        }
      }
    }
    // Ultimate fallback
    return "Unknown File";
  }

  @override
  void dispose() {
    _controller.dispose();
    // _focusNode.dispose(); // No longer needed for split view
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Custom App Bar
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceVariant,
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getFileDisplayName(widget.noteFileUri),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Markdown Note',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Save button
                    FilledButton.icon(
                      onPressed: _saveNoteContent,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Formatting Toolbar
          _buildFormattingToolbar(context),
          
          // Editor Content
          Expanded(
            child: Row(
              children: [
                // Editor Panel
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(
                        right: BorderSide(
                          color: colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Editor',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _controller,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Start writing your note...',
                                hintStyle: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.4),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                
                // Preview Panel
                Expanded(
                  child: Container(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                size: 16,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Preview',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: MarkdownBody(
                              data: _controller.text.isEmpty 
                                  ? '*Preview will appear here as you type...*'
                                  : _controller.text,
                              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                h1: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                h2: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                h3: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                p: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.6,
                                  color: colorScheme.onSurface,
                                ),
                                code: theme.textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  backgroundColor: colorScheme.surfaceVariant,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattingToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Format:',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),
            _buildToolbarButton(
              context,
              Icons.title_rounded,
              'H',
              () => _applyMarkdownFormat('## '),
            ),
            _buildToolbarButton(
              context,
              Icons.format_bold_rounded,
              'B',
              () => _applyMarkdownFormat('**'),
            ),
            _buildToolbarButton(
              context,
              Icons.format_italic_rounded,
              'I',
              () => _applyMarkdownFormat('*'),
            ),
            _buildToolbarButton(
              context,
              Icons.format_underlined_rounded,
              'U',
              () => _applyMarkdownFormat('<u>', '</u>'),
            ),
            _buildToolbarButton(
              context,
              Icons.format_strikethrough_rounded,
              'S',
              () => _applyMarkdownFormat('~~'),
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 24,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(width: 8),
            _buildToolbarButton(
              context,
              Icons.format_list_bulleted_rounded,
              '•',
              () => _applyMarkdownFormat('- '),
            ),
            _buildToolbarButton(
              context,
              Icons.format_list_numbered_rounded,
              '1.',
              () => _applyMarkdownFormat('1. '),
            ),
            _buildToolbarButton(
              context,
              Icons.code_rounded,
              '<>',
              () => _applyMarkdownFormat('`'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _applyMarkdownFormat(
    String markdownTag, [
    String? closingTag,
  ]) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (start == -1 || end == -1) {
      // No selection, just insert at cursor
      final newText =
          text.substring(0, _controller.selection.baseOffset) +
          markdownTag +
          (closingTag ?? markdownTag) +
          text.substring(_controller.selection.baseOffset);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.selection.baseOffset + markdownTag.length,
      );
    } else if (start == end) {
      // No text selected, insert tags and place cursor in between
      final newText =
          text.substring(0, start) +
          markdownTag +
          (closingTag ?? markdownTag) +
          text.substring(end);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: start + markdownTag.length,
      );
    } else {
      // Text selected, wrap with tags
      final selectedText = text.substring(start, end);
      final newText =
          text.substring(0, start) +
          markdownTag +
          selectedText +
          (closingTag ?? markdownTag) +
          text.substring(end);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: end + markdownTag.length * (closingTag == null ? 1 : 2),
      );
    }
  }
}
