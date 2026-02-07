import 'dart:io';
import 'package:flutter/material.dart';
import '../backend_service/models/course_upload_task.dart';
import '../../../../services/bunny_cdn_service.dart';

class CourseStateManager extends ChangeNotifier {
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
  double _preparationProgress = 0.0;
  double get preparationProgress => _preparationProgress;
  set preparationProgress(double value) {
    _preparationProgress = value;
    notifyListeners();
  }

  String _preparationMessage = '';
  String get preparationMessage => _preparationMessage;
  set preparationMessage(String value) {
    _preparationMessage = value;
    notifyListeners();
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
    // We still notify because some labels depend on this in the header
    notifyListeners();
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

  double _totalProgress = 0.0;
  void calculateOverallProgress() {
    if (_uploadTasks.isEmpty) {
      if (_totalProgress != 0.0) {
        _totalProgress = 0.0;
        notifyListeners();
      }
      return;
    }
    double total = 0;
    for (var task in _uploadTasks) {
      total += task.progress;
    }
    final newProgress = total / _uploadTasks.length;
    if ((newProgress - _totalProgress).abs() > 0.01) {
      _totalProgress = newProgress;
      notifyListeners();
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
