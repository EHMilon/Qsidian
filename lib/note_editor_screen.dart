import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel

class NoteEditorScreen extends StatefulWidget {
  final String noteFileUri;

  const NoteEditorScreen({super.key, required this.noteFileUri});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _controller;
  String _initialContent = '';
  static const platform = MethodChannel('com.example.qsidian/vault');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(); // Initialize controller
    _loadNoteContent();
  }

  Future<void> _loadNoteContent() async {
    try {
      final String? content = await platform.invokeMethod(
        'readFileContent',
        {'fileUri': widget.noteFileUri},
      );
      _initialContent = content ?? '';
      _controller.text = _initialContent; // Update controller's text
    } on PlatformException catch (e) {
      print("Failed to read file content: '${e.message}'.");
      _initialContent = 'Error loading note: ${e.message}';
      _controller.text = _initialContent; // Update controller's text
    }
    setState(() {});
  }

  Future<void> _saveNoteContent() async {
    try {
      await platform.invokeMethod(
        'writeFileContent',
        {'fileUri': widget.noteFileUri, 'content': _controller.text},
      );
      print('Note saved: ${widget.noteFileUri}');
    } on PlatformException catch (e) {
      print("Failed to save file content: '${e.message}'.");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(Uri.parse(widget.noteFileUri).path)),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveNoteContent),
        ],
      ),
      body: Column(
        children: [
          _buildFormattingToolbar(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical:
                          TextAlignVertical.top, // Align text to top
                      decoration: const InputDecoration(
                        hintText: 'Start writing your note...',
                        border: InputBorder.none, // Remove default border
                      ),
                      onChanged: (text) {
                        setState(() {}); // Trigger rebuild for live preview
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Markdown(data: _controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      color: Colors.grey[200],
      child: Row(
        children: [
          _buildToolbarButton(
            'H',
            () => _applyMarkdownFormat('## '),
          ), // Heading 2
          _buildToolbarButton('B', () => _applyMarkdownFormat('**')), // Bold
          _buildToolbarButton('I', () => _applyMarkdownFormat('*')), // Italic
          _buildToolbarButton(
            'U',
            () => _applyMarkdownFormat('<u>', '</u>'),
          ), // Underline (HTML for now)
          _buildToolbarButton(
            'S',
            () => _applyMarkdownFormat('~~'),
          ), // Strikethrough
        ],
      ),
    );
  }

  Widget _buildToolbarButton(String text, VoidCallback onPressed) {
    return IconButton(
      icon: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }

  void _applyMarkdownFormat(String markdownTag, [String? closingTag]) {
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
