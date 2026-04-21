import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:taste_spot/data/repositories/restaurant_repository.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();

  // Selected photos from device
  final List<XFile> _selectedImages = [];

  // Chosen restaurant
  RestaurantModel? _selectedRestaurant;

  // State
  bool _isPublishing = false;

  // TODO: replace with real auth userId
  static const _tempUserId = '00000000-0000-0000-0000-000000000001';

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _imagePicker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (picked.isNotEmpty) {
      setState(() => _selectedImages.addAll(picked));
    }
  }

  // ── Remove a selected image ───────────────────────────────────────────────
  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // ── Show restaurant search bottom sheet ────────────────────────────────────
  void _showRestaurantPicker() {
    showCupertinoModalPopup<RestaurantModel>(
      context: context,
      builder: (ctx) => _RestaurantPickerSheet(
        onSelected: (r) {
          setState(() => _selectedRestaurant = r);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  // ── Publish ───────────────────────────────────────────────────────────────
  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final caption = _captionController.text.trim();
    if (title.isEmpty) {
      _showError('Please add a title before publishing.');
      return;
    }

    if (_selectedImages.isEmpty) {
      _showError('Please add at least one photo before publishing.');
      return;
    }

    setState(() => _isPublishing = true);
    try {
      // Convert XFiles to bytes
      final imageByteslist = <Uint8List>[];
      for (final xFile in _selectedImages) {
        imageByteslist.add(await xFile.readAsBytes());
      }

      await PostRepository.instance.createPost(
        userId: _tempUserId,
        restaurantId: _selectedRestaurant?.restaurantId,
        title: title,
        caption: caption,
        images: imageByteslist,
      );

      if (mounted) Navigator.of(context).pop(true); // true = feed should refresh
    } catch (e) {
      if (mounted) _showError('Failed to publish: $e');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Oops'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.xmark,
              color: AppColors.textPrimary, size: 22),
        ),
        middle: const Text(
          'New Post',
          style: TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isPublishing ? null : _publish,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _isPublishing ? AppColors.textLight : AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _isPublishing
                ? const CupertinoActivityIndicator()
                : const Text(
                    'Publish',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image picker row ──
              SizedBox(
                height: 120,
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _selectedImages.length) {
                      return _buildAddButton();
                    }
                    return _buildImagePreview(i);
                  },
                ),
              ),

              _divider(),

              // ── Title input ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoTextField(
                  controller: _titleController,
                  placeholder: 'Add a title...',
                  placeholderStyle: const TextStyle(
                      color: AppColors.textLight, fontSize: 16),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.4),
                  decoration: null,
                  maxLines: 2,
                  minLines: 1,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),

              _divider(),

              // ── Details input ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoTextField(
                  controller: _captionController,
                  placeholder: 'Share your experience, taste, and tips...',
                  placeholderStyle: const TextStyle(
                      color: AppColors.textLight, fontSize: 15),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.5),
                  decoration: null,
                  maxLines: 8,
                  minLines: 4,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              _divider(),

              // ── Restaurant picker ──
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showRestaurantPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.location_solid,
                        color: _selectedRestaurant != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedRestaurant?.name ?? 'Tag a Restaurant',
                              style: TextStyle(
                                color: _selectedRestaurant != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                            if (_selectedRestaurant?.mainCuisineId != null)
                              Text(
                                _selectedRestaurant!.mainCuisineId!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight),
                              ),
                          ],
                        ),
                      ),
                      if (_selectedRestaurant != null)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 0,
                          onPressed: () =>
                              setState(() => _selectedRestaurant = null),
                          child: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: AppColors.textLight,
                            size: 18,
                          ),
                        )
                      else
                        const Icon(
                          CupertinoIcons.chevron_right,
                          color: AppColors.textLight,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              ),

              _divider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
        height: 0.5,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: AppColors.divider,
      );

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.camera_fill,
                color: AppColors.textSecondary, size: 32),
            SizedBox(height: 8),
            Text('Add Photo',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(int index) {
    final xFile = _selectedImages[index];
    return Stack(
      children: [
        Container(
          width: 96,
          height: 96,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(File(xFile.path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 14,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xAA000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.xmark,
                  color: CupertinoColors.white, size: 11),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════
//  RESTAURANT PICKER SHEET
// ══════════════════════════════════════════════
class _RestaurantPickerSheet extends StatefulWidget {
  final ValueChanged<RestaurantModel> onSelected;

  const _RestaurantPickerSheet({required this.onSelected});

  @override
  State<_RestaurantPickerSheet> createState() =>
      _RestaurantPickerSheetState();
}

class _RestaurantPickerSheetState
    extends State<_RestaurantPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<RestaurantModel> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final list = await RestaurantRepository.instance.fetchRecent(limit: 20);
    if (mounted) setState(() { _results = list; _isLoading = false; });
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) { _loadInitial(); return; }
    _search(q);
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    final list = await RestaurantRepository.instance.searchRestaurants(query);
    if (mounted) setState(() { _results = list; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.textLight,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          const Text('Tag a Restaurant',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoTextField(
              controller: _searchCtrl,
              placeholder: 'Search restaurants...',
              prefix: const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Icon(CupertinoIcons.search,
                      color: AppColors.textLight, size: 18)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              autofocus: true,
            ),
          ),
          const SizedBox(height: 8),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _results.isEmpty
                    ? const Center(
                        child: Text('No restaurants found 🍴',
                            style: TextStyle(color: AppColors.textLight)))
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => Container(
                            height: 0.5,
                            color: AppColors.divider,
                            margin: const EdgeInsets.only(left: 58)),
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => widget.onSelected(r),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        CupertinoIcons.location_solid,
                                        color: AppColors.primary,
                                        size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(r.name,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppColors.textPrimary)),
                                        if (r.mainCuisineId != null)
                                          Text(r.mainCuisineId!,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textLight)),
                                      ],
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.chevron_right,
                                      color: AppColors.textLight, size: 14),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Bottom safe area padding
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
