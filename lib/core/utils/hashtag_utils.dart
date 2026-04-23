class HashtagUtils {
  HashtagUtils._();

  static const int maxTagsPerPost = 5;
  static const int maxTagLength = 24;
  static final RegExp _splitPattern = RegExp(r'[\s,]+');
  static final RegExp _validPattern = RegExp(r'^[a-z0-9_]+$');
  static final RegExp _inlineHashtagPattern = RegExp(
    r'(^|[\s])#([a-zA-Z0-9_]+)',
    multiLine: true,
  );

  static String normalizeToken(String raw) {
    var value = raw.trim().toLowerCase();
    value = value.replaceFirst(RegExp(r'^#+'), '');
    return value.trim();
  }

  static List<String> extractTokens(String raw) {
    return raw
        .split(_splitPattern)
        .map(normalizeToken)
        .where((token) => token.isNotEmpty)
        .toList();
  }

  static List<String> normalizeAll(Iterable<String> rawValues) {
    final normalized = <String>[];
    final seen = <String>{};

    for (final raw in rawValues) {
      for (final token in extractTokens(raw)) {
        if (seen.add(token)) {
          normalized.add(token);
        }
      }
    }

    return normalized;
  }

  static List<String> extractHashtagsFromText(String raw) {
    final normalized = <String>[];
    final seen = <String>{};

    for (final match in _inlineHashtagPattern.allMatches(raw)) {
      final token = normalizeToken(match.group(2) ?? '');
      if (token.isNotEmpty && seen.add(token)) {
        normalized.add(token);
      }
    }

    return normalized;
  }

  static String? validateToken(String token) {
    if (token.isEmpty) {
      return 'Enter at least one hashtag.';
    }
    if (token.length > maxTagLength) {
      return 'Hashtags can be up to $maxTagLength characters.';
    }
    if (!_validPattern.hasMatch(token)) {
      return 'Hashtags can only use letters, numbers, and _.';
    }
    return null;
  }

  static String? validateList(List<String> tags) {
    if (tags.length > maxTagsPerPost) {
      return 'You can add up to $maxTagsPerPost hashtags.';
    }
    for (final tag in tags) {
      final error = validateToken(tag);
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  static String format(String token) {
    final normalized = normalizeToken(token);
    return normalized.isEmpty ? '#' : '#$normalized';
  }
}
