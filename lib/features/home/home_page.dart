import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
import 'package:qsidian/models/file_item.dart';

import 'package:qsidian/features/note_editor/note_editor_screen.dart'; // Updated import path
import 'package:qsidian/core/utils/file_utils.dart'; // Import file utility functions
import 'package:qsidian/widgets/quick_note_widget.dart'; // Import QuickNoteWidget

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  String? _vaultUri; // Changed to _vaultUri to store the content URI
  String? _currentFolderUri; // Current folder being viewed
  List<FileItem> _currentItems = []; // Current folder contents
  final List<String> _navigationStack = []; // For back navigation (made final)
  static const platform = MethodChannel('com.example.qsidian/vault');

  // Page controller for swipe navigation
  late PageController _pageController;

  // Animation controller for drawer-like behavior (kept for potential future use)
  late AnimationController _animationController;

  // Search functionality
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadVaultPath();

    // Initialize page controller
    _pageController = PageController(initialPage: 1);

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Set up MethodChannel to receive vault URI from Android
    platform.setMethodCallHandler((call) async {
      if (call.method == "vaultSelected") {
        final String? vaultUriString = call.arguments as String?;
        if (vaultUriString != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('vaultUri', vaultUriString);
          setState(() {
            _vaultUri = vaultUriString;
            _currentFolderUri = vaultUriString;
            _navigationStack.clear();
          });
          await _loadCurrentFolder();
          await _sendDataToWidget();
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  // Simplified search to be used directly in build method
  List<FileItem> get _currentDisplayItems {
    if (_isSearching && _searchController.text.isNotEmpty) {
      return _currentItems.where((item) {
        return item.name.toLowerCase().contains(
          _searchController.text.toLowerCase(),
        );
      }).toList();
    }
    return _currentItems;
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
  }

  Future<void> _loadVaultPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vaultUri = prefs.getString('vaultUri'); // Changed to vaultUri
    });
    if (_vaultUri != null) {
      _currentFolderUri = _vaultUri;
      _loadCurrentFolder();
    }
  }

  Future<void> _sendDataToWidget() async {
    if (_vaultUri != null) {
      await HomeWidget.saveWidgetData('vaultPath', _vaultUri);
      // For now, we'll send an empty list since we're using folder navigation
      await HomeWidget.saveWidgetData('markdownFilePaths', jsonEncode([]));
      await HomeWidget.updateWidget(name: 'QsidianWidget');
    }
  }

  Future<void> _selectVaultFolder() async {
    try {
      await platform.invokeMethod('openDirectoryPicker');
      // The result will be handled by the MethodChannel listener in initState
    } on PlatformException {
      // Handle error silently
    }
  }

  Future<void> _loadCurrentFolder() async {
    if (_currentFolderUri == null) {
      setState(() {
        _currentItems = [];
      });
      return;
    }

    try {
      final List<dynamic>? folderContents = await platform.invokeMethod(
        'listFolderContents',
        {'folderUri': _currentFolderUri},
      );

      if (folderContents != null) {
        List<FileItem> items = [];

        for (var item in folderContents) {
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final String uri = itemMap['uri'] ?? '';
          final String name = itemMap['name'] ?? '';
          final bool isDirectory = itemMap['isDirectory'] ?? false;

          // Skip hidden files and folders (starting with .)
          if (name.startsWith('.')) {
            continue;
          }

          items.add(
            FileItem(
              uri: uri,
              name: name,
              isDirectory: isDirectory,
              displayPath: getDisplayPath(uri), // Use global utility
            ),
          );
        }

        // Sort: directories first, then files, both alphabetically
        items.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        setState(() {
          _currentItems = items;
        });
      } else {
        setState(() {
          _currentItems = [];
        });
      }
    } on PlatformException {
      setState(() {
        _currentItems = [];
      });
    } catch (_) {
      setState(() {
        _currentItems = [];
      });
    }
  }

  void _navigateToFolder(String folderUri) {
    if (_currentFolderUri != null) {
      _navigationStack.add(_currentFolderUri!);
    }
    setState(() {
      _currentFolderUri = folderUri;
    });
    _loadCurrentFolder();
  }

  void _navigateBack() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _currentFolderUri = _navigationStack.removeLast();
      });
      _loadCurrentFolder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _vaultUri == null
          ? _buildWelcomeScreen(context)
          : _buildMainContent(context),
    );
  }

  Widget _buildWelcomeScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon and Title
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 60,
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'Welcome to Qsidian',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Your modern markdown note-taking companion.\nSelect your vault to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),

            // Select Vault Button
            FilledButton.icon(
              onPressed: _selectVaultFolder,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Select Vault Folder'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Features
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildFeatureItem(
                      Icons.folder_rounded,
                      'Organize',
                      'Browse your notes in folders',
                      colorScheme,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      Icons.edit_rounded,
                      'Write',
                      'Markdown editor with live preview',
                      colorScheme,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      Icons.sync_rounded,
                      'Sync',
                      'Works with your existing files',
                      colorScheme,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String description,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          // _currentPageIndex = index; // Removed unused field
        });
      },
      children: [
        // Left Panel - File Browser
        _buildFileBrowserPanel(context),

        // Center Panel - Main Content
        _buildCenterPanel(context),

        // Right Panel - Empty for now
        _buildRightPanel(context),
      ],
    );
  }

  Widget _buildFileBrowserPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest.withAlpha(
        (255 * 0.3).round(),
      ), // Deprecated withOpacity and surfaceVariant
      child: Column(
        children: [
          // File Browser Header
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
                    if (_navigationStack.isNotEmpty)
                      IconButton(
                        onPressed: _navigateBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          foregroundColor: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (_navigationStack.isNotEmpty) const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Files',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          buildBreadcrumb(
                            // Use global utility
                            context,
                            _currentFolderUri,
                            _vaultUri,
                            _navigationStack,
                            () => getCurrentFolderNameUtil(
                              _currentFolderUri,
                              _vaultUri,
                            ), // Pass a function reference
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      onPressed: _selectVaultFolder,
                      icon: const Icon(Icons.folder_open_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // File List
          Expanded(
            child:
                _currentDisplayItems
                    .isEmpty // Use filtered items
                ? _buildEmptyState(context)
                : _buildFileList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Center Panel Header
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
                    // Menu button to show file browser
                    IconButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(Icons.menu_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            getCurrentFolderNameUtil(
                              _currentFolderUri,
                              _vaultUri,
                            ), // Use global utility
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            getVaultDisplayName(
                              _vaultUri,
                            ), // Use global utility
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    IconButton(
                      onPressed: _toggleSearch,
                      icon: Icon(
                        _isSearching
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isSearching
                            ? colorScheme.secondaryContainer
                            : colorScheme.surfaceContainerHighest,
                        foregroundColor: _isSearching
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                        backgroundColor: colorScheme
                            .surfaceContainerHighest, // Deprecated surfaceVariant
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Content - QuickNoteWidget
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Welcome header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Text(
                          'Quick Note',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create notes quickly and save them to your vault',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // QuickNoteWidget
                  QuickNoteWidget(
                    vaultUri: _vaultUri,
                    onNoteCreated: () {
                      // Refresh the file list when a note is created
                      _loadCurrentFolder();
                    },
                    onNoteDeleted: () {
                      // Refresh the file list when a note is deleted
                      _loadCurrentFolder();
                    },
                  ),

                  const SizedBox(height: 24),

                  // Quick actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          _pageController.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: const Icon(Icons.folder_rounded),
                        label: const Text('Browse Files'),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: _selectVaultFolder,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Change Vault'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest.withAlpha(
        (255 * 0.3).round(),
      ), // Deprecated withOpacity and surfaceVariant
      child: Column(
        children: [
          // Right Panel Header
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
                        'Options',
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
                        backgroundColor: colorScheme
                            .surfaceContainerHighest, // Deprecated surfaceVariant
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right Panel Content
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colorScheme
                            .surfaceContainerHighest, // Deprecated surfaceVariant
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.settings_rounded,
                        size: 40,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Coming Soon',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Settings and additional features will be available here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                color: colorScheme
                    .surfaceContainerHighest, // Deprecated surfaceVariant
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
              'This folder is empty',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No files or folders found in this location.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _currentDisplayItems.length, // Use filtered items
      itemBuilder: (context, index) {
        final item = _currentDisplayItems[index]; // Use filtered items
        final isMarkdown =
            item.name.endsWith('.md') || item.name.endsWith('.markdown');

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (item.isDirectory) {
                  _navigateToFolder(item.uri);
                } else if (isMarkdown) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditorScreen(
                        noteFileUri: item.uri,
                        parentFolderUri: _currentFolderUri,
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
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.isDirectory
                            ? colorScheme.primaryContainer
                            : isMarkdown
                            ? colorScheme.secondaryContainer
                            : colorScheme
                                  .surfaceContainerHighest, // Deprecated surfaceVariant
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.isDirectory
                            ? Icons.folder_rounded
                            : isMarkdown
                            ? Icons.description_rounded
                            : Icons.insert_drive_file_rounded,
                        color: item.isDirectory
                            ? colorScheme.onPrimaryContainer
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
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.displayPath.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.displayPath,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Arrow for folders
                    if (item.isDirectory)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
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
}
