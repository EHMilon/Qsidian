import 'package:flutter/material.dart';
import 'quick_note_widget.dart';

/// A custom PageRoute that displays the QuickNoteWidget as a transparent overlay.
/// This route is designed for use with the Android Quick Settings tile functionality,
/// providing a transparent background that allows the Quick Settings panel to remain visible.
class QuickNoteOverlayRoute extends PageRoute<void> {
  final String? vaultUri;
  final VoidCallback? onSave;
  final VoidCallback? onDismiss;

  QuickNoteOverlayRoute({
    required this.vaultUri,
    this.onSave,
    this.onDismiss,
    super.settings,
  });

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {
          // Handle outside tap dismissal
          onDismiss?.call();
          Navigator.of(context).pop();
        },
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {
                // Prevent dismissal when tapping inside the widget
              },
              child: QuickNoteWidget(
                vaultUri: vaultUri,
                isTransparent: true,
                onNoteCreated: () {
                  // Call onSave callback and dismiss overlay after successful note creation
                  onSave?.call();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Fade in/out animation for smooth overlay appearance
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}
