import 'package:flutter/material.dart';
import 'package:qsidian/features/home/home_page.dart'; // Import MyHomePage from its new location
import 'package:qsidian/widgets/quick_note_overlay_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const MyHomePage());
          case '/overlay':
            return _createOverlayRoute();
          default:
            return MaterialPageRoute(builder: (_) => const MyHomePage());
        }
      },
    );
  }

  /// Creates the overlay route for Quick Settings tile functionality
  PageRoute _createOverlayRoute() {
    return QuickNoteOverlayRoute(
      vaultUri: null, // Will be loaded from SharedPreferences
      onSave: () {
        // Handle successful note save
      },
      onDismiss: () {
        // Handle overlay dismissal
      },
    );
  }
}
