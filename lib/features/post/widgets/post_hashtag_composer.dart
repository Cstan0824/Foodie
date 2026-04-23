import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/utils/hashtag_utils.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';

class PostHashtagComposer extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onChanged;

  const PostHashtagComposer({
    super.key,
    this.initialTags = const [],
    required this.onChanged,
  });

  @override
  State<PostHashtagComposer> createState() => _PostHashtagComposerState();
}

class _PostHashtagComposerState extends State<PostHashtagComposer> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final List<String> _tags;
  List<String> _suggestions = const [];
  bool _isSearching = false;
  String? _errorText;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _tags = List<String>.from(HashtagUtils.normalizeAll(widget.initialTags));
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _inputController.text.trim().isEmpty) {
      setState(() => _suggestions = const []);
    }
  }

  Future<void> _handleInputChanged(String rawValue) async {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }

    final query = HashtagUtils.normalizeToken(rawValue);
    final validation = query.isEmpty ? null : HashtagUtils.validateToken(query);
    if (query.isEmpty || validation != null) {
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }

    final requestId = ++_searchRequestId;
    setState(() => _isSearching = true);

    try {
      final results = await PostRepository.instance.searchHashtags(
        query,
        limit: 6,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _suggestions = results.where((tag) => !_tags.contains(tag)).toList();
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

  void _addFromInput([String? rawValue]) {
    final tokens = HashtagUtils.normalizeAll(
      HashtagUtils.extractTokens(rawValue ?? _inputController.text),
    );
    if (tokens.isEmpty) {
      setState(() => _errorText = 'Enter at least one hashtag.');
      return;
    }

    final merged = List<String>.from(_tags);
    for (final token in tokens) {
      final error = HashtagUtils.validateToken(token);
      if (error != null) {
        setState(() => _errorText = error);
        return;
      }
      if (!merged.contains(token)) {
        merged.add(token);
      }
    }

    final listError = HashtagUtils.validateList(merged);
    if (listError != null) {
      setState(() => _errorText = listError);
      return;
    }

    setState(() {
      _tags
        ..clear()
        ..addAll(merged);
      _inputController.clear();
      _suggestions = const [];
      _errorText = null;
    });
    widget.onChanged(List<String>.unmodifiable(_tags));
    _focusNode.requestFocus();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _errorText = null;
    });
    widget.onChanged(List<String>.unmodifiable(_tags));
  }

  bool get _shouldShowSuggestions {
    final currentInput = HashtagUtils.normalizeToken(_inputController.text);
    if (!_focusNode.hasFocus || currentInput.isEmpty) {
      return false;
    }
    return _isSearching || _suggestions.isNotEmpty || _showCreateOption;
  }

  bool get _showCreateOption {
    final currentInput = HashtagUtils.normalizeToken(_inputController.text);
    return currentInput.isNotEmpty &&
        HashtagUtils.validateToken(currentInput) == null &&
        !_tags.contains(currentInput) &&
        !_suggestions.contains(currentInput);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.number,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              const Text(
                'Hashtags',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_tags.length}/${HashtagUtils.maxTagsPerPost}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map(_buildTagChip).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  placeholder: 'Add hashtags like #sushi or #latenight',
                  placeholderStyle: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _errorText != null
                          ? CupertinoColors.systemRed
                          : AppColors.divider,
                      width: 0.8,
                    ),
                  ),
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  onChanged: _handleInputChanged,
                  onSubmitted: _addFromInput,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _addFromInput,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Add',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Existing hashtags appear while you type. New ones are created when you publish.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textLight,
              height: 1.3,
            ),
          ),
          if (_shouldShowSuggestions) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider, width: 0.8),
              ),
              child: Column(
                children: [
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.all(12),
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
                    for (final suggestion in _suggestions)
                      _buildSuggestionTile(
                        label: HashtagUtils.format(suggestion),
                        subtitle: 'Existing hashtag',
                        onTap: () => _addFromInput(suggestion),
                      ),
                    if (_showCreateOption)
                      _buildSuggestionTile(
                        label: 'Use ${HashtagUtils.format(_inputController.text)}',
                        subtitle: 'Create this hashtag when you publish',
                        onTap: _addFromInput,
                      ),
                  ],
                ],
              ),
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemRed,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            HashtagUtils.format(tag),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _removeTag(tag),
            child: const Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile({
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.number_circle,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
