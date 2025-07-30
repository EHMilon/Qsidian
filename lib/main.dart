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
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      title: 'Qsidian',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: const MyHomePage(),
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

class _MyHomePageState
    extends
        State<
          MyHomePage
        > {
  String? _vaultUri; // Changed to _vaultUri to store the content URI
  List<
    String
  >
  _markdownFileUris = []; // Changed to store URIs as strings
  static const platform = MethodChannel(
    'com.example.qsidian/vault',
  );

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadVaultPath();

    // Set up MethodChannel to receive vault URI from Android
    platform.setMethodCallHandler(
      (
        call,
      ) async {
        if (call.method ==
            "vaultSelected") {
          final String? vaultUriString =
              call.arguments
                  as String?;
          if (vaultUriString !=
              null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'vaultUri',
              vaultUriString,
            );
            setState(
              () {
                _vaultUri = vaultUriString;
              },
            );
            await _loadMarkdownFiles();
            await _sendDataToWidget();
            print(
              "Vault URI received from Android: $_vaultUri",
            );
          }
        }
      },
    );
  }

  Future<
    void
  >
  _requestPermissions() async {
    if (await Permission.storage.request().isGranted) {
      print(
        "Storage permission granted",
      );
    } else {
      print(
        "Storage permission denied",
      );
    }
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
      _loadMarkdownFiles();
    }
  }

  Future<
    void
  >
  _sendDataToWidget() async {
    if (_vaultUri !=
        null) {
      await HomeWidget.saveWidgetData(
        'vaultPath',
        _vaultUri,
      ); // Send URI
      await HomeWidget.saveWidgetData(
        'markdownFilePaths',
        jsonEncode(
          _markdownFileUris,
        ), // Send list of URIs
      );
      await HomeWidget.updateWidget(
        name: 'QsidianWidget',
      );
      print(
        "Data sent to widget: Vault: $_vaultUri, Files: ${_markdownFileUris.length}",
      );
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

  Future<
    void
  >
  _loadMarkdownFiles() async {
    if (_vaultUri ==
        null) {
      print(
        "DEBUG: _loadMarkdownFiles called with null _vaultUri.",
      );
      setState(
        () {
          _markdownFileUris = [];
        },
      );
      await _sendDataToWidget();
      return;
    }

    print(
      "DEBUG: Attempting to load markdown files from URI: $_vaultUri",
    );

    try {
      final List<
        dynamic
      >?
      fileUris = await platform.invokeMethod(
        'listMarkdownFiles',
        {
          'vaultUri': _vaultUri,
        },
      );
      setState(
        () {
          _markdownFileUris =
              fileUris
                  ?.cast<
                    String
                  >() ??
              [];
        },
      );
      print(
        "DEBUG: Loaded ${_markdownFileUris.length} markdown files from URI.",
      );
    } on PlatformException catch (
      e
    ) {
      print(
        "DEBUG: Error listing markdown files: '${e.message}'.",
      );
      setState(
        () {
          _markdownFileUris = [];
        },
      );
    }
    await _sendDataToWidget();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Qsidian',
        ),
      ),
      body: Column(
        children:
            <
              Widget
            >[
              Padding(
                padding: const EdgeInsets.all(
                  8.0,
                ),
                child: ElevatedButton(
                  onPressed: _selectVaultFolder,
                  child: const Text(
                    'Select Vault Folder',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(
                  8.0,
                ),
                child: Text(
                  _getVaultDisplayName(_vaultUri) ??
                      'No vault selected',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Expanded(
                child:
                    _vaultUri ==
                        null
                    ? const Center(
                        child: Text(
                          'Please select a vault folder.',
                        ),
                      )
                    : _markdownFileUris.isEmpty
                    ? const Center(
                        child: Text(
                          'No markdown files found in this vault.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: _markdownFileUris.length,
                        itemBuilder:
                            (
                              context,
                              index,
                            ) {
                              final fileUri = _markdownFileUris[index];
                              return ListTile(
                                title: Text(
                                  Uri.decodeComponent(Uri.parse(fileUri).path.split('/').last),
                                ),
                                subtitle: Text(
                                  _getRelativePath(fileUri),
                                ), // Display relative path or folder name
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (
                                            context,
                                          ) => NoteEditorScreen(
                                            noteFileUri: fileUri,
                                          ), // Pass URI to NoteEditorScreen
                                    ),
                                  );
                                },
                            );
                          },
                    ),
            ),
          ],
    ),
);
}

  String _getVaultDisplayName(String? uriString) {
    if (uriString == null) return "No Vault Selected";
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
  }

  String _getRelativePath(String fileUri) {
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
  }
}
