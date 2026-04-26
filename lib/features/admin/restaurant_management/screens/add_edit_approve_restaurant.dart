import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/cuisine_model.dart';
import 'package:taste_spot/data/models/restaurant_approval_model.dart';
import 'package:taste_spot/data/repositories/restaurant_approval_repository.dart';
import 'package:taste_spot/data/repositories/restaurant_repository.dart';

// ── Malaysian location data ──────────────────────────────────────────────────

const List<String> _malaysianStates = [
  'Johor',
  'Kedah',
  'Kelantan',
  'Kuala Lumpur',
  'Labuan',
  'Melaka',
  'Negeri Sembilan',
  'Pahang',
  'Penang',
  'Perak',
  'Perlis',
  'Putrajaya',
  'Sabah',
  'Sarawak',
  'Selangor',
  'Terengganu',
];

const Map<String, List<String>> _citiesByState = {
  'Kuala Lumpur': ['Kuala Lumpur'],
  'Selangor': [
    'Petaling Jaya',
    'Shah Alam',
    'Subang Jaya',
    'Klang',
    'Ampang',
    'Kajang',
    'Puchong',
    'Cyberjaya',
    'Putrajaya',
    'Serdang',
  ],
  'Penang': ['George Town', 'Butterworth', 'Bayan Lepas', 'Bukit Mertajam'],
  'Johor': ['Johor Bahru', 'Iskandar Puteri', 'Batu Pahat', 'Muar', 'Kluang'],
  'Perak': ['Ipoh', 'Taiping', 'Teluk Intan', 'Kampar'],
  'Melaka': ['Melaka City', 'Ayer Keroh', 'Alor Gajah'],
  'Kedah': ['Alor Setar', 'Sungai Petani', 'Langkawi', 'Kulim'],
  'Pahang': ['Kuantan', 'Temerloh', 'Bentong', 'Cameron Highlands'],
  'Kelantan': ['Kota Bharu', 'Pasir Mas', 'Tanah Merah'],
  'Terengganu': ['Kuala Terengganu', 'Kemaman', 'Dungun'],
  'Negeri Sembilan': ['Seremban', 'Port Dickson', 'Nilai'],
  'Perlis': ['Kangar', 'Arau'],
  'Sabah': ['Kota Kinabalu', 'Sandakan', 'Tawau'],
  'Sarawak': ['Kuching', 'Miri', 'Sibu', 'Bintulu'],
  'Putrajaya': ['Putrajaya'],
  'Labuan': ['Labuan'],
};

// ── Form image model ─────────────────────────────────────────────────────────

/// Represents one image in the form — either an existing remote URL or a
/// newly picked local file.
class _FormImage {
  final String id;
  final String? networkUrl; // non-null for existing (already-uploaded) images
  final File? file; // non-null for newly picked local images
  bool isCover;

  _FormImage({
    required this.id,
    this.networkUrl,
    this.file,
    this.isCover = false,
  });
}

// ── Pending cuisine model ─────────────────────────────────────────────────────

/// A cuisine the admin created during this form session that has NOT yet been
/// written to the database. It carries a temporary local ID prefixed with
/// `_temp_` and is resolved to a real UUID only when the form is submitted.
class _PendingCuisine {
  final String tempId;
  final String name;
  final bool isPrimaryOption;

  const _PendingCuisine({
    required this.tempId,
    required this.name,
    required this.isPrimaryOption,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AddEditApproveRestaurantScreen extends StatefulWidget {
  /// `null` → add mode (empty form).
  /// Non-null → edit mode (form pre-filled from database).
  final String? restaurantId;
  final String? approvalId;

  const AddEditApproveRestaurantScreen({
    super.key,
    this.restaurantId,
    this.approvalId,
  }) : assert(
         restaurantId == null || approvalId == null,
         'Use either restaurantId or approvalId, not both.',
       );

  @override
  State<AddEditApproveRestaurantScreen> createState() =>
      _AddEditApproveRestaurantScreenState();
}

class _AddEditApproveRestaurantScreenState
    extends State<AddEditApproveRestaurantScreen> {
  bool get _isApprovalMode => widget.approvalId != null;
  bool get _isEditMode => widget.restaurantId != null && !_isApprovalMode;

  final _picker = ImagePicker();
  final _repo = RestaurantRepository.instance;
  final _approvalRepo = RestaurantApprovalRepository.instance;

  // ── Form controllers ────────────────────────────────────────────────────────

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addr1Ctrl;
  late final TextEditingController _addr2Ctrl;
  late final TextEditingController _postcodeCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _priceRangeCtrl;
  late final TextEditingController _ratingCtrl;
  String? _selectedState;
  String? _selectedCity;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _mapsUrlCtrl;
  late final TextEditingController _infoUrlCtrl;
  late final TextEditingController _sourceCtrl;

  // ── Cuisine state ───────────────────────────────────────────────────────────

  /// Cuisines eligible as main cuisine (isPrimaryOption == true).
  List<CuisineModel> _primaryCuisines = [];

  /// All cuisines available as extra tags.
  List<CuisineModel> _allCuisines = [];

  /// UUID of the selected main cuisine.
  String? _mainCuisineId;

  /// UUIDs of selected extra cuisine tags.
  Set<String> _extraCuisineIds = {};

  // ── Pending (unsaved) cuisines ──────────────────────────────────────────────

  /// New cuisines entered this session — written to the DB only on submit.
  final List<_PendingCuisine> _pendingCuisines = [];
  int _pendingCuisineCounter = 0;

  // ── Image state ─────────────────────────────────────────────────────────────

  List<_FormImage> _images = [];
  int _imgIdCounter = 0;

  // ── UX state ────────────────────────────────────────────────────────────────

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  final Map<String, String?> _errors = {};

  RestaurantApprovalModel? _approval;
  RestaurantBasicInfo? _currentRestaurant;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _priceRangeCtrl = TextEditingController();
    _ratingCtrl = TextEditingController();
    _addr1Ctrl = TextEditingController();
    _addr2Ctrl = TextEditingController();
    _postcodeCtrl = TextEditingController();
    _latCtrl = TextEditingController();
    _lngCtrl = TextEditingController();
    _mapsUrlCtrl = TextEditingController();
    _infoUrlCtrl = TextEditingController();
    _sourceCtrl = TextEditingController(text: 'admin');
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceRangeCtrl.dispose();
    _ratingCtrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _postcodeCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _mapsUrlCtrl.dispose();
    _infoUrlCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final cuisines = await _repo.fetchAllCuisines();
      _allCuisines = cuisines;
      _primaryCuisines = cuisines.where((c) => c.isPrimaryOption).toList();

      if (_isApprovalMode) {
        final approval = await _approvalRepo.fetchApprovalById(
          widget.approvalId!,
        );
        if (approval == null) {
          throw Exception('Approval record not found.');
        }
        _prefillFromApproval(approval);
        _approval = approval;

        if (approval.currRestaurantId != null &&
            approval.currRestaurantId!.isNotEmpty) {
          _currentRestaurant = await _repo.fetchRestaurantBasicInfo(
            approval.currRestaurantId!,
          );
        }
      } else if (_isEditMode) {
        final detail = await _repo.fetchRestaurantDetail(widget.restaurantId!);
        if (detail != null) _prefillForm(detail);
      } else {
        _sourceCtrl.text = 'ADMIN';
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _prefillForm(RestaurantDetailData detail) {
    final r = detail.restaurant;
    _nameCtrl.text = r.name;
    _descriptionCtrl.text = r.description ?? '';
    _priceRangeCtrl.text = r.priceRange ?? '';
    _ratingCtrl.text = r.rating?.toString() ?? '';
    _latCtrl.text = r.latitude?.toString() ?? '';
    _lngCtrl.text = r.longitude?.toString() ?? '';
    _mapsUrlCtrl.text = r.mapsUrl ?? '';
    _infoUrlCtrl.text = r.infoUrl ?? '';
    _sourceCtrl.text = (r.source ?? 'ADMIN').trim();

    // ── Address parsing ────────────────────────────────────────────────────────
    // Use the 5-digit postcode as the anchor. If not found, fall back to
    // putting the whole string in addr1 so the admin can edit manually.
    final rawAddr = r.address ?? '';
    final parsed = _parseStoredAddress(rawAddr);
    if (parsed != null) {
      _addr1Ctrl.text = parsed.addr1;
      _addr2Ctrl.text = parsed.addr2;
      _postcodeCtrl.text = parsed.postcode;

      // Match raw state string against the dropdown list.
      // Use partial containment to handle variants like
      // "Wilayah Persekutuan Kuala Lumpur" → "Kuala Lumpur".
      if (parsed.rawState != null) {
        _selectedState = _malaysianStates.where((s) {
          final raw = parsed.rawState!;
          return raw == s || (raw.contains(s) && s.length >= 4);
        }).firstOrNull;
      }

      // Only pre-select city if it is in the known dropdown for that state.
      if (_selectedState != null && parsed.rawCity != null) {
        final knownCities = _citiesByState[_selectedState!] ?? [];
        _selectedCity = knownCities.contains(parsed.rawCity)
            ? parsed.rawCity
            : null;
      }
    } else {
      _addr1Ctrl.text = rawAddr;
    }

    // r.mainCuisineId stores the cuisine description (e.g. "Japanese") because
    // RestaurantModel.fromJson resolves the join alias. Resolve back to UUID.
    if (r.mainCuisineId != null) {
      final match = _allCuisines
          .where((c) => c.description == r.mainCuisineId)
          .toList();
      if (match.isNotEmpty) _mainCuisineId = match.first.id;
    }

    _extraCuisineIds = Set.from(detail.extraCuisines.map((c) => c.id));
    // Safety: main cuisine must not also appear in extra tags.
    _extraCuisineIds.remove(_mainCuisineId);

    _images = detail.images
        .map(
          (img) => _FormImage(
            id: img.imageId,
            networkUrl: img.imageUrl,
            isCover: img.isCover,
          ),
        )
        .toList();
  }

  void _prefillFromApproval(RestaurantApprovalModel approval) {
    _nameCtrl.text = approval.name;
    _descriptionCtrl.text = approval.description ?? '';
    _priceRangeCtrl.text = approval.priceRange ?? '';
    _ratingCtrl.text = approval.rating?.toString() ?? '';
    _latCtrl.text = approval.latitude?.toString() ?? '';
    _lngCtrl.text = approval.longitude?.toString() ?? '';
    _mapsUrlCtrl.text = approval.mapsUrl ?? '';
    _infoUrlCtrl.text = '';
    _sourceCtrl.text = (approval.source ?? 'User').trim();

    final rawAddr = approval.address ?? '';
    final parsed = _parseStoredAddress(rawAddr);
    if (parsed != null) {
      _addr1Ctrl.text = parsed.addr1;
      _addr2Ctrl.text = parsed.addr2;
      _postcodeCtrl.text = parsed.postcode;

      if (parsed.rawState != null) {
        _selectedState = _malaysianStates.where((s) {
          final raw = parsed.rawState!;
          return raw == s || (raw.contains(s) && s.length >= 4);
        }).firstOrNull;
      }

      if (_selectedState != null && parsed.rawCity != null) {
        final knownCities = _citiesByState[_selectedState!] ?? [];
        _selectedCity = knownCities.contains(parsed.rawCity)
            ? parsed.rawCity
            : null;
      }
    } else {
      _addr1Ctrl.text = rawAddr;
    }

    _mainCuisineId = approval.mainCuisineId;

    if (approval.imageUrl != null && approval.imageUrl!.trim().isNotEmpty) {
      _images = [
        _FormImage(
          id: 'approval_img_0',
          networkUrl: approval.imageUrl!.trim(),
          isCover: true,
        ),
      ];
    }
  }

  // ── Address parser ────────────────────────────────────────────────────────────

  /// Parses a stored Malaysian address string into structured fields using the
  /// **5-digit postcode as the anchor point** — no state-list validation needed.
  ///
  /// Handles both common formats:
  ///   • Combined  — `"addr1, 58200 Kuala Lumpur, State"` (API / external)
  ///   • Separate  — `"addr1, 58200, Kuala Lumpur, State"` (our own format)
  ///
  /// Everything **before** the postcode segment is joined into `addr1`.
  /// Everything **after** the city is joined into `rawState`.
  /// Returns `null` if no 5-digit postcode is found anywhere in the string.
  ({
    String addr1,
    String addr2,
    String postcode,
    String? rawCity,
    String? rawState,
  })?
  _parseStoredAddress(String raw) {
    if (raw.trim().isEmpty) return null;

    final parts = raw
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.length < 2) return null;

    // ── 1. Scan forward for the first segment that is (or starts with) a
    //       5-digit postcode ──────────────────────────────────────────────────
    final combinedRx = RegExp(r'^(\d{5})\s+(.+)$'); // "58200 Kuala Lumpur"
    final standaloneRx = RegExp(r'^\d{5}$'); // "58200"

    int postcodeIdx = -1;
    String postcode = '';
    String? rawCity;
    bool isCombined = false;

    for (int i = 0; i < parts.length; i++) {
      final cm = combinedRx.firstMatch(parts[i]);
      if (cm != null) {
        postcodeIdx = i;
        postcode = cm.group(1)!;
        rawCity = cm.group(2)!.trim();
        isCombined = true;
        break;
      }
      if (standaloneRx.hasMatch(parts[i])) {
        postcodeIdx = i;
        postcode = parts[i];
        isCombined = false;
        break;
      }
    }

    if (postcodeIdx == -1) return null; // no postcode found → can't parse

    // ── 2. Split segments before postcode into addr1 + addr2 ─────────────────
    // addr1 takes at most 4 parts (3 commas); anything beyond goes to addr2.
    final preParts = parts.sublist(0, postcodeIdx);
    if (preParts.isEmpty) return null; // nothing before postcode

    const addr1MaxParts = 4;
    final String addr1;
    final String addr2;
    if (preParts.length <= addr1MaxParts) {
      addr1 = preParts.join(', ');
      addr2 = '';
    } else {
      addr1 = preParts.sublist(0, addr1MaxParts).join(', ');
      addr2 = preParts.sublist(addr1MaxParts).join(', ');
    }

    // ── 3. City and state from the segments after the postcode ───────────────
    String? rawState;
    if (isCombined) {
      // city already extracted from the postcode segment itself.
      // Remaining parts (after postcodeIdx) form the state.
      if (postcodeIdx + 1 < parts.length) {
        rawState = parts.sublist(postcodeIdx + 1).join(', ');
      }
    } else {
      // Next segment = city, everything after = state.
      if (postcodeIdx + 1 < parts.length) {
        rawCity = parts[postcodeIdx + 1];
      }
      if (postcodeIdx + 2 < parts.length) {
        rawState = parts.sublist(postcodeIdx + 2).join(', ');
      }
    }

    return (
      addr1: addr1,
      addr2: addr2,
      postcode: postcode,
      rawCity: rawCity,
      rawState: rawState,
    );
  }

  // ── Add cuisine dialog ────────────────────────────────────────────────────────

  /// Shows a dialog for the admin to type a new cuisine name.
  ///
  /// The cuisine is stored locally as a [_PendingCuisine] and is only written
  /// to the database when the form is submitted — no async work happens here.
  Future<void> _addCuisineDialog({required bool forMain}) async {
    final ctrl = TextEditingController();
    String? confirmed;

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(forMain ? 'Add Main Cuisine' : 'Add Cuisine Tag'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            placeholder: 'e.g. Vietnamese',
            autofocus: true,
            padding: const EdgeInsets.all(10),
            textCapitalization: TextCapitalization.words,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) confirmed = name;
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    ctrl.dispose();
    if (confirmed == null || !mounted) return;

    final tempId = '_temp_${_pendingCuisineCounter++}';
    final pending = _PendingCuisine(
      tempId: tempId,
      name: confirmed!,
      isPrimaryOption: forMain,
    );
    final asCuisine = CuisineModel(
      id: tempId,
      description: confirmed!,
      isPrimaryOption: forMain,
    );

    setState(() {
      _pendingCuisines.add(pending);

      // Insert alphabetically into the display lists.
      _allCuisines = [..._allCuisines, asCuisine]
        ..sort((a, b) => a.description.compareTo(b.description));

      if (forMain) {
        _primaryCuisines = [..._primaryCuisines, asCuisine]
          ..sort((a, b) => a.description.compareTo(b.description));
        // Auto-select the new cuisine as main and ensure it is not in extra tags.
        _mainCuisineId = tempId;
        _extraCuisineIds.remove(tempId);
      } else {
        // Auto-add new extra cuisine tag and deselect it from main if coincidentally same.
        _extraCuisineIds.add(tempId);
      }
    });
  }

  // ── Resolve pending cuisines ─────────────────────────────────────────────────

  /// Creates all [_PendingCuisine] entries in the database and returns a map
  /// of `tempId → real database UUID`.  Called once at submit time.
  Future<Map<String, String>> _resolvePendingCuisines() async {
    final idMap = <String, String>{};
    for (final pending in _pendingCuisines) {
      final realId = await _repo.createCuisine(
        name: pending.name,
        isPrimaryOption: pending.isPrimaryOption,
      );
      idMap[pending.tempId] = realId;
    }
    return idMap;
  }

  // ── Validation ───────────────────────────────────────────────────────────────

  bool _validate() {
    _errors.clear();

    if (_nameCtrl.text.trim().isEmpty) {
      _errors['name'] = 'Name is required';
    }
    if (_addr1Ctrl.text.trim().isEmpty) {
      _errors['addr1'] = 'Address is required';
    }
    if (_postcodeCtrl.text.trim().isEmpty) {
      _errors['postcode'] = 'Required';
    }
    if (_selectedState == null) {
      _errors['state'] = 'Required';
    }
    if (_selectedCity == null) {
      _errors['city'] = 'Required';
    }
    if (_mainCuisineId == null) {
      _errors['cuisine'] = 'Main cuisine is required';
    }

    final lat = _latCtrl.text.trim();
    final lng = _lngCtrl.text.trim();
    if (lat.isNotEmpty && double.tryParse(lat) == null) {
      _errors['lat'] = 'Invalid number';
    }
    if (lng.isNotEmpty && double.tryParse(lng) == null) {
      _errors['lng'] = 'Invalid number';
    }
    if (lat.isNotEmpty && lng.isEmpty) {
      _errors['lng'] = 'Required if latitude is set';
    }
    if (lng.isNotEmpty && lat.isEmpty) {
      _errors['lat'] = 'Required if longitude is set';
    }

    final rating = _ratingCtrl.text.trim();
    if (rating.isNotEmpty) {
      final parsedRating = double.tryParse(rating);
      if (parsedRating == null) {
        _errors['rating'] = 'Invalid number';
      } else if (parsedRating < 0 || parsedRating > 5) {
        _errors['rating'] = 'Must be between 0 and 5';
      }
    }

    final mapsUrl = _mapsUrlCtrl.text.trim();
    if (mapsUrl.isNotEmpty) {
      final uri = Uri.tryParse(mapsUrl);
      if (uri == null || !uri.hasScheme) _errors['mapsUrl'] = 'Invalid URL';
    }

    final infoUrl = _infoUrlCtrl.text.trim();
    if (infoUrl.isNotEmpty) {
      final uri = Uri.tryParse(infoUrl);
      if (uri == null || !uri.hasScheme) _errors['infoUrl'] = 'Invalid URL';
    }

    // Auto-assign cover if none set.
    if (_images.isNotEmpty && !_images.any((i) => i.isCover)) {
      _images.first.isCover = true;
    }

    setState(() {});
    return _errors.isEmpty;
  }

  // ── Image helpers ─────────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    setState(() {
      for (final xf in picked) {
        _images.add(
          _FormImage(
            id: 'new_${_imgIdCounter++}',
            file: File(xf.path),
            isCover: _images.isEmpty, // first image auto-becomes cover
          ),
        );
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      final removed = _images.removeAt(index);
      if (removed.isCover && _images.isNotEmpty) {
        _images.first.isCover = true;
      }
    });
  }

  void _setCover(int index) {
    setState(() {
      for (int i = 0; i < _images.length; i++) {
        _images[i].isCover = i == index;
      }
    });
  }

  // ── Address helper ────────────────────────────────────────────────────────────

  String _buildAddress() {
    final parts = <String>[];
    if (_addr1Ctrl.text.trim().isNotEmpty) {
      parts.add(_addr1Ctrl.text.trim());
    }
    if (_addr2Ctrl.text.trim().isNotEmpty) {
      parts.add(_addr2Ctrl.text.trim());
    }
    if (_postcodeCtrl.text.trim().isNotEmpty) {
      parts.add(_postcodeCtrl.text.trim());
    }
    if (_selectedCity != null) {
      parts.add(_selectedCity!);
    }
    if (_selectedState != null) {
      parts.add(_selectedState!);
    }
    return parts.join(', ');
  }

  // ── Submit ────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isApprovalMode) {
      await _acceptApproval();
      return;
    }

    if (!_validate()) return;
    setState(() => _isSubmitting = true);

    try {
      // Step 0 — Persist any cuisines the admin created during this session.
      //          Pending entries use temp IDs; after this step we have real UUIDs.
      final pendingMap = await _resolvePendingCuisines();
      final resolvedMainId = pendingMap[_mainCuisineId] ?? _mainCuisineId!;
      final resolvedExtraIds = _extraCuisineIds
          .map((id) => pendingMap[id] ?? id)
          .toList();

      final address = _buildAddress();
      final lat = double.tryParse(_latCtrl.text.trim());
      final lng = double.tryParse(_lngCtrl.text.trim());
      final mapsUrl = _mapsUrlCtrl.text.trim().isEmpty
          ? null
          : _mapsUrlCtrl.text.trim();
      final infoUrl = _infoUrlCtrl.text.trim().isEmpty
          ? null
          : _infoUrlCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      final description = _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim();
      final priceRange = _priceRangeCtrl.text.trim().isEmpty
          ? null
          : _priceRangeCtrl.text.trim();
      final rating = double.tryParse(_ratingCtrl.text.trim());

      // Step 1 — Ensure a restaurant row exists so we have an ID for storage paths.
      //          In add mode we create the row now; in edit mode we use the known ID.
      final String targetId =
          widget.restaurantId ??
          await _repo.createRestaurant(
            name: name,
            description: description,
            priceRange: priceRange,
            address: address,
            latitude: lat,
            longitude: lng,
            mapsUrl: mapsUrl,
            mainCuisineId: resolvedMainId,
            infoUrl: infoUrl,
            source: 'ADMIN',
            rating: rating,
          );

      // Step 2 — Upload any newly picked local images; keep existing remote ones.
      final imageRecords = <RestaurantImageRecord>[];
      for (final img in _images) {
        if (img.file != null) {
          final bytes = await img.file!.readAsBytes();
          final rawExt = img.file!.path.split('.').last.toLowerCase();
          final ext = const ['jpg', 'jpeg', 'png', 'webp'].contains(rawExt)
              ? rawExt
              : 'jpg';
          final record = await _repo.uploadRestaurantImageBytes(
            restaurantId: targetId,
            bytes: bytes,
            fileExt: ext,
            isCover: img.isCover,
          );
          imageRecords.add(record);
        } else if (img.networkUrl != null) {
          imageRecords.add(
            RestaurantImageRecord(
              imageId: img.id,
              imageUrl: img.networkUrl!,
              isCover: img.isCover,
            ),
          );
        }
      }

      // Step 3 — Persist full restaurant record (details + cuisine tags + images).
      //          For add mode this performs an update on the just-created row, which
      //          is a safe no-op duplication. For edit mode this is the normal update.
      await _repo.saveRestaurant(
        restaurantId: targetId,
        name: name,
        address: address,
        mainCuisineId: resolvedMainId,
        latitude: lat,
        longitude: lng,
        mapsUrl: mapsUrl,
        infoUrl: infoUrl,
        source: 'ADMIN',
        extraCuisineIds: resolvedExtraIds,
        images: imageRecords,
        description: description,
        priceRange: priceRange,
        rating: rating,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      await showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Text(
            _isEditMode ? 'Restaurant Updated' : 'Restaurant Created',
          ),
          content: Text(
            _isEditMode ? '$name has been updated.' : '$name has been created.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
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
    }
  }

  Future<void> _acceptApproval() async {
    if (!_validate()) return;

    final approval = _approval;
    if (approval == null) {
      _showErrorDialog('Approval context is missing.');
      return;
    }

    final confirmed = await _showAcceptConfirmDialog();
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final pendingMap = await _resolvePendingCuisines();
      final resolvedMainId = pendingMap[_mainCuisineId] ?? _mainCuisineId!;
      final resolvedExtraIds = _extraCuisineIds
          .map((id) => pendingMap[id] ?? id)
          .toList();
      final rating = double.tryParse(_ratingCtrl.text.trim());

      final decision = ApprovalDecisionInput(
        approvalId: approval.approvalId,
        name: _nameCtrl.text.trim(),
        address: _buildAddress(),
        latitude: double.tryParse(_latCtrl.text.trim()),
        longitude: double.tryParse(_lngCtrl.text.trim()),
        mapsUrl: _mapsUrlCtrl.text.trim().isEmpty
            ? null
            : _mapsUrlCtrl.text.trim(),
        infoUrl: _infoUrlCtrl.text.trim().isEmpty
            ? null
            : _infoUrlCtrl.text.trim(),
        source: _sourceCtrl.text.trim().isEmpty
            ? 'USER'
            : _sourceCtrl.text.trim().toUpperCase(),
        rating: rating,
        mainCuisineId: resolvedMainId,
        extraCuisineIds: resolvedExtraIds,
        images: _buildApprovalDecisionImages(),
      );

      await _approvalRepo.acceptApprovalReviewed(decision);

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await _showInfoDialog(
        title: 'Approval Accepted',
        message:
            '${decision.name} has been accepted and published as a restaurant.',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _rejectApproval() async {
    final approval = _approval;
    if (approval == null) {
      _showErrorDialog('Approval context is missing.');
      return;
    }

    final confirmed = await _showRejectConfirmDialog();
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final pendingMap = await _resolvePendingCuisines();
      final resolvedMainId =
          pendingMap[_mainCuisineId] ??
          _mainCuisineId ??
          approval.mainCuisineId;
      final resolvedExtraIds = _extraCuisineIds
          .map((id) => pendingMap[id] ?? id)
          .toList();
      final rating = double.tryParse(_ratingCtrl.text.trim());

      final fallbackName = approval.name.trim();
      final inputName = _nameCtrl.text.trim().isEmpty
          ? fallbackName
          : _nameCtrl.text.trim();

      final builtAddress = _buildAddress().trim();
      final fallbackAddress = (approval.address ?? '').trim();
      final inputAddress = builtAddress.isEmpty
          ? fallbackAddress
          : builtAddress;

      final decision = ApprovalDecisionInput(
        approvalId: approval.approvalId,
        name: inputName,
        address: inputAddress,
        latitude: double.tryParse(_latCtrl.text.trim()),
        longitude: double.tryParse(_lngCtrl.text.trim()),
        mapsUrl: _mapsUrlCtrl.text.trim().isEmpty
            ? null
            : _mapsUrlCtrl.text.trim(),
        infoUrl: _infoUrlCtrl.text.trim().isEmpty
            ? null
            : _infoUrlCtrl.text.trim(),
        source: _sourceCtrl.text.trim().isEmpty
            ? 'USER'
            : _sourceCtrl.text.trim().toUpperCase(),
        rating: rating,
        mainCuisineId: resolvedMainId,
        extraCuisineIds: resolvedExtraIds,
        images: _buildApprovalDecisionImages(),
      );

      await _approvalRepo.rejectApprovalReviewed(decision);

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await _showInfoDialog(
        title: 'Approval Rejected',
        message:
            '${decision.name} has been rejected and linked pending posts were blocked.',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showErrorDialog(e.toString());
    }
  }

  List<ApprovalFinalImageInput> _buildApprovalDecisionImages() {
    final out = <ApprovalFinalImageInput>[];
    for (final img in _images) {
      if (img.file != null) {
        out.add(
          ApprovalFinalImageInput.upload(
            bytes: img.file!.readAsBytesSync(),
            fileExt: _fileExtFromPath(img.file!.path),
            isCover: img.isCover,
          ),
        );
      } else if (img.networkUrl != null && img.networkUrl!.trim().isNotEmpty) {
        out.add(
          ApprovalFinalImageInput.existing(
            url: img.networkUrl!.trim(),
            isCover: img.isCover,
          ),
        );
      }
    }
    return out;
  }

  String _fileExtFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.jpeg')) return 'jpeg';
    if (lower.endsWith('.jpg')) return 'jpg';
    return 'jpg';
  }

  Future<bool?> _showRejectConfirmDialog() {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Reject Approval?'),
        content: const Text(
          'This will reject this restaurant approval and block all linked pending posts.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showAcceptConfirmDialog() {
    final current = _currentRestaurant;
    final reviewedName = _nameCtrl.text.trim();
    final reviewedAddress = _buildAddress();
    final reviewedMainCuisine = _allCuisines
        .where((c) => c.id == _mainCuisineId)
        .map((c) => c.description)
        .firstOrNull;

    if (current == null) {
      return showCupertinoDialog<bool>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Accept Approval?'),
          content: const Text(
            'This will create a new restaurant from your reviewed values and publish linked pending posts.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );
    }

    return showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Accept & Replace?'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            _ComparisonBlock(
              title: 'Current Restaurant',
              name: current.name,
              address: current.address,
              mainCuisine: current.mainCuisineName,
              source: current.source,
              status: current.isDisabled ? 'Disabled' : 'Active',
            ),
            const SizedBox(height: 8),
            _ComparisonBlock(
              title: 'Reviewed Approval',
              name: reviewedName,
              address: reviewedAddress,
              mainCuisine: reviewedMainCuisine,
              source: _sourceCtrl.text.trim(),
              status: 'Pending approval',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

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
          _isApprovalMode
              ? 'Review Approval'
              : _isEditMode
              ? 'Edit Restaurant'
              : 'Add Restaurant',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }

    if (_loadError != null) {
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
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                onPressed: _loadData,
                child: const Text('Retry', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              const SizedBox(height: 8),
              if (_isApprovalMode && _currentRestaurant != null)
                _buildCurrentRestaurantInfoCard(),
              if (_isApprovalMode && _currentRestaurant != null)
                const SizedBox(height: 8),
              _buildBasicInfoSection(),
              const SizedBox(height: 8),
              _buildCuisineSection(),
              const SizedBox(height: 8),
              _buildImageSection(),
              const SizedBox(height: 16),
              _isApprovalMode ? _buildDecisionButtons() : _buildSubmitButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentRestaurantInfoCard() {
    final current = _currentRestaurant;
    if (current == null) return const SizedBox.shrink();

    return _SectionCard(
      title: 'Current Restaurant Context',
      children: [
        _InfoLine(label: 'Name', value: current.name),
        _InfoLine(label: 'Address', value: current.address ?? '-'),
        _InfoLine(label: 'Main Cuisine', value: current.mainCuisineName ?? '-'),
        _InfoLine(label: 'Source', value: current.source ?? '-'),
        _InfoLine(
          label: 'Status',
          value: current.isDisabled ? 'Disabled' : 'Active',
        ),
      ],
    );
  }

  // ── Section 1: Basic Info ─────────────────────────────────────────────────────

  Widget _buildBasicInfoSection() {
    final cities = _selectedState != null
        ? (_citiesByState[_selectedState] ?? <String>[])
        : <String>[];

    return _SectionCard(
      title: 'Basic Information',
      children: [
        _FormField(
          label: 'Restaurant Name *',
          controller: _nameCtrl,
          placeholder: 'e.g. Sushi Nori',
          error: _errors['name'],
        ),
        _FormField(
          label: 'Description',
          controller: _descriptionCtrl,
          placeholder: 'Short restaurant description or about text',
          maxLines: 3,
        ),
        Row(
          children: [
            Expanded(
              child: _FormField(
                label: 'Price Range',
                controller: _priceRangeCtrl,
                placeholder: 'e.g. RM 20-40',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FormField(
                label: 'Rating',
                controller: _ratingCtrl,
                placeholder: 'e.g. 4.5',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                error: _errors['rating'],
              ),
            ),
          ],
        ),
        _FormField(
          label: 'Address Line 1 *',
          controller: _addr1Ctrl,
          placeholder: 'Street address',
          error: _errors['addr1'],
        ),
        _FormField(
          label: 'Address Line 2',
          controller: _addr2Ctrl,
          placeholder: 'Unit, floor, building (optional)',
        ),
        // Postcode + State + City row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: _FormField(
                label: 'Postcode *',
                controller: _postcodeCtrl,
                placeholder: 'e.g. 50000',
                keyboardType: TextInputType.number,
                error: _errors['postcode'],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPickerField(
                label: 'State *',
                value: _selectedState,
                placeholder: 'Select state',
                onTap: _showStatePicker,
                error: _errors['state'],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPickerField(
                label: 'City *',
                value: _selectedCity,
                placeholder: cities.isEmpty
                    ? 'Select state first'
                    : 'Select city',
                onTap: cities.isEmpty ? null : _showCityPicker,
                error: _errors['city'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: _FormField(
                label: 'Latitude',
                controller: _latCtrl,
                placeholder: 'e.g. 3.1480',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                error: _errors['lat'],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FormField(
                label: 'Longitude',
                controller: _lngCtrl,
                placeholder: 'e.g. 101.7130',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                error: _errors['lng'],
              ),
            ),
          ],
        ),
        _FormField(
          label: 'Maps URL',
          controller: _mapsUrlCtrl,
          placeholder: 'https://maps.google.com/...',
          keyboardType: TextInputType.url,
          error: _errors['mapsUrl'],
        ),
        _FormField(
          label: 'Info URL',
          controller: _infoUrlCtrl,
          placeholder: 'https://...',
          keyboardType: TextInputType.url,
          error: _errors['infoUrl'],
        ),
        _FormField(
          label: 'Source',
          controller: _sourceCtrl,
          placeholder: 'e.g. API / ADMIN',
          enabled: !_isApprovalMode,
        ),
      ],
    );
  }

  Widget _buildPickerField({
    required String label,
    String? value,
    required String placeholder,
    VoidCallback? onTap,
    String? error,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: onTap == null ? AppColors.surface : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: error != null
                      ? const Color(0xFFFF3B30)
                      : AppColors.divider,
                  width: 0.5,
                ),
              ),
              child: Text(
                value ?? placeholder,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                style: const TextStyle(fontSize: 11, color: Color(0xFFFF3B30)),
              ),
            ),
        ],
      ),
    );
  }

  void _showStatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.5,
        ),
        child: CupertinoActionSheet(
          title: const Text('Select State'),
          actions: _malaysianStates.map((s) {
            final selected = s == _selectedState;
            return CupertinoActionSheetAction(
              onPressed: () {
                setState(() {
                  _selectedState = s;
                  _selectedCity = null;
                });
                Navigator.pop(ctx);
              },
              child: Text(
                s,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }

  void _showCityPicker() {
    final cities = _citiesByState[_selectedState] ?? [];
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.5,
        ),
        child: CupertinoActionSheet(
          title: const Text('Select City'),
          actions: cities.map((c) {
            final selected = c == _selectedCity;
            return CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _selectedCity = c);
                Navigator.pop(ctx);
              },
              child: Text(
                c,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }

  // ── Section 2: Cuisine ────────────────────────────────────────────────────────

  Widget _buildCuisineSection() {
    final mainName = _mainCuisineId == null
        ? null
        : _primaryCuisines
              .where((c) => c.id == _mainCuisineId)
              .map((c) => c.description)
              .firstOrNull;

    return _SectionCard(
      title: 'Cuisine',
      children: [
        // Main cuisine label + "Add New" button
        Row(
          children: [
            const Expanded(
              child: Text(
                'Main Cuisine *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            _AddNewCuisineButton(onTap: () => _addCuisineDialog(forMain: true)),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _primaryCuisines.isEmpty ? null : _showMainCuisinePicker,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _errors['cuisine'] != null
                    ? const Color(0xFFFF3B30)
                    : AppColors.divider,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    mainName ?? 'Select cuisine...',
                    style: TextStyle(
                      fontSize: 14,
                      color: mainName != null
                          ? AppColors.textPrimary
                          : AppColors.textLight,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_errors['cuisine'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errors['cuisine']!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFFF3B30)),
            ),
          ),
        const SizedBox(height: 20),

        // Extra cuisine tags label + "Add New" button
        Row(
          children: [
            const Expanded(
              child: Text(
                'Extra Cuisine Tags',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            _AddNewCuisineButton(
              onTap: () => _addCuisineDialog(forMain: false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildExtraCuisineTags(),
      ],
    );
  }

  void _showMainCuisinePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.5,
        ),
        child: CupertinoActionSheet(
          title: const Text('Select Main Cuisine'),
          actions: _primaryCuisines.map((c) {
            final selected = c.id == _mainCuisineId;
            return CupertinoActionSheetAction(
              onPressed: () {
                setState(() {
                  _mainCuisineId = c.id;
                  // A cuisine cannot be both the main cuisine and an extra tag.
                  _extraCuisineIds.remove(c.id);
                });
                Navigator.pop(ctx);
              },
              child: Text(
                c.description,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraCuisineTags() {
    if (_allCuisines.isEmpty) {
      return const Text(
        'No cuisine tags available',
        style: TextStyle(fontSize: 13, color: AppColors.textLight),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allCuisines.where((c) => c.id != _mainCuisineId).map((c) {
        final selected = _extraCuisineIds.contains(c.id);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _extraCuisineIds.remove(c.id);
            } else {
              _extraCuisineIds.add(c.id);
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withAlpha(18)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withAlpha(60)
                    : AppColors.divider,
                width: 0.5,
              ),
            ),
            child: Text(
              c.description,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Section 3: Images ─────────────────────────────────────────────────────────

  Widget _buildImageSection() {
    return _SectionCard(
      title: 'Images',
      trailing: GestureDetector(
        onTap: _pickImages,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primary.withAlpha(50),
              width: 0.5,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.camera, size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                'Upload',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      children: [
        if (_images.isEmpty)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.cloud_upload,
                    size: 32,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to upload images',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'JPG, PNG supported',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _images.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (_, i) => _ImageCard(
              image: _images[i],
              onSetCover: () => _setCover(i),
              onRemove: () => _removeImage(i),
            ),
          ),
        if (_images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_images.length} image${_images.length != 1 ? 's' : ''} • Tap image to set as cover',
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ),
      ],
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : Text(
                  _isEditMode ? 'Update Restaurant' : 'Create Restaurant',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDecisionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          AbsorbPointer(
            absorbing: _isSubmitting,
            child: Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: _isSubmitting ? 0.55 : 1,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _rejectApproval,
                      child: const Text(
                        'Reject',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: const Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _acceptApproval,
                    child: _isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Accepting...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(radius: 7),
                  SizedBox(width: 8),
                  Text(
                    'Processing approval, please wait...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Small "+ Add New" pill button used next to cuisine section labels.
class _AddNewCuisineButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNewCuisineButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withAlpha(50),
            width: 0.5,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.add, size: 11, color: AppColors.primary),
            SizedBox(width: 3),
            Text(
              'Add New',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section card with a labelled header row and child content.
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBackground,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Labelled text field for the form.
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final String? error;
  final bool enabled;
  final int maxLines;

  const _FormField({
    required this.label,
    required this.controller,
    this.placeholder,
    this.keyboardType,
    this.error,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: controller,
            enabled: enabled,
            placeholder: placeholder,
            maxLines: maxLines,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: enabled ? AppColors.background : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: error != null
                    ? const Color(0xFFFF3B30)
                    : AppColors.divider,
                width: 0.5,
              ),
            ),
            style: TextStyle(
              fontSize: 14,
              color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            placeholderStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            keyboardType: keyboardType,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFFF3B30)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Image card: tap to set as cover, ✕ button to remove.
class _ImageCard extends StatelessWidget {
  final _FormImage image;
  final VoidCallback onSetCover;
  final VoidCallback onRemove;

  const _ImageCard({
    required this.image,
    required this.onSetCover,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSetCover,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: image.networkUrl != null
                ? Image.network(
                    image.networkUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : image.file != null
                ? Image.file(image.file!, fit: BoxFit.cover)
                : _placeholder(),
          ),
          // Cover border highlight
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: image.isCover ? AppColors.primary : AppColors.divider,
                width: image.isCover ? 2 : 0.5,
              ),
            ),
          ),
          // Cover badge
          if (image.isCover)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Cover',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  size: 12,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(CupertinoIcons.photo, size: 24, color: AppColors.textLight),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonBlock extends StatelessWidget {
  final String title;
  final String? name;
  final String? address;
  final String? mainCuisine;
  final String? source;
  final String? status;

  const _ComparisonBlock({
    required this.title,
    this.name,
    this.address,
    this.mainCuisine,
    this.source,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text('Name: ${name ?? '-'}', style: const TextStyle(fontSize: 12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Address: ', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  address ?? '-',
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.left,
                  softWrap: true,
                ),
              ),
            ],
          ),
          Text(
            'Main Cuisine: ${mainCuisine ?? '-'}',
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.start,
          ),
          Text(
            'Source: ${source ?? '-'}',
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.start,
          ),
          Text(
            'Status: ${status ?? '-'}',
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }
}
