import 'package:flutter/material.dart';

class CustomMarkdownController extends TextEditingController {
  // This controller no longer needs custom buildTextSpan logic
  // as the MarkdownBody will handle rendering.
  // We keep it as CustomMarkdownController for now for consistency,
  // but its functionality is essentially that of a standard TextEditingController.
  CustomMarkdownController({String? text}) : super(text: text);
}
