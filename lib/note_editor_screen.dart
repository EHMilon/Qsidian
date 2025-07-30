import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:qsidian/custom_markdown_controller.dart';

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

class FileItem {
  final String uri;
  final String name;
  final bool isDirectory;
  final String displayPath;

  FileItem({
    required this.uri,
    required this.name,
    required this.isDirectory,
    required this.displayPath,
  });
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
  
  // Parent folder contents for left swipe
  List<FileItem> _parentFolderItems = [];
  bool _isLoadingParentFolder = false;
  
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
    
    _modeTransitionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _modeTransitionController,
      curve: Curves.easeInOut,
    ));
    
    _loadNoteContent();
    _loadParentFolderContents();
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
      final String? content = await platform.invokeMethod(
        'readFileContent',
        {'fileUri': widget.noteFileUri},
      );
      _initialContent = content ?? '';
      _controller.text = _initialContent;
    } on PlatformException catch (e) {
      print("Failed to read file content: '${e.message}'.");
      _initialContent = 'Error loading note: ${e.message}';
      _controller.text = _initialContent;
    }
    setState(() {});
  }

  Future<void> _loadParentFolderContents() async {
    if (widget.parentFolderUri == null) return;
    
    setState(() {
      _isLoadingParentFolder = true;
    });

    try {
      final List<dynamic>? folderContents = await platform.invokeMethod(
        'listFolderContents',
        {'folderUri': widget.parentFolderUri},
      );

      if (folderContents != null) {
        List<FileItem> items = [];
        
        for (var item in folderContents) {
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final String uri = itemMap['uri'] ?? '';
          final String name = itemMap['name'] ?? '';
          final bool isDirectory = itemMap['isDirectory'] ?? false;
          
          // Skip hidden files and folders
          if (name.startsWith('.')) continue;
          
          items.add(FileItem(
            uri: uri,
            name: name,
            isDirectory: isDirectory,
            displayPath: _getDisplayPath(uri),
          ));
        }

        // Sort: directories first, then files, both alphabetically
        items.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        setState(() {
          _parentFolderItems = items;
          _isLoadingParentFolder = false;
        });
      }
    } on PlatformException catch (e) {
      print("Failed to load parent folder: '${e.message}'.");
      setState(() {
        _isLoadingParentFolder = false;
      });
    }
  }

  Future<void> _saveNoteContent() async {
    try {
      await platform.invokeMethod(
        'writeFileContent',
        {
          'fileUri': widget.noteFileUri,
          'content': _controller.text,
        },
      );
      
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
      builder: (context) => _CreateNoteDialog(),
    );
    
    if (result != null && result.isNotEmpty) {
      try {
        // Create new note in the same folder as current note
        final String newNoteUri = await platform.invokeMethod(
          'createNewNote',
          {
            'parentFolderUri': widget.parentFolderUri,
            'noteName': result,
          },
        );
        
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
        content: Text('Are you sure you want to delete "${_getFileDisplayName(widget.noteFileUri)}"?'),
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
        await platform.invokeMethod(
          'deleteFile',
          {'fileUri': widget.noteFileUri},
        );
        
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

  String _getFileDisplayName(String fileUri) {
    try {
      final Uri parsedUri = Uri.parse(fileUri);
      if (parsedUri.pathSegments.isNotEmpty) {
        final String lastSegment = parsedUri.pathSegments.last;
        String decoded = Uri.decodeComponent(lastSegment);
        // Remove .md extension for display
        if (decoded.endsWith('.md')) {
          decoded = decoded.substring(0, decoded.length - 3);
        }
        return decoded;
      }
    } catch (e) {
      final int lastSlashIndex = fileUri.lastIndexOf('/');
      if (lastSlashIndex != -1 && lastSlashIndex < fileUri.length - 1) {
        String filename = fileUri.substring(lastSlashIndex + 1);
        try {
          filename = Uri.decodeComponent(filename);
          if (filename.endsWith('.md')) {
            filename = filename.substring(0, filename.length - 3);
          }
          return filename;
        } catch (e2) {
          return filename;
        }
      }
    }
    return "Unknown File";
  }

  String _getDisplayPath(String uri) {
    try {
      final int lastSlashIndex = uri.lastIndexOf('/');
      if (lastSlashIndex != -1 && lastSlashIndex < uri.length - 1) {
        final String filename = uri.substring(lastSlashIndex + 1);
        try {
          return Uri.decodeComponent(filename);
        } catch (e) {
          return filename;
        }
      }
      return "";
    } catch (e) {
      return "";
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
          // Left Panel - Parent Folder Contents
          _buildParentFolderPanel(context),
          
          // Center Panel - Note Content
          _buildNoteContentPanel(context),
          
          // Right Panel - Note Actions
          _buildNoteActionsPanel(context),
        ],
      ),
    );
  }

  Widget _buildParentFolderPanel(BuildContext context) {
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Folder Contents',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Notes in this folder',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
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
          
          // Content
          Expanded(
            child: _isLoadingParentFolder
                ? const Center(child: CircularProgressIndicator())
                : _parentFolderItems.isEmpty
                    ? _buildEmptyFolderState(context)
                    : _buildParentFolderList(context),
          ),
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
                                  backgroundColor: colorScheme.secondaryContainer,
                                  foregroundColor: colorScheme.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _toggleEditMode,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        if (_isEditMode) _buildFormattingToolbar(context),
        
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
                      const SnackBar(content: Text('Rename feature coming soon')),
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
                      const SnackBar(content: Text('Share feature coming soon')),
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
                      const SnackBar(content: Text('Note info feature coming soon')),
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
                child: Icon(
                  icon,
                  color: foregroundColor,
                  size: 24,
                ),
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
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
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

  Widget _buildEmptyFolderState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 40,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No other notes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This folder only contains the current note.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentFolderList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _parentFolderItems.length,
      itemBuilder: (context, index) {
        final item = _parentFolderItems[index];
        final isMarkdown = item.name.endsWith('.md') || item.name.endsWith('.markdown');
        final isCurrentNote = item.uri == widget.noteFileUri;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isCurrentNote ? null : () {
                if (item.isDirectory) {
                  // TODO: Navigate to folder
                } else if (isMarkdown) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditorScreen(
                        noteFileUri: item.uri,
                        parentFolderUri: widget.parentFolderUri,
                      ),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isCurrentNote 
                        ? colorScheme.outline
                        : colorScheme.outlineVariant,
                    width: isCurrentNote ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isCurrentNote 
                      ? colorScheme.surfaceVariant.withOpacity(0.5)
                      : null,
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.isDirectory 
                            ? colorScheme.tertiaryContainer
                            : isMarkdown 
                                ? colorScheme.secondaryContainer
                                : colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.isDirectory 
                            ? Icons.folder_rounded
                            : isMarkdown 
                                ? Icons.description_rounded
                                : Icons.insert_drive_file_rounded,
                        color: item.isDirectory 
                            ? colorScheme.onTertiaryContainer
                            : isMarkdown 
                                ? colorScheme.onSecondaryContainer
                                : colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isCurrentNote ? FontWeight.w600 : FontWeight.w500,
                              color: isCurrentNote 
                                  ? colorScheme.onSurface
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isCurrentNote) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Current note',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Arrow for folders or current indicator
                    if (isCurrentNote)
                      Icon(
                        Icons.radio_button_checked_rounded,
                        color: colorScheme.secondary,
                        size: 20,
                      )
                    else if (item.isDirectory)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurface.withOpacity(0.4),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

class _CreateNoteDialog extends StatefulWidget {
  @override
  _CreateNoteDialogState createState() => _CreateNoteDialogState();
}

class _CreateNoteDialogState extends State<_CreateNoteDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Note'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Note name',
            hintText: 'Enter note name',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a note name';
            }
            return null;
          },
          autofocus: true,
          onFieldSubmitted: (value) {
            if (_formKey.currentState?.validate() == true) {
              Navigator.pop(context, value.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}