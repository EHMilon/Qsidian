import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/quick_note_service.dart';

class FolderSelectionOverlay extends StatefulWidget {
  final String vaultUri;
  final String? currentSelection;
  final Function(String folderUri, String folderName) onFolderSelected;
  final VoidCallback onDismiss;

  const FolderSelectionOverlay({
    super.key,
    required this.vaultUri,
    this.currentSelection,
    required this.onFolderSelected,
    required this.onDismiss,
  });

  @override
  State<FolderSelectionOverlay> createState() => _FolderSelectionOverlayState();
}

class _FolderSelectionOverlayState extends State<FolderSelectionOverlay> {
  final QuickNoteService _service = QuickNoteService();
  List<FileItem> _folders = [];
  final Map<String, List<FileItem>> _subfolderCache = {};
  final Set<String> _expandedFolders = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final folders = await _service.getFolderStructure(widget.vaultUri);

      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load folders: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<FileItem>> _loadSubfolders(String folderUri) async {
    if (_subfolderCache.containsKey(folderUri)) {
      return _subfolderCache[folderUri]!;
    }

    try {
      final subfolders = await _service.getFolderStructure(folderUri);
      _subfolderCache[folderUri] = subfolders;
      return subfolders;
    } catch (e) {
      return [];
    }
  }

  void _toggleFolder(String folderUri) async {
    if (_expandedFolders.contains(folderUri)) {
      setState(() {
        _expandedFolders.remove(folderUri);
      });
    } else {
      // Load subfolders if not already cached
      if (!_subfolderCache.containsKey(folderUri)) {
        final subfolders = await _loadSubfolders(folderUri);
        setState(() {
          _subfolderCache[folderUri] = subfolders;
          _expandedFolders.add(folderUri);
        });
      } else {
        setState(() {
          _expandedFolders.add(folderUri);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300, minWidth: 250),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Flexible(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(
            Icons.folder,
            size: 20.0,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8.0),
          Text(
            'Select Folder',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onDismiss,
            icon: const Icon(Icons.close),
            iconSize: 18.0,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24.0, minHeight: 24.0),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 32.0,
            ),
            const SizedBox(height: 8.0),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            TextButton(onPressed: _loadFolders, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        // Root folder option
        _buildFolderTile(
          folderUri: widget.vaultUri,
          folderName: 'Root',
          level: 0,
          isSelected:
              widget.currentSelection == widget.vaultUri ||
              widget.currentSelection == null ||
              widget.currentSelection!.isEmpty,
        ),
        // Other folders
        ..._buildFolderTree(_folders, 0),
      ],
    );
  }

  List<Widget> _buildFolderTree(List<FileItem> folders, int level) {
    final List<Widget> widgets = [];

    for (final folder in folders) {
      final isExpanded = _expandedFolders.contains(folder.uri);
      final hasSubfolders = _subfolderCache[folder.uri]?.isNotEmpty ?? false;
      final isSelected = widget.currentSelection == folder.uri;

      widgets.add(
        _buildFolderTile(
          folderUri: folder.uri,
          folderName: folder.name,
          level: level,
          isSelected: isSelected,
          hasSubfolders: hasSubfolders,
          isExpanded: isExpanded,
          onToggle: () => _toggleFolder(folder.uri),
        ),
      );

      // Add subfolders if expanded
      if (isExpanded && _subfolderCache.containsKey(folder.uri)) {
        final subfolders = _subfolderCache[folder.uri]!;
        widgets.addAll(_buildFolderTree(subfolders, level + 1));
      }
    }

    return widgets;
  }

  Widget _buildFolderTile({
    required String folderUri,
    required String folderName,
    required int level,
    required bool isSelected,
    bool hasSubfolders = false,
    bool isExpanded = false,
    VoidCallback? onToggle,
  }) {
    return InkWell(
      onTap: () {
        widget.onFolderSelected(folderUri, folderName);
        widget.onDismiss();
      },
      child: Container(
        padding: EdgeInsets.only(
          left: 16.0 + (level * 24.0),
          right: 16.0,
          top: 8.0,
          bottom: 8.0,
        ),
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : null,
        child: Row(
          children: [
            // Expand/collapse icon for folders with subfolders
            if (hasSubfolders)
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16.0,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              )
            else
              const SizedBox(width: 16.0),

            const SizedBox(width: 4.0),

            // Folder icon
            Icon(
              Icons.folder,
              size: 16.0,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),

            const SizedBox(width: 8.0),

            // Folder name
            Expanded(
              child: Text(
                folderName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  fontWeight: isSelected ? FontWeight.w500 : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Selected indicator
            if (isSelected)
              Icon(
                Icons.check,
                size: 16.0,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
