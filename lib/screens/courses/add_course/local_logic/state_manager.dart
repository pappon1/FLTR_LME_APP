import 'dart:io';
import 'package:flutter/material.dart';
import '../backend_service/models/course_upload_task.dart';
import '../../../../services/bunny_cdn_service.dart';
import '../../../../models/course_model.dart';
import '../../../../services/config_service.dart';

class CourseStateManager extends ChangeNotifier {
  CourseStateManager() {
    mrpController.addListener(_onPriceChanged);
    discountAmountController.addListener(_onPriceChanged);
  }

  void _onPriceChanged() {
    calculateFinalPrice();
    notifyListeners();
  }

  final formKey = GlobalKey<FormState>();
  final bunnyService = BunnyCDNService();
  final pageController = PageController();
  final scrollController = ScrollController();

  int _currentStep = 0;
  int get currentStep => _currentStep;
  set currentStep(int value) {
    if (_currentStep == value) return;
    _currentStep = value;
    notifyListeners();
  }

  // Controllers
  final titleController = TextEditingController();
  final descController = TextEditingController();

  // Pricing Controllers
  final mrpController = TextEditingController();
  final discountAmountController = TextEditingController();
  final finalPriceController = TextEditingController();

  final whatsappController = TextEditingController();
  final websiteUrlController = TextEditingController();
  final specialTagController = TextEditingController();
  final customValidityController = TextEditingController();

  // Content Management
  final List<Map<String, dynamic>> _courseContents = [];
  List<Map<String, dynamic>> get courseContents => _courseContents;

  // Selection Mode
  bool _isSelectionMode = false;
  bool get isSelectionMode => _isSelectionMode;
  set isSelectionMode(bool value) {
    if (_isSelectionMode == value) return;
    _isSelectionMode = value;
    notifyListeners();
  }

  final Set<int> selectedIndices = {};

  bool _isDragModeActive = false;
  bool get isDragModeActive => _isDragModeActive;
  set isDragModeActive(bool value) {
    if (_isDragModeActive == value) return;
    _isDragModeActive = value;
    notifyListeners();
  }

  // State Variables
  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;
  set selectedCategory(String? value) {
    if (_selectedCategory == value) return;
    _selectedCategory = value;
    notifyListeners();
  }

  File? _thumbnailImage;
  File? get thumbnailImage => _thumbnailImage;
  set thumbnailImage(File? value) {
    if (_thumbnailImage == value) return;
    _thumbnailImage = value;
    notifyListeners();
  }

  // Point 1: Preparation Feedback
  final ValueNotifier<double> preparationProgressNotifier =
      ValueNotifier<double>(0.0);
  final ValueNotifier<String> preparationMessageNotifier =
      ValueNotifier<String>('');

  double get preparationProgress => preparationProgressNotifier.value;
  set preparationProgress(double value) {
    preparationProgressNotifier.value = value;
  }

  String get preparationMessage => preparationMessageNotifier.value;
  set preparationMessage(String value) {
    preparationMessageNotifier.value = value;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  set isLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  bool _isPublished = false;
  bool get isPublished => _isPublished;
  set isPublished(bool value) {
    if (_isPublished == value) return;
    _isPublished = value;
    notifyListeners();
  }

  bool _isInitialLoading = true;
  bool get isInitialLoading => _isInitialLoading;
  set isInitialLoading(bool value) {
    if (_isInitialLoading == value) return;
    _isInitialLoading = value;
    notifyListeners();
  }

  int? _courseValidityDays;
  int? get courseValidityDays => _courseValidityDays;
  set courseValidityDays(int? value) {
    if (_courseValidityDays == value) return;
    _courseValidityDays = value;
    notifyListeners();
  }

  bool _hasCertificate = false;
  bool get hasCertificate => _hasCertificate;
  set hasCertificate(bool value) {
    if (_hasCertificate == value) return;
    _hasCertificate = value;
    notifyListeners();
  }

  File? _certificate1File;
  File? get certificate1File => _certificate1File;
  set certificate1File(File? value) {
    if (_certificate1File == value) return;
    _certificate1File = value;
    notifyListeners();
  }

  // Removed Syllabus logic as per new requirement
  // Defaulting everything to a single slot logic.

  bool _isOfflineDownloadEnabled = true;
  bool get isOfflineDownloadEnabled => _isOfflineDownloadEnabled;
  set isOfflineDownloadEnabled(bool value) {
    if (_isOfflineDownloadEnabled == value) return;
    _isOfflineDownloadEnabled = value;
    notifyListeners();
  }

  bool _isBigScreenEnabled = false;
  bool get isBigScreenEnabled => _isBigScreenEnabled;
  set isBigScreenEnabled(bool value) {
    if (_isBigScreenEnabled == value) return;
    _isBigScreenEnabled = value;
    notifyListeners();
  }

  // Screwdriver Tag Settings
  bool _isSpecialTagVisible = true;
  bool get isSpecialTagVisible => _isSpecialTagVisible;
  set isSpecialTagVisible(bool value) {
    if (_isSpecialTagVisible == value) return;
    _isSpecialTagVisible = value;
    notifyListeners();
  }

  String _specialTagColor = 'Blue';
  String get specialTagColor => _specialTagColor;
  set specialTagColor(String value) {
    if (_specialTagColor == value) return;
    _specialTagColor = value;
    notifyListeners();
  }

  // Granular Notifiers for local UI updates
  final ValueNotifier<bool> isSavingDraftNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> totalProgressNotifier = ValueNotifier<double>(
    0.0,
  );

  bool _isSavingDraft = false;
  bool get isSavingDraft => _isSavingDraft;
  set isSavingDraft(bool value) {
    if (_isSavingDraft == value) return;
    _isSavingDraft = value;
    isSavingDraftNotifier.value = value;
    // Removed notifyListeners() to prevent full screen rebuild.
    // All UI components MUST use ValueListenableBuilder<bool>(state.isSavingDraftNotifier).
  }

  bool isRestoringDraft = false;

  String? _difficulty;
  String? get difficulty => _difficulty;
  set difficulty(String? value) {
    if (_difficulty == value) return;
    _difficulty = value;
    notifyListeners();
  }

  String? _selectedLanguage;
  String? get selectedLanguage => _selectedLanguage;
  set selectedLanguage(String? value) {
    if (_selectedLanguage == value) return;
    _selectedLanguage = value;
    notifyListeners();
  }

  String? _selectedCourseMode;
  String? get selectedCourseMode => _selectedCourseMode;
  set selectedCourseMode(String? value) {
    if (_selectedCourseMode == value) return;
    _selectedCourseMode = value;
    notifyListeners();
  }

  String? _selectedSupportType;
  String? get selectedSupportType => _selectedSupportType;
  set selectedSupportType(String? value) {
    if (_selectedSupportType == value) return;
    _selectedSupportType = value;
    notifyListeners();
  }

  // Upload State
  List<CourseUploadTask> _uploadTasks = [];
  List<CourseUploadTask> get uploadTasks => _uploadTasks;
  set uploadTasks(List<CourseUploadTask> value) {
    _uploadTasks = value;
    notifyListeners();
  }

  bool _isUploading = false;
  bool get isUploading => _isUploading;
  set isUploading(bool value) {
    if (_isUploading == value) return;
    _isUploading = value;
    notifyListeners();
  }

  void calculateOverallProgress() {
    if (_uploadTasks.isEmpty) {
      if (totalProgressNotifier.value != 0.0) {
        totalProgressNotifier.value = 0.0;
      }
      return;
    }
    double total = 0;
    for (var task in _uploadTasks) {
      total += task.progress;
    }
    final newProgress = total / _uploadTasks.length;
    // 0.005 = 0.5% threshold to avoid excessive UI updates
    if ((newProgress - totalProgressNotifier.value).abs() > 0.005) {
      totalProgressNotifier.value = newProgress;
    }
  }

  void updateProgress(String id, double progress) {
    final index = _uploadTasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      if ((_uploadTasks[index].progress - progress).abs() > 0.01) {
        _uploadTasks[index].progress = progress;
        calculateOverallProgress();
      }
    }
  }

  // Lists for UI (Modern Optimization: static const)
  static const List<String> difficultyLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];
  static const List<String> categories = ['Hardware', 'Software'];
  static const List<String> languages = ['Hindi', 'English', 'Bengali'];
  static const List<String> courseModes = ['Recorded', 'Live Session'];
  static const List<String> supportTypes = ['WhatsApp Group', 'No Support'];
  static const List<String> tagColors = ['Blue', 'Red', 'Green', 'Pink'];

  // 30, 60, 90, or 0 (Always Visible)
  int _specialTagDurationDays = 30;
  int get specialTagDurationDays => _specialTagDurationDays;
  set specialTagDurationDays(int value) {
    if (_specialTagDurationDays == value) return;
    _specialTagDurationDays = value;
    notifyListeners();
  }

  // Highlights & FAQs
  final List<TextEditingController> highlightControllers = [];
  final List<Map<String, TextEditingController>> faqControllers = [];

  // Error States
  bool thumbnailError = false;
  bool titleError = false;
  bool descError = false;
  bool categoryError = false;
  bool difficultyError = false;
  bool highlightsError = false;
  bool faqsError = false;
  bool mrpError = false;
  bool languageError = false;
  bool courseModeError = false;
  bool supportTypeError = false;
  bool wpGroupLinkError = false;
  bool validityError = false;
  bool certError = false;
  bool bigScreenUrlError = false;
  bool discountError = false;
  bool discountWarning = false; // Updated: Maximum 50% discount check
  bool courseContentError = false;

  // Link Validation State
  bool isWpChecking = false;
  bool isWpValid = false;
  bool isWebChecking = false;
  bool isWebValid = false;

  // Focus Nodes
  final titleFocus = FocusNode();
  final descFocus = FocusNode();
  final mrpFocus = FocusNode();
  final discountFocus = FocusNode();

  // Scroll Keys (Step 0)
  final thumbnailKey = GlobalKey();
  final titleKey = GlobalKey();
  final descKey = GlobalKey();
  final categoryKey = GlobalKey();
  final difficultyKey = GlobalKey(); // Also for duration
  final highlightsKey = GlobalKey();
  final faqsKey = GlobalKey();

  // Scroll Keys (Step 1)
  final mrpKey = GlobalKey();
  final discountKey = GlobalKey();
  final languageKey = GlobalKey();
  final courseModeKey = GlobalKey();
  final supportTypeKey = GlobalKey();
  final whatsappKey = GlobalKey();
  final validityKey = GlobalKey();
  final certificateKey = GlobalKey();
  final bigScreenKey = GlobalKey();

  // Computed Properties for UI validation checks
  bool get hasContent =>
      thumbnailImage != null ||
      titleController.text.trim().isNotEmpty ||
      descController.text.trim().isNotEmpty ||
      selectedCategory != null ||
      difficulty != null ||
      selectedCategory != null ||
      difficulty != null ||
      highlightControllers.any((c) => c.text.trim().isNotEmpty) ||
      faqControllers.any(
        (f) =>
            (f['q']?.text.trim().isNotEmpty ?? false) ||
            (f['a']?.text.trim().isNotEmpty ?? false),
      );

  bool get hasSetupContent =>
      mrpController.text.trim().isNotEmpty ||
      discountAmountController.text.trim().isNotEmpty ||
      selectedLanguage != null ||
      selectedCourseMode != null ||
      selectedSupportType != null ||
      whatsappController.text.trim().isNotEmpty ||
      courseValidityDays != null ||
      certificate1File != null ||
      websiteUrlController.text.trim().isNotEmpty;

  void updateState() {
    notifyListeners();
  }

  void calculateFinalPrice() {
    final double mrp = double.tryParse(mrpController.text) ?? 0;
    final double discountAmt =
        double.tryParse(discountAmountController.text) ?? 0;

    if (mrp > 0) {
      // 50% Discount Warning Logic (No auto-correction, just warning)
      if (discountAmt > (mrp * 0.5)) {
        discountWarning = true;
      } else {
        discountWarning = false;
      }

      double finalPrice = mrp - discountAmt;
      if (finalPrice < 0) finalPrice = 0;
      finalPriceController.text = finalPrice.round().toString();
    } else {
      finalPriceController.text = '0';
      discountWarning = false;
    }
  }

  // Edit Mode
  String? editingCourseId;
  CourseModel? originalCourse;

  void initializeFromCourse(CourseModel course) {
    editingCourseId = course.id;
    originalCourse = course;

    // 1. Basic Info
    titleController.text = course.title;
    descController.text = course.description;
    selectedCategory = course.category;
    difficulty = course.difficulty;

    // 2. Setup
    mrpController.text = course.price.toString();
    // Calculate original discount amount (Price - DiscountedPrice)
    // Wait, discountPrice is the FINAL price.
    // Logic: Final = MRP - DiscountAmount
    // So DiscountAmount = MRP - Final
    discountAmountController.text = (course.price - course.discountPrice)
        .toString();
    finalPriceController.text = course.discountPrice.toString();

    selectedLanguage = course.language;
    selectedCourseMode = course.courseMode;
    selectedSupportType = course.supportType;
    whatsappController.text = course.whatsappNumber;
    websiteUrlController.text = course.websiteUrl;

    courseValidityDays = course.courseValidityDays;
    if (course.courseValidityDays > 0) {
      customValidityController.text = course.courseValidityDays.toString();
    }

    hasCertificate = course.hasCertificate;
    // Certificates are URLs, so we can't set File objects directly.
    // We need to handle this in UI or keep separate URL variables.
    // For now, let's just respect that if we pick a new file, it overrides.
    // We might need 'currentCertificateUrl' in state to display existing ones.

    isOfflineDownloadEnabled = course.isOfflineDownloadEnabled;
    isBigScreenEnabled = course.isBigScreenEnabled;

    // 3. Advanced
    specialTagController.text = course.specialTag;
    specialTagColor = course.specialTagColor;
    isSpecialTagVisible = course.isSpecialTagVisible;
    specialTagDurationDays = course.specialTagDurationDays;

    highlightControllers.clear();
    for (var h in course.highlights) {
      if (h.isNotEmpty) {
        highlightControllers.add(TextEditingController(text: h));
      }
    }
    if (highlightControllers.isEmpty) {
      highlightControllers.add(TextEditingController());
    }

    faqControllers.clear();
    for (var f in course.faqs) {
      faqControllers.add({
        'q': TextEditingController(text: f['question']),
        'a': TextEditingController(text: f['answer']),
      });
    }
    if (faqControllers.isEmpty) {
      faqControllers.add({
        'q': TextEditingController(),
        'a': TextEditingController(),
      });
    }

    // 4. Content & Thumbnail
    // We need to store current thumbnail URL to show it if no new file is picked
    currentThumbnailUrl = course.thumbnailUrl;
    currentCertificate1Url = course.certificateUrl1;

    // Deep copy contents to ensure mutability
    _courseContents.clear();
    _courseContents.addAll(_deepCopyContents(course.contents));

    isPublished = course.isPublished;
    notifyListeners();
  }

  // Helper to deep copy contents and ensure they are mutable maps + Normalize them
  List<Map<String, dynamic>> _deepCopyContents(List<dynamic> source) {
    return source.map((item) {
      return _normalizeContentItem(Map<String, dynamic>.from(item));
    }).toList();
  }

  // Normalization Logic (Centralized)
  Map<String, dynamic> _normalizeContentItem(Map<String, dynamic> item) {
    final Map<String, dynamic> copy = Map<String, dynamic>.from(item);

    // Default isLocal to false for existing items (if missing)
    if (!copy.containsKey('isLocal')) {
      copy['isLocal'] = false;
    }

    // Support multiple key names for the path
    final String? rawPath = (copy['path'] ?? copy['videoUrl'] ?? copy['url'])?.toString();
    if (rawPath == null) return copy;

    if (copy['type'] == 'video') {
      final cdnHost = ConfigService().bunnyStreamCdnHost;

      if (rawPath.contains('iframe.mediadelivery.net') || rawPath.contains(cdnHost)) {
        try {
          final uri = Uri.parse(rawPath);
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

          String? videoId;
          if (rawPath.contains('iframe.mediadelivery.net')) {
            videoId = segments.last;
          } else if (segments.isNotEmpty) {
            // Usually /VIDEO_ID/playlist.m3u8 or /play/LIB/VIDEO_ID
            // Attempt to find a long ID segment
            videoId = segments.firstWhere((s) => s.length > 20,
                orElse: () => segments[0]);
          }

          if (videoId != null && videoId != cdnHost && !videoId.startsWith('http')) {
             // Remove query params if any (e.g. ?autoplay=true)
             if (videoId.contains('?')) {
               videoId = videoId.split('?').first;
             }

             // Construct HLS URL
             final normalizedPath = 'https://$cdnHost/$videoId/playlist.m3u8';
             copy['path'] = normalizedPath;

            // Fix thumbnail if missing or empty
            if (copy['thumbnail'] == null ||
                copy['thumbnail'].toString().isEmpty) {
              copy['thumbnail'] = 'https://$cdnHost/$videoId/thumbnail.jpg';
            }
          } else {
             copy['path'] = rawPath;
          }
        } catch (_) {
          copy['path'] = rawPath;
        }
      } else {
        copy['path'] = rawPath;
      }
    } else if (copy['type'] == 'pdf' || copy['type'] == 'image') {
      copy['path'] = rawPath;
    }

    if (copy['type'] == 'folder' && copy['contents'] != null) {
      copy['contents'] = (copy['contents'] as List)
          .map((e) => _normalizeContentItem(Map<String, dynamic>.from(e)))
          .toList();
    }

    return copy;
  }

  // Public setter for DraftManager to use (Ensures normalization)
  void setContentsFromDraft(List<dynamic> rawContents) {
    _courseContents.clear();
    _courseContents.addAll(_deepCopyContents(rawContents));
    notifyListeners();
  }

  // Helper for existing URLs
  String? currentThumbnailUrl;
  String? currentCertificate1Url;

  @override
  void dispose() {
    pageController.dispose();
    scrollController.dispose();
    titleController.dispose();
    descController.dispose();
    mrpController.dispose();
    discountAmountController.dispose();
    finalPriceController.dispose();
    whatsappController.dispose();
    websiteUrlController.dispose();
    specialTagController.dispose();
    customValidityController.dispose();
    titleFocus.dispose();
    descFocus.dispose();
    mrpFocus.dispose();
    discountFocus.dispose();
    for (var c in highlightControllers) {
      c.dispose();
    }
    for (var f in faqControllers) {
      f['q']?.dispose();
      f['a']?.dispose();
    }
    super.dispose();
  }
}
