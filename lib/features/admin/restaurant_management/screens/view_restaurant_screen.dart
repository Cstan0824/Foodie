import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';
import 'package:taste_spot/data/models/cuisine_model.dart';
import 'package:taste_spot/data/repositories/restaurant_repository.dart';
import 'package:taste_spot/features/admin/restaurant_management/screens/add_edit_restaurant_screen.dart';

class ViewRestaurantScreen extends StatefulWidget {
  final String restaurantId;

  const ViewRestaurantScreen({super.key, required this.restaurantId});

  @override
  State<ViewRestaurantScreen> createState() => _ViewRestaurantScreenState();
}

class _ViewRestaurantScreenState extends State<ViewRestaurantScreen> {
  RestaurantDetailData? _detail;
  bool _isLoading = true;
  bool _isTogglingStatus = false;
  String? _error;

  final _repo = RestaurantRepository.instance;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _repo.fetchRestaurantDetail(widget.restaurantId);
      if (!mounted) return;
      if (detail == null) {
        setState(() {
          _error = 'Restaurant not found.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Computed helpers ────────────────────────────────────────────────────────

  RestaurantModel? get _restaurant => _detail?.restaurant;

  String? get _coverImageUrl {
    final images = _detail?.images ?? [];
    if (images.isEmpty) return null;
    try {
      return images.firstWhere((img) => img.isCover).imageUrl;
    } catch (_) {
      return images.first.imageUrl;
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ── Disable / Re-enable ─────────────────────────────────────────────────────

  void _toggleDisabled() {
    final r = _restaurant;
    if (r == null) return;
    final willDisable = !r.isDisabled;
    final title = willDisable ? 'Disable Restaurant' : 'Re-enable Restaurant';
    final message = willDisable
        ? 'This restaurant will be hidden from users. You can re-enable it later.'
        : 'This restaurant will become visible to users again.';
    final actionLabel = willDisable ? 'Disable' : 'Re-enable';

    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: willDisable,
            onPressed: () async {
              Navigator.pop(context);
              await _performToggle(willDisable);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _performToggle(bool disable) async {
    setState(() => _isTogglingStatus = true);
    try {
      await _repo.setDisabled(widget.restaurantId, disable);
      await _loadDetail();
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTogglingStatus = false);
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.cardBackground,
        border: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
        middle: Text(
          _restaurant?.name ?? 'Restaurant Detail',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _isTogglingStatus
            ? const CupertinoActivityIndicator(radius: 10)
            : null,
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: Color(0xFFFF9500),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                onPressed: _loadDetail,
                child: const Text('Retry', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;
    final r = detail.restaurant;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoverHeader(r),
            _buildActionButtons(r),
            const SizedBox(height: 8),
            _buildInfoSection(r),
            const SizedBox(height: 8),
            _buildCuisineSection(r, detail.extraCuisines),
            const SizedBox(height: 8),
            _buildImageGallery(detail.images),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Cover header ────────────────────────────────────────────────────────────

  Widget _buildCoverHeader(RestaurantModel r) {
    final coverUrl = _coverImageUrl;
    return Stack(
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: coverUrl != null
              ? Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _imagePlaceholder(),
                )
              : _imagePlaceholder(),
        ),
        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),
        ),
        // Name + cuisine + status badge
        Positioned(
          bottom: 14,
          left: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (r.mainCuisineId != null)
                      Text(
                        r.mainCuisineId!,
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.white.withAlpha(200),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(isDisabled: r.isDisabled),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(
          CupertinoIcons.photo,
          size: 48,
          color: AppColors.textLight,
        ),
      ),
    );
  }

  // ── Action buttons ──────────────────────────────────────────────────────────

  Widget _buildActionButtons(RestaurantModel r) {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: CupertinoIcons.pencil,
              label: 'Edit',
              color: const Color(0xFF007AFF),
              onTap: _isTogglingStatus
                  ? null
                  : () async {
                      final didSave = await Navigator.of(context).push<bool>(
                        CupertinoPageRoute(
                          builder: (_) => AddEditRestaurantScreen(
                            restaurantId: widget.restaurantId,
                          ),
                        ),
                      );
                      if (didSave == true) _loadDetail();
                    },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              icon: r.isDisabled
                  ? CupertinoIcons.checkmark_circle
                  : CupertinoIcons.nosign,
              label: r.isDisabled ? 'Re-enable' : 'Disable',
              color: r.isDisabled
                  ? const Color(0xFF34C759)
                  : const Color(0xFFFF3B30),
              onTap: _isTogglingStatus ? null : _toggleDisabled,
            ),
          ),
        ],
      ),
    );
  }

  // ── Restaurant information ──────────────────────────────────────────────────

  Widget _buildInfoSection(RestaurantModel r) {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Restaurant Information',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(label: 'ID', value: r.restaurantId),
          _InfoRow(label: 'Name', value: r.name),
          _InfoRow(label: 'Address', value: r.address ?? '—'),
          _InfoRow(
            label: 'Latitude',
            value: r.latitude != null ? r.latitude!.toStringAsFixed(6) : '—',
          ),
          _InfoRow(
            label: 'Longitude',
            value: r.longitude != null ? r.longitude!.toStringAsFixed(6) : '—',
          ),
          _InfoRow(
            label: 'Maps URL',
            value: r.mapsUrl ?? '—',
            isLink: r.mapsUrl != null,
          ),
          _InfoRow(
            label: 'Info URL',
            value: r.infoUrl ?? '—',
            isLink: r.infoUrl != null,
          ),
          _InfoRow(label: 'Source', value: r.source ?? '—'),
          _InfoRow(
            label: 'Rating',
            value: r.rating != null ? r.rating!.toStringAsFixed(1) : '—',
          ),
          _InfoRow(label: 'Created', value: _formatDate(r.createdAt)),
          _InfoRow(
            label: 'Status',
            value: r.isDisabled ? 'Disabled' : 'Active',
            valueColor: r.isDisabled
                ? const Color(0xFFFF3B30)
                : const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }

  // ── Cuisine section ─────────────────────────────────────────────────────────

  Widget _buildCuisineSection(
    RestaurantModel r,
    List<CuisineModel> extraCuisines,
  ) {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cuisines',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          // Main cuisine
          Row(
            children: [
              const Text(
                'Main: ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              _CuisineTag(
                name: r.mainCuisineId ?? '—',
                isPrimary: true,
              ),
            ],
          ),
          if (extraCuisines.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Extra Tags:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: extraCuisines
                  .map((c) => _CuisineTag(name: c.description, isPrimary: false))
                  .toList(),
            ),
          ],
          if (extraCuisines.isEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'No extra cuisine tags',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ],
        ],
      ),
    );
  }

  // ── Image gallery ───────────────────────────────────────────────────────────

  Widget _buildImageGallery(List<RestaurantImageRecord> images) {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Images',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(
                '${images.length} image${images.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (images.isEmpty)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.photo,
                      size: 32,
                      color: AppColors.textLight,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No images available',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: images.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, i) {
                final img = images[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Image.network(
                          img.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.surface,
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.photo,
                                size: 20,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (img.isCover)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Cover',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onTap == null ? AppColors.textLight : color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: effectiveColor.withAlpha(18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: effectiveColor.withAlpha(50),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: effectiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLink;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLink = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isLink
                    ? CupertinoColors.activeBlue
                    : (valueColor ?? AppColors.textPrimary),
                decoration: isLink ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isDisabled;
  const _StatusBadge({required this.isDisabled});

  @override
  Widget build(BuildContext context) {
    final color =
        isDisabled ? const Color(0xFFFF3B30) : const Color(0xFF34C759);
    final label = isDisabled ? 'Disabled' : 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CuisineTag extends StatelessWidget {
  final String name;
  final bool isPrimary;

  const _CuisineTag({required this.name, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    final color = isPrimary ? AppColors.primary : const Color(0xFF007AFF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50), width: 0.5),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
