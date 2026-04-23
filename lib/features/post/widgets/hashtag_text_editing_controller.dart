import 'package:flutter/cupertino.dart';

class HashtagTextEditingController extends TextEditingController {
  static final RegExp _hashtagPattern = RegExp(r'#[a-zA-Z0-9_]+');
  static final RegExp _whitespacePattern = RegExp(r'\s');
  static const Color _hashtagBlue = Color(0xFF1DA1F2);

  HashtagTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final text = value.text;

    if (text.isEmpty) {
      return TextSpan(style: baseStyle, text: text);
    }

    final children = <InlineSpan>[];
    var currentIndex = 0;

    for (final match in _hashtagPattern.allMatches(text)) {
      if (!_isValidBoundary(text, match.start)) {
        continue;
      }

      if (match.start > currentIndex) {
        children.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      children.add(
        TextSpan(
          text: match.group(0),
          style: baseStyle.copyWith(
            color: _hashtagBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      children.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: baseStyle,
        ),
      );
    }

    return TextSpan(style: baseStyle, children: children);
  }

  bool _isValidBoundary(String text, int index) {
    if (index == 0) {
      return true;
    }
    return _whitespacePattern.hasMatch(text[index - 1]);
  }
}
