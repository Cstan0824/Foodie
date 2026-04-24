import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';

class HashtagTextEditingController extends TextEditingController {
  static final RegExp _hashtagPattern = RegExp(r'#[a-zA-Z0-9_]+');
  static final RegExp _whitespacePattern = RegExp(r'\s');
  static final RegExp _tokenPattern = RegExp(r'[a-zA-Z0-9_]');
  static const Color _hashtagSurface = Color(0xFFFFF1F4);

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
    final cursor = value.selection.isValid && value.selection.isCollapsed
        ? value.selection.baseOffset
        : -1;

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
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            backgroundColor: _isCompletedMatch(text, match, cursor)
                ? _hashtagSurface
                : null,
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

  bool _isCompletedMatch(String text, RegExpMatch match, int cursor) {
    final end = match.end;
    final cursorInsideMatch = cursor >= match.start && cursor <= match.end;

    if (end >= text.length) {
      return !cursorInsideMatch;
    }

    final nextChar = text[end];
    if (_whitespacePattern.hasMatch(nextChar)) {
      return true;
    }

    return !_tokenPattern.hasMatch(nextChar);
  }
}
