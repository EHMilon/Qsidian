import 'package:flutter/material.dart';
import 'package:qsidian/custom_markdown_controller.dart'; // Import CustomMarkdownController

class MarkdownToolbar extends StatelessWidget {
  final CustomMarkdownController controller;

  const MarkdownToolbar({
    super.key,
    required this.controller,
  });

  void _applyMarkdownFormat(String markdownTag, [String? closingTag]) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (start == -1 || end == -1) {
      // No selection, just insert at cursor
      final newText =
          text.substring(0, controller.selection.baseOffset) +
          markdownTag +
          (closingTag ?? markdownTag) +
          text.substring(controller.selection.baseOffset);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: controller.selection.baseOffset + markdownTag.length,
      );
    } else if (start == end) {
      // No text selected, insert tags and place cursor in between
      final newText =
          text.substring(0, start) +
          markdownTag +
          (closingTag ?? markdownTag) +
          text.substring(end);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
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
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: end + markdownTag.length * (closingTag == null ? 1 : 2),
      );
    }
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

  @override
  Widget build(BuildContext context) {
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
}