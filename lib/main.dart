import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:qsidian/note_editor_screen.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel

void
main() {
  runApp(
    const MyApp(),
  );
}

class MyApp
    extends
        StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qsidian',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5CF6), // Purple theme to match app icon
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
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

class MyHomePage
    extends
        StatefulWidget {
  const MyHomePage({
    super.key,
  });

  @override
  State<
    MyHomePage
  >
  createState() => _MyHomePageState();
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

class _MyHomePageState
    extends
        State<
          MyHomePage
        > with TickerProviderStateMixin {
  String? _vaultUri; // Changed to _vaultUri to store the content URI
  String? _currentFolderUri; // Current folder being viewed
  List<FileItem> _currentItems = []; // Current folder contents
  List<String> _navigationStack = []; // For back navigation
  static const platform = MethodChannel(
    'com.example.qsidian/vault',
  );
  
  // Page controller for swipe navigation
  late PageController _pageController;
  int _currentPageIndex = 1; // Start with the main content (middle page)
  
  // Animation controller for drawer-like behavior
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  
  // Search functionality
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<FileItem> _filteredItems = [];

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
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Set up MethodChannel to receive vault URI from Android
    platform.setMethodCallHandler(
      (
        call,
      ) async {
        print("DEBUG: MethodChannel call received: ${call.method}");
        if (call.method ==
            "vaultSelected") {
          final String? vaultUriString =
              call.arguments
                  as String?;
          print("DEBUG: Vault URI received: $vaultUriString");
          if (vaultUriString !=
              null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'vaultUri',
              vaultUriString,
            );
            print("DEBUG: Vault URI saved to preferences");
            setState(
              () {
                _vaultUri = vaultUriString;
                _currentFolderUri = vaultUriString;
                _navigationStack.clear();
              },
            );
            print("DEBUG: State updated, calling _loadCurrentFolder");
            await _loadCurrentFolder();
            await _sendDataToWidget();
          }
        }
      },
    );
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
        _searchQuery = '';
        _searchController.clear();
        _filteredItems.clear();
      }
    });
  }
  
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredItems.clear();
      } else {
        _filteredItems = _currentItems.where((item) {
          return item.name.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }
  
  Future<void> _createNewNote() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CreateNoteDialog(),
    );
    
    if (result != null && result.isNotEmpty) {
      try {
        // Create new note in current folder
        final String newNoteUri = await platform.invokeMethod(
          'createNewNote',
          {
            'parentFolderUri': _currentFolderUri,
            'noteName': result,
          },
        );
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(
                noteFileUri: newNoteUri,
                parentFolderUri: _currentFolderUri,
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

  Future<
    void
  >
  _requestPermissions() async {
    await Permission.storage.request();
  }

  Future<
    void
  >
  _loadVaultPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(
      () {
        _vaultUri = prefs.getString(
          'vaultUri',
        ); // Changed to vaultUri
      },
    );
    if (_vaultUri !=
        null) {
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

  Future<
    void
  >
  _selectVaultFolder() async {
    try {
      await platform.invokeMethod(
        'openDirectoryPicker',
      );
      // The result will be handled by the MethodChannel listener in initState
    } on PlatformException catch (
      e
    ) {
      print(
        "Failed to open directory picker: '${e.message}'.",
      );
    }
  }

  Future<void> _loadCurrentFolder() async {
    print("DEBUG: _loadCurrentFolder called with _currentFolderUri: $_currentFolderUri");
    
    if (_currentFolderUri == null) {
      print("DEBUG: _currentFolderUri is null, setting empty items");
      setState(() {
        _currentItems = [];
      });
      return;
    }

    try {
      print("DEBUG: Calling platform method listFolderContents with URI: $_currentFolderUri");
      final List<dynamic>? folderContents = await platform.invokeMethod(
        'listFolderContents',
        {'folderUri': _currentFolderUri},
      );

      print("DEBUG: Platform method returned: $folderContents");

      if (folderContents != null) {
        List<FileItem> items = [];
        
        print("DEBUG: Processing ${folderContents.length} items");
        for (var item in folderContents) {
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final String uri = itemMap['uri'] ?? '';
          final String name = itemMap['name'] ?? '';
          final bool isDirectory = itemMap['isDirectory'] ?? false;
          
          print("DEBUG: Processing item - name: $name, isDirectory: $isDirectory, uri: $uri");
          
          // Skip hidden files and folders (starting with .)
          if (name.startsWith('.')) {
            print("DEBUG: Skipping hidden item: $name");
            continue;
          }
          
          items.add(FileItem(
            uri: uri,
            name: name,
            isDirectory: isDirectory,
            displayPath: _getDisplayPath(uri),
          ));
        }

        print("DEBUG: After filtering, we have ${items.length} items");

        // Sort: directories first, then files, both alphabetically
        items.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        print("DEBUG: Setting state with ${items.length} items");
        setState(() {
          _currentItems = items;
        });
      } else {
        print("DEBUG: folderContents is null");
        setState(() {
          _currentItems = [];
        });
      }
    } on PlatformException catch (e) {
      print("DEBUG: PlatformException: ${e.message}");
      setState(() {
        _currentItems = [];
      });
    } catch (e) {
      print("DEBUG: General exception: $e");
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

  String _getDisplayPath(String uri) {
    try {
      if (_vaultUri == null) return "";
      
      // Simple approach: just extract the filename
      final int lastSlashIndex = uri.lastIndexOf('/');
      if (lastSlashIndex != -1 && lastSlashIndex < uri.length - 1) {
        final String filename = uri.substring(lastSlashIndex + 1);
        try {
          return Uri.decodeComponent(filename);
        } catch (e) {
          return filename; // Return raw filename if decoding fails
        }
      }
      return "";
    } catch (e) {
      return "";
    }
  }

  String _getCurrentFolderName() {
    if (_currentFolderUri == null || _vaultUri == null) return "Vault";
    if (_currentFolderUri == _vaultUri) return "Vault Root";
    
    try {
      final Uri uri = Uri.parse(_currentFolderUri!);
      if (uri.pathSegments.isNotEmpty) {
        return Uri.decodeComponent(uri.pathSegments.last);
      }
    } catch (e) {
      print("Error getting folder name: $e");
    }
    return "Folder";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _vaultUri == null ? _buildWelcomeScreen(context) : _buildMainContent(context),
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
                    color: colorScheme.primary.withOpacity(0.3),
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
                color: colorScheme.onSurface.withOpacity(0.7),
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

  Widget _buildFeatureItem(IconData icon, String title, String description, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: colorScheme.onPrimaryContainer,
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
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
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
          _currentPageIndex = index;
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
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        children: [
          // File Browser Header
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
                    if (_navigationStack.isNotEmpty)
                      IconButton(
                        onPressed: _navigateBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceVariant,
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
                          _buildBreadcrumb(context),
                        ],
                      ),
                    ),
                    
                    IconButton(
                      onPressed: _selectVaultFolder,
                      icon: const Icon(Icons.folder_open_rounded),
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
          
          // File List
          Expanded(
            child: _currentItems.isEmpty
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
                            _getCurrentFolderName(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _getVaultDisplayName(_vaultUri) ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Action buttons
                    IconButton(
                      onPressed: _toggleSearch,
                      icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: _isSearching 
                            ? colorScheme.secondaryContainer
                            : colorScheme.surfaceVariant,
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
                        backgroundColor: colorScheme.surfaceVariant,
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Main Content
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                            color: colorScheme.primary.withOpacity(0.3),
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
                      'Swipe left to browse files\nSwipe right for more options',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
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
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        children: [
          // Right Panel Header
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
                        backgroundColor: colorScheme.surfaceVariant,
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
                        color: colorScheme.surfaceVariant,
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
                        color: colorScheme.onSurface.withOpacity(0.7),
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
              'This folder is empty',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No files or folders found in this location.',
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

  Widget _buildFileList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _currentItems.length,
      itemBuilder: (context, index) {
        final item = _currentItems[index];
        final isMarkdown = item.name.endsWith('.md') || item.name.endsWith('.markdown');
        
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
                                color: colorScheme.onSurface.withOpacity(0.6),
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

  String _getVaultDisplayName(String? uriString) {
    if (uriString == null) return "No Vault Selected";
    try {
      final Uri uri = Uri.parse(uriString);
      // The last segment of the path is usually the folder name.
      // We need to handle cases where the URI path might be something like
      // 'tree/primary:My%20NoteBooks%20/Programming'
      // We want to extract 'Programming'
      String path = Uri.decodeComponent(uri.path);
      List<String> segments = path.split('/').where((s) => s.isNotEmpty).toList();

      // Find the segment that contains the actual folder name (e.g., after 'primary:')
      for (String segment in segments) {
        if (segment.contains(':')) {
          return segment.split(':').last;
        }
      }
      // Fallback if no ':' is found, return the last segment
      return segments.isNotEmpty ? segments.last : "Selected Vault";
    } catch (e) {
      print("Error parsing vault URI: $e");
      return "Selected Vault";
    }
  }

  String _getRelativePath(String fileUri) {
    try {
      final String vaultUriString = _vaultUri ?? '';
      final Uri fileParsedUri = Uri.parse(fileUri);
      final Uri vaultParsedUri = Uri.parse(vaultUriString);

      // Get the path segments, decoding them
      List<String> fileSegments = fileParsedUri.pathSegments.map((s) => Uri.decodeComponent(s)).toList();
      List<String> vaultSegments = vaultParsedUri.pathSegments.map((s) => Uri.decodeComponent(s)).toList();

      // Find the common root in the path segments to determine the relative path
      // This handles variations like 'tree/primary:...' and 'document/primary:...'
      int commonPrefixEndIndex = 0;
      for (int i = 0; i < fileSegments.length && i < vaultSegments.length; i++) {
        if (fileSegments[i] == vaultSegments[i]) {
          commonPrefixEndIndex = i + 1;
        } else {
          break;
        }
      }

      // Extract segments after the common prefix
      List<String> relativeSegments = fileSegments.sublist(commonPrefixEndIndex);

      // Remove the filename from the relative path to get just the directory
      if (relativeSegments.isNotEmpty) {
        relativeSegments = relativeSegments.sublist(0, relativeSegments.length - 1);
      }

      final String directory = relativeSegments.join('/');
      return directory.isEmpty ? "Root" : directory;
    } catch (e) {
      print("Error getting relative path: $e");
      return "Root";
    }
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (_currentFolderUri == null || _vaultUri == null) {
      return Text(
        "Vault",
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      );
    }

    if (_currentFolderUri == _vaultUri) {
      return Text(
        "Root",
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      );
    }

    // Build breadcrumb from navigation stack
    List<String> breadcrumbParts = [];
    
    // Add root
    breadcrumbParts.add("Root");
    
    // Add intermediate folders from navigation stack
    for (String folderUri in _navigationStack) {
      if (folderUri != _vaultUri) {
        try {
          final Uri uri = Uri.parse(folderUri);
          if (uri.pathSegments.isNotEmpty) {
            breadcrumbParts.add(Uri.decodeComponent(uri.pathSegments.last));
          }
        } catch (e) {
          // Skip invalid URIs
        }
      }
    }
    
    // Add current folder
    breadcrumbParts.add(_getCurrentFolderName());

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < breadcrumbParts.length; i++) ...[
            if (i > 0) 
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
            Text(
              breadcrumbParts[i],
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontWeight: i == breadcrumbParts.length - 1 ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
