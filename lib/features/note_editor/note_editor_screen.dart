import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:qsidian/custom_markdown_controller.dart';
import 'package:qsidian/widgets/create_note_dialog.dart';
import 'package:qsidian/core/utils/file_utils.dart'; // Import file utility functions
import 'package:qsidian/features/note_editor/widgets/markdown_toolbar.dart'; // Import MarkdownToolbar

class NoteEditorScreen extends StatefulWidget {
  final String noteFileUri;
  final String? parentFolderUri;

  const NoteEditorScreen({
    super.key,
    required this.noteFileUri,
    this.parentFolderUri,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with TickerProviderStateMixin {
  late CustomMarkdownController _controller;
  String _initialContent = '';
  static const platform = MethodChannel('com.example.qsidian/vault');

  // Edit mode state
  bool _isEditMode = false;

  // Page controller for swipe navigation
  late PageController _pageController;
  int _currentPageIndex = 1; // Start with note content (middle page)

  // Animation controllers
  late AnimationController _modeTransitionController;
  late Animation<double> _modeTransitionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = CustomMarkdownController();
    _controller.addListener(() {
      setState(() {
        // Rebuild when text changes
      });
    });

    // Initialize page controller
    _pageController = PageController(initialPage: 1);

    // Initialize animation controller for mode transitions
    _modeTransitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _modeTransitionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _modeTransitionController,
        curve: Curves.easeInOut,
      ),
    );

    _loadNoteContent();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    _modeTransitionController.dispose();
    super.dispose();
  }

  Future<void> _loadNoteContent() async {
    try {
      final String? content = await platform.invokeMethod('readFileContent', {
        'fileUri': widget.noteFileUri,
      });
      _initialContent = content ?? '';
      _controller.text = _initialContent;
    } on PlatformException catch (e) {
      print("Failed to read file content: '${e.message}'.");
      _initialContent = 'Error loading note: ${e.message}';
      _controller.text = _initialContent;
    }
    setState(() {});
  }

  Future<void> _saveNoteContent() async {
    try {
      await platform.invokeMethod('writeFileContent', {
        'fileUri': widget.noteFileUri,
        'content': _controller.text,
      });

      // Show save confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note saved successfully'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } on PlatformException catch (e) {
      print("Failed to save file content: '${e.message}'.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _createNewNote() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => CreateNoteDialog(), // Use the new CreateNoteDialog
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Create new note in the same folder as current note
        final String newNoteUri = await platform.invokeMethod('createNewNote', {
          'parentFolderUri': widget.parentFolderUri,
          'noteName': result,
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(
                noteFileUri: newNoteUri,
                parentFolderUri: widget.parentFolderUri,
              ),
            ),
          );
        }
      } on PlatformException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create note: ${e.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text(
          'Are you sure you want to delete "${getFileDisplayName(widget.noteFileUri)}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await platform.invokeMethod('deleteFile', {
          'fileUri': widget.noteFileUri,
        });

        if (mounted) {
          Navigator.pop(context);
        }
      } on PlatformException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete note: ${e.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });

    if (_isEditMode) {
      _modeTransitionController.forward();
    } else {
      _modeTransitionController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        children: [
          // Left Panel - Parent Folder Contents (Placeholder for now)
          Container(
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            child: Center(
              child: Text(
                'Folder Contents (Coming soon)',
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ),

          // Center Panel - Note Content
          _buildNoteContentPanel(context),

          // Right Panel - Note Actions
          _buildNoteActionsPanel(context),
        ],
      ),
    );
  }

  Widget _buildNoteContentPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
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
                          getFileDisplayName(widget.noteFileUri), // Use global utility
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _isEditMode ? 'Editing' : 'Reading',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _isEditMode
                                ? colorScheme.secondary
                                : colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Edit/Preview toggle
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isEditMode
                        ? Row(
                            key: const ValueKey('edit_actions'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _saveNoteContent,
                                icon: const Icon(Icons.save_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      colorScheme.secondaryContainer,
                                  foregroundColor:
                                      colorScheme.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _toggleEditMode,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Preview'),
                              ),
                            ],
                          )
                        : Row(
                            key: const ValueKey('preview_actions'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  _pageController.animateToPage(
                                    2,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                icon: const Icon(Icons.more_vert_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.surfaceVariant,
                                  foregroundColor: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _toggleEditMode,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Edit'),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Formatting Toolbar (only in edit mode)
        if (_isEditMode) MarkdownToolbar(controller: _controller), // Use MarkdownToolbar widget

        // Content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isEditMode
                ? _buildEditorView(context)
                : _buildPreviewView(context),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteActionsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Actions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceVariant,
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Actions List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildActionCard(
                  context,
                  Icons.add_rounded,
                  'New Note',
                  'Create a new note in this folder',
                  _createNewNote,
                  colorScheme.secondaryContainer,
                  colorScheme.onSecondaryContainer,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  Icons.edit_rounded,
                  'Rename Note',
                  'Change the title of this note',
                  () {
                    // TODO: Implement rename functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rename feature coming soon'),
                      ),
                    );
                  },
                  colorScheme.surfaceVariant,
                  colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  Icons.share_rounded,
                  'Share Note',
                  'Share this note with others',
                  () {
                    // TODO: Implement share functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share feature coming soon'),
                      ),
                    );
                  },
                  colorScheme.surfaceVariant,
                  colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  Icons.info_outline_rounded,
                  'Note Info',
                  'View note details and metadata',
                  () {
                    // TODO: Implement note info
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note info feature coming soon'),
                      ),
                    );
                  },
                  colorScheme.surfaceVariant,
                  colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 24),
                _buildActionCard(
                  context,
                  Icons.delete_rounded,
                  'Delete Note',
                  'Permanently delete this note',
                  _deleteNote,
                  colorScheme.errorContainer,
                  colorScheme.onErrorContainer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    Color backgroundColor,
    Color foregroundColor,
  ) {
    return Card(
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: foregroundColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: _controller.text.isEmpty
              ? '*This note is empty. Tap Edit to start writing.*'
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
    );
  }
}
