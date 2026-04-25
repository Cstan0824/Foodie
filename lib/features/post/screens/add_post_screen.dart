import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/utils/hashtag_utils.dart';
import 'package:taste_spot/data/models/cuisine_model.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:taste_spot/data/repositories/restaurant_approval_repository.dart';
import 'package:taste_spot/data/repositories/restaurant_repository.dart';
import 'package:taste_spot/features/post/widgets/hashtag_text_editing_controller.dart';
import 'package:taste_spot/features/post/widgets/inline_hashtag_caption_field.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _titleController = TextEditingController();
  final TextEditingController _captionController =
      HashtagTextEditingController();
  final _imagePicker = ImagePicker();

  // Selected photos from device
  final List<XFile> _selectedImages = [];

  // Chosen restaurant
  RestaurantModel? _selectedRestaurant;
  String? _restaurantApprovalId;
  String? _selectedRestaurantName;

  // State
  bool _isPublishing = false;
  bool _titleError = false;
  bool _captionError = false;

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
          setState(() {
            _selectedRestaurant = r;
            _restaurantApprovalId = null;
            _selectedRestaurantName = r.name;
          });
          Navigator.of(ctx).pop();
        },
        onAddNew: (initialName) {
          Navigator.of(ctx).pop();
          _showNewRestaurantForm(initialName: initialName);
        },
      ),
    );
  }

  // ── Show new restaurant form bottom sheet ──────────────────────────────────
  void _showNewRestaurantForm({String? initialName}) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _NewRestaurantFormSheet(
        initialName: initialName,
        onSubmitted: (approvalId, name) {
          setState(() {
            _selectedRestaurant = null;
            _restaurantApprovalId = approvalId;
            _selectedRestaurantName = name;
          });
          Navigator.of(ctx).pop();
        },
        onBack: () {
          Navigator.of(ctx).pop();
          _showRestaurantPicker();
        },
      ),
    );
  }

  // ── Publish ───────────────────────────────────────────────────────────────
  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final caption = _captionController.text.trim();
    final hashtags = HashtagUtils.extractHashtagsFromText(caption);

    setState(() {
      _titleError = title.isEmpty;
      _captionError = caption.isEmpty;
    });

    if (_titleError || _captionError) {
      _showError('Please add a title and caption before publishing.');
      return;
    }

    final hasRestaurant =
        _selectedRestaurant != null &&
        _selectedRestaurant!.restaurantId.trim().isNotEmpty;
    final hasApproval =
        _restaurantApprovalId != null &&
        _restaurantApprovalId!.trim().isNotEmpty;

    if (!hasRestaurant && !hasApproval) {
      _showError('Please tag a restaurant before publishing.');
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
        userId: SupabaseService.requireCurrentUserId(),
        restaurantId: _selectedRestaurant?.restaurantId,
        restaurantApprovalId: _restaurantApprovalId,
        title: title,
        caption: caption,
        hashtags: hashtags,
        images: imageByteslist,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // true = feed should refresh
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to publish: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
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
          child: const Icon(
            CupertinoIcons.xmark,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
        middle: const Text(
          'New Post',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                    color: AppColors.textLight,
                    fontSize: 16,
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  decoration: BoxDecoration(
                    border: _titleError ? Border.all(color: CupertinoColors.systemRed, width: 1.2) : null,
                    borderRadius: _titleError ? BorderRadius.circular(10) : null,
                  ),
                  onChanged: (_) {
                    if (_titleError) setState(() => _titleError = false);
                  },
                  maxLines: 2,
                  minLines: 1,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                ),
              ),

              _divider(),

              // ── Details input ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InlineHashtagCaptionField(
                  controller: _captionController,
                  placeholder: 'Share your experience, taste, and tips...',
                  maxLines: 8,
                  minLines: 4,
                  isError: _captionError,
                  onChanged: (_) {
                    if (_captionError) setState(() => _captionError = false);
                  },
                ),
              ),

              _divider(),

              // ── Restaurant picker ──
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showRestaurantPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.location_solid,
                        color:
                            (_selectedRestaurant != null ||
                                _restaurantApprovalId != null)
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
                              _selectedRestaurant?.name ??
                                  _selectedRestaurantName ??
                                  'Tag a Restaurant',
                              style: TextStyle(
                                color:
                                    (_selectedRestaurant != null ||
                                        _restaurantApprovalId != null)
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
                                  color: AppColors.textLight,
                                ),
                              )
                            else if (_restaurantApprovalId != null)
                              const Text(
                                'Pending review',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.systemOrange,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_selectedRestaurant != null ||
                          _restaurantApprovalId != null)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: () => setState(() {
                            _selectedRestaurant = null;
                            _restaurantApprovalId = null;
                            _selectedRestaurantName = null;
                          }),
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
            Icon(
              CupertinoIcons.camera_fill,
              color: AppColors.textSecondary,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              'Add Photo',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
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
              child: const Icon(
                CupertinoIcons.xmark,
                color: CupertinoColors.white,
                size: 11,
              ),
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
  final ValueChanged<String> onAddNew;

  const _RestaurantPickerSheet({
    required this.onSelected,
    required this.onAddNew,
  });

  @override
  State<_RestaurantPickerSheet> createState() => _RestaurantPickerSheetState();
}

class _RestaurantPickerSheetState extends State<_RestaurantPickerSheet> {
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
    if (mounted) {
      setState(() {
        _results = list;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      _loadInitial();
      return;
    }
    _search(q);
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    final list = await RestaurantRepository.instance.searchRestaurants(query);
    if (mounted) {
      setState(() {
        _results = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;
    final query = _searchCtrl.text.trim();

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
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tag a Restaurant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoTextField(
              controller: _searchCtrl,
              placeholder: 'Search restaurants...',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(
                  CupertinoIcons.search,
                  color: AppColors.textLight,
                  size: 18,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                : Column(
                    children: [
                      Expanded(
                        child: _results.isEmpty
                            ? Center(
                                child: Text(
                                  query.isEmpty
                                      ? 'No restaurants found 🍴'
                                      : 'No restaurant found for "$query"',
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: _results.length,
                                separatorBuilder: (_, _) => Container(
                                  height: 0.5,
                                  color: AppColors.divider,
                                  margin: const EdgeInsets.only(left: 58),
                                ),
                                itemBuilder: (_, i) {
                                  final r = _results[i];
                                  return CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => widget.onSelected(r),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
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
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                                if (r.mainCuisineId != null)
                                                  Text(
                                                    r.mainCuisineId!,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textLight,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            CupertinoIcons.chevron_right,
                                            color: AppColors.textLight,
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Persistent Bottom Button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                                color: AppColors.divider, width: 0.5),
                          ),
                        ),
                        child: CupertinoButton(
                          onPressed: () => widget.onAddNew(query),
                          child: Text(
                            query.isEmpty
                                ? 'Can\'t find it? Add a new restaurant'
                                : 'Add "$query" as a new restaurant',
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  NEW RESTAURANT FORM SHEET
// ══════════════════════════════════════════════
class _NewRestaurantFormSheet extends StatefulWidget {
  final String? initialName;
  final void Function(String approvalId, String name) onSubmitted;
  final VoidCallback? onBack;

  const _NewRestaurantFormSheet({
    required this.onSubmitted,
    this.initialName,
    this.onBack,
  });

  @override
  State<_NewRestaurantFormSheet> createState() =>
      _NewRestaurantFormSheetState();
}

class _NewRestaurantFormSheetState extends State<_NewRestaurantFormSheet> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  List<CuisineModel> _cuisines = [];
  String? _selectedCuisineId;
  bool _isLoadingCuisines = true;
  bool _isSubmitting = false;
  
  bool _nameError = false;
  bool _addressError = false;
  bool _cuisineError = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameCtrl.text = widget.initialName!;
    }
    _loadCuisines();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCuisines() async {
    try {
      final list = await RestaurantRepository.instance.fetchPrimaryCuisines();
      if (mounted) {
        setState(() {
          _cuisines = list;
          if (list.isNotEmpty) _selectedCuisineId = list.first.id;
          _isLoadingCuisines = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCuisines = false);
    }
  }

  void _showCuisinePicker() {
    FocusScope.of(context).unfocus();

    int initialIndex = 0;
    if (_selectedCuisineId != null) {
      final idx = _cuisines.indexWhere((c) => c.id == _selectedCuisineId);
      if (idx != -1) initialIndex = idx;
    }

    int tempSelectedIndex = initialIndex;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  CupertinoButton(
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      if (_cuisines.isNotEmpty) {
                        setState(() {
                          _selectedCuisineId = _cuisines[tempSelectedIndex].id;
                          _cuisineError = false;
                        });
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: initialIndex,
                  ),
                  itemExtent: 32.0,
                  onSelectedItemChanged: (int index) {
                    tempSelectedIndex = index;
                  },
                  children: _cuisines
                      .map((c) => Center(child: Text(c.description)))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Error'),
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

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final cuisineId = _selectedCuisineId;

    setState(() {
      _nameError = name.isEmpty;
      _addressError = address.isEmpty;
      _cuisineError = cuisineId == null;
    });

    if (_nameError || _addressError || _cuisineError) {
      _showError('Please fill in all required fields marked with *');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final approvalId = await RestaurantApprovalRepository.instance
          .submitForApproval(
            name: name,
            mainCuisineId: cuisineId,
            address: address,
            source: 'USER',
          );
      if (mounted) {
        widget.onSubmitted(approvalId, name);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;
    final bottomPadding =
        MediaQuery.of(context).padding.bottom +
        MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              if (widget.onBack != null)
                Positioned(
                  left: 8,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    onPressed: widget.onBack,
                    child: const Icon(
                      CupertinoIcons.chevron_back,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ),
              const Text(
                'Add New Restaurant',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 0.5, color: AppColors.divider),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Can’t find the restaurant? Submit it for admin review.\nYour post will stay pending until the restaurant is approved.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  const Text(
                    'Restaurant name *',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _nameCtrl,
                    placeholder: 'e.g. Sakura Sushi Bar',
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: _nameError ? Border.all(color: CupertinoColors.systemRed, width: 1.2) : null,
                    ),
                    onChanged: (_) {
                      if (_nameError) setState(() => _nameError = false);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Cuisine
                  const Text(
                    'Main cuisine *',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _isLoadingCuisines
                      ? const CupertinoActivityIndicator()
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _showCuisinePicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: _cuisineError ? Border.all(color: CupertinoColors.systemRed, width: 1.2) : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedCuisineId == null
                                      ? 'Select cuisine'
                                      : _cuisines
                                            .firstWhere(
                                              (c) => c.id == _selectedCuisineId,
                                              orElse: () => _cuisines.first,
                                            )
                                            .description,
                                  style: TextStyle(
                                    color: _selectedCuisineId == null
                                        ? AppColors.textLight
                                        : AppColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const Icon(
                                  CupertinoIcons.chevron_down,
                                  color: AppColors.textLight,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),

                  // Address
                  const Text(
                    'Address *',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _addressCtrl,
                    placeholder: 'Full restaurant address',
                    padding: const EdgeInsets.all(12),
                    maxLines: 3,
                    minLines: 2,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: _addressError ? Border.all(color: CupertinoColors.systemRed, width: 1.2) : null,
                    ),
                    onChanged: (_) {
                      if (_addressError) setState(() => _addressError = false);
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : const Text(
                              'Submit for Review',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }
}
