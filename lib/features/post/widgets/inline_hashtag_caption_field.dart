import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/utils/hashtag_utils.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';

class InlineHashtagCaptionField extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final int minLines;
  final int maxLines;
  final bool isError;
  final ValueChanged<String>? onChanged;

  const InlineHashtagCaptionField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.minLines = 4,
    this.maxLines = 8,
    this.isError = false,
    this.onChanged,
  });

  @override
  State<InlineHashtagCaptionField> createState() =>
      _InlineHashtagCaptionFieldState();
}

class _InlineHashtagCaptionFieldState extends State<InlineHashtagCaptionField> {
  static const Color _hashtagSurface = Color(0xFFFFF1F4);
  static const Color _hashtagBorder = Color(0xFFFFD4DD);

  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = const [];
  bool _isSearching = false;
  int _searchRequestId = 0;
  String _activeToken = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant InlineHashtagCaptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _handleControllerChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleControllerChanged() async {
    final active = _findActiveHashtag(widget.controller.value);
    final token = active?.token ?? '';

    if (_activeToken != token && mounted) {
      setState(() => _activeToken = token);
    }

    if (token.isEmpty || HashtagUtils.validateToken(token) != null) {
      if (mounted) {
        setState(() {
          _suggestions = const [];
          _isSearching = false;
        });
      }
      return;
    }

    final requestId = ++_searchRequestId;
    if (mounted) {
      setState(() => _isSearching = true);
    }

    try {
      final results = await PostRepository.instance.searchHashtags(
        token,
        limit: 6,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _suggestions = results.where((tag) => tag != token).toList();
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _suggestions = const []);
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  _ActiveHashtag? _findActiveHashtag(TextEditingValue value) {
    if (!value.selection.isValid || !value.selection.isCollapsed) {
      return null;
    }

    final cursor = value.selection.baseOffset;
    if (cursor < 0 || cursor > value.text.length) {
      return null;
    }

    final prefix = value.text.substring(0, cursor);
    final match = RegExp(r'(^|[\s])#([a-zA-Z0-9_]*)$').firstMatch(prefix);
    if (match == null) {
      return null;
    }

    final leading = match.group(1)?.length ?? 0;
    return _ActiveHashtag(
      start: match.start + leading,
      end: cursor,
      token: HashtagUtils.normalizeToken(match.group(2) ?? ''),
    );
  }

  void _insertHashtagMarker() {
    final value = widget.controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = selection.start.clamp(0, value.text.length);
    final end = selection.end.clamp(0, value.text.length);

    var insertion = '#';
    if (start > 0) {
      final previousChar = value.text[start - 1];
      if (!RegExp(r'\s').hasMatch(previousChar)) {
        insertion = ' #';
      }
    }

    final newText = value.text.replaceRange(start, end, insertion);
    final cursor = start + insertion.length;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  void _replaceActiveHashtag(String rawTag) {
    final active = _findActiveHashtag(widget.controller.value);
    if (active == null) return;

    final normalized = HashtagUtils.normalizeToken(rawTag);
    if (normalized.isEmpty || HashtagUtils.validateToken(normalized) != null) {
      return;
    }

    final replacement = HashtagUtils.format(normalized);
    final value = widget.controller.value;
    var newText = value.text.replaceRange(active.start, active.end, replacement);
    var cursor = active.start + replacement.length;

    final shouldAppendSpace =
        cursor == newText.length || !RegExp(r'\s').hasMatch(newText[cursor]);
    if (shouldAppendSpace) {
      newText = '$newText ';
      cursor += 1;
    }

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  bool get _showCreateOption =>
      _activeToken.isNotEmpty && !_suggestions.contains(_activeToken);

  bool get _showSuggestions =>
      _focusNode.hasFocus &&
      (_isSearching || _suggestions.isNotEmpty || _showCreateOption);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoTextField(
          controller: widget.controller,
          focusNode: _focusNode,
          placeholder: widget.placeholder,
          placeholderStyle:
              const TextStyle(color: AppColors.textLight, fontSize: 15),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            height: 1.5,
          ),
          decoration: BoxDecoration(
            border: widget.isError ? Border.all(color: CupertinoColors.systemRed, width: 1.2) : null,
            borderRadius: widget.isError ? BorderRadius.circular(12) : null,
          ),
          onChanged: widget.onChanged,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        ),
        const SizedBox(height: 10),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: _insertHashtagMarker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _hashtagSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _hashtagBorder, width: 0.9),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.number,
                  size: 14,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'Hashtag',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Type # in your caption or tap the button to insert one.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textLight,
            height: 1.3,
          ),
        ),
        if (_showSuggestions) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(radius: 8),
                        SizedBox(width: 10),
                        Text(
                          'Searching hashtags…',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Text(
                    _suggestions.isNotEmpty
                        ? 'Suggested hashtags'
                        : 'Create hashtag',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final suggestion in _suggestions)
                        _HashtagPill(
                          label: HashtagUtils.format(suggestion),
                          onTap: () => _replaceActiveHashtag(suggestion),
                        ),
                      if (_showCreateOption)
                        _HashtagPill(
                          label: 'Create ${HashtagUtils.format(_activeToken)}',
                          onTap: () => _replaceActiveHashtag(_activeToken),
                        ),
                    ],
                  ),
                  if (_showCreateOption) ...[
                    const SizedBox(height: 10),
                    Text(
                      'New hashtags are only created when you publish the post.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withAlpha(220),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HashtagPill extends StatelessWidget {
  static const Color _surface = Color(0xFFFFF1F4);
  static const Color _border = Color(0xFFFFD4DD);

  final String label;
  final VoidCallback? onTap;

  const _HashtagPill({
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border, width: 0.9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: -0.2,
        ),
      ),
    );

    if (onTap == null) {
      return chip;
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: chip,
    );
  }
}

class _ActiveHashtag {
  final int start;
  final int end;
  final String token;

  const _ActiveHashtag({
    required this.start,
    required this.end,
    required this.token,
  });
}
