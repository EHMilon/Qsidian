import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/quick_note_service.dart';
import 'folder_selection_overlay.dart';

class QuickNoteWidget extends StatefulWidget {
  final bool isTransparent;
  final String? vaultUri;
  final VoidCallback? onNoteCreated;
  final VoidCallback? onNoteDeleted;

  const QuickNoteWidget({
    super.key,
    this.isTransparent = false,
    required this.vaultUri,
    this.onNoteCreated,
    this.onNoteDeleted,
  });

  @override
  State<QuickNoteWidget> createState() => _QuickNoteWidgetState();
}

class _QuickNoteWidgetState extends State<QuickNoteWidget> {
  // Services
  final QuickNoteService _service = QuickNoteService();

  // Text controllers for title and content input
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // Folder selection state
  String? _selectedFolderUri;
  String _selectedFolderName = 'Root';

  // Recent notes state
  List<FileItem> _recentNotes = [];

  // Editing state
  bool _isEditingExistingNote = false;
  String? _currentEditingNoteUri;

  // Overlay state
  OverlayEntry? _folderOverlay;
  OverlayEntry? _recentNotesOverlay;

  // Focus nodes for proper keyboard handling
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

  // Content field expansion state
  static const int _minLines = 2;
  static const int _maxLines = 4;
  int _currentLines = _minLines;

  @override
  void initState() {
    super.initState();
    _initializeWidget();
    _setupContentFieldListener();
  }

  void _setupContentFieldListener() {
    _contentController.addListener(() {
      final text = _contentController.text;
      final lines = '\n'.allMatches(text).length + 1;
      final newLines = lines.clamp(_minLines, _maxLines);

      if (newLines != _currentLines) {
        setState(() {
          _currentLines = newLines;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _dismissOverlays();
    super.dispose();
  }

  void _initializeWidget() {
    // Load last selected folder from preferences asynchronously
    if (widget.vaultUri != null) {
      _loadLastSelectedFolder();
    }
  }

  Future<void> _loadLastSelectedFolder() async {
    try {
      final lastFolder = await _service.getLastSelectedFolder();
      if (mounted) {
        setState(() {
          _selectedFolderUri = lastFolder['uri']!.isEmpty
              ? widget.vaultUri
              : lastFolder['uri'];
          _selectedFolderName = lastFolder['name']!;
        });
      }
    } catch (e) {
      // Use default values if loading fails
      if (mounted) {
        setState(() {
          _selectedFolderUri = widget.vaultUri;
          _selectedFolderName = 'Root';
        });
      }
    }
  }

  void _dismissOverlays() {
    _folderOverlay?.remove();
    _folderOverlay = null;
    _recentNotesOverlay?.remove();
    _recentNotesOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: widget.isTransparent
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: const Color(0xFF8B5CF6), // Purple border
          width: 2.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Note',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                IconButton(
                  onPressed: _onExpandPressed,
                  icon: const Icon(Icons.north_east),
                  iconSize: 18.0,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 20.0,
                    minHeight: 20.0,
                  ),
                ),
              ],
            ),
            _buildTitleField(),
            const SizedBox(height: 8.0),
            _buildContentField(),
            const SizedBox(height: 8.0),
            _buildBottomToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      decoration: InputDecoration(
        hintText: 'What is the title of your note?',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 8.0,
        ),
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildContentField() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: _minLines * 24.0, // Approximate line height
        maxHeight: _maxLines * 24.0, // Maximum height before scrolling
      ),
      child: TextField(
        controller: _contentController,
        focusNode: _contentFocusNode,
        maxLines: _currentLines >= _maxLines ? _maxLines : null,
        minLines: _minLines,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          hintText: 'Write your Quick Note here.....',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 12.0,
          ),
          alignLabelWithHint: true,
        ),
        style: Theme.of(context).textTheme.bodyMedium,
        scrollPhysics: _currentLines >= _maxLines
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side - Folder selection
        _buildFolderButton(),

        // Right side - Action buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAttachmentButton(),
            const SizedBox(width: 8.0),
            _buildDeleteButton(),
            const SizedBox(width: 8.0),
            _buildRecentButton(),
            const SizedBox(width: 8.0),
            _buildSaveButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildFolderButton() {
    return InkWell(
      onTap: _onFolderPressed,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder,
              size: 20.0,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4.0),
            Text(
              _selectedFolderName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentButton() {
    return IconButton(
      onPressed: _onAttachmentPressed,
      icon: const Icon(Icons.attach_file),
      iconSize: 20.0,
      padding: const EdgeInsets.all(4.0),
      constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
    );
  }

  Widget _buildDeleteButton() {
    return IconButton(
      onPressed: _onDeletePressed,
      icon: const Icon(Icons.delete_outline),
      iconSize: 20.0,
      padding: const EdgeInsets.all(4.0),
      constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
    );
  }

  Widget _buildRecentButton() {
    return IconButton(
      onPressed: _onRecentPressed,
      icon: const Icon(Icons.history),
      iconSize: 20.0,
      padding: const EdgeInsets.all(4.0),
      constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
    );
  }

  Widget _buildSaveButton() {
    return IconButton(
      onPressed: _onSavePressed,
      icon: const Icon(Icons.save),
      iconSize: 20.0,
      padding: const EdgeInsets.all(4.0),
      constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
    );
  }

  // Event handlers - to be implemented in future tasks
  void _onExpandPressed() {
    // TODO: Implement expand/resize functionality
  }

  void _onFolderPressed() {
    if (widget.vaultUri == null) return;

    // Dismiss any existing overlays
    _dismissOverlays();

    // Create the folder selection overlay
    _folderOverlay = OverlayEntry(builder: (context) => _buildFolderOverlay());

    // Insert the overlay
    Overlay.of(context).insert(_folderOverlay!);
  }

  Widget _buildFolderOverlay() {
    return Stack(
      children: [
        // Backdrop to dismiss overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismissOverlays,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Overlay positioned above the folder button
        Positioned(
          left: 24.0,
          right: 24.0,
          bottom:
              MediaQuery.of(context).size.height *
              0.3, // Position above the widget
          child: FolderSelectionOverlay(
            vaultUri: widget.vaultUri!,
            currentSelection: _selectedFolderUri,
            onFolderSelected: _onFolderSelected,
            onDismiss: _dismissOverlays,
          ),
        ),
      ],
    );
  }

  void _onFolderSelected(String folderUri, String folderName) async {
    setState(() {
      _selectedFolderUri = folderUri;
      _selectedFolderName = folderName;
    });

    // Save the selection to preferences
    try {
      await _service.saveLastSelectedFolder(folderUri, folderName);
    } catch (e) {
      // Silently fail if we can't save preferences
    }
  }

  void _onAttachmentPressed() {
    // TODO: Implement image attachment functionality
  }

  void _onDeletePressed() {
    // TODO: Implement delete/clear functionality
  }

  void _onRecentPressed() {
    // TODO: Implement recent notes overlay
  }

  void _onSavePressed() {
    // TODO: Implement note saving functionality
  }
}
