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

  final durationController = TextEditingController();
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
    _isSelectionMode = value;
    notifyListeners();
  }

  final Set<int> selectedIndices = {};

  bool _isDragModeActive = false;
  bool get isDragModeActive => _isDragModeActive;
  set isDragModeActive(bool value) {
    _isDragModeActive = value;
    notifyListeners();
  }

  // State Variables
  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;
  set selectedCategory(String? value) {
    _selectedCategory = value;
    notifyListeners();
  }

  File? _thumbnailImage;
  File? get thumbnailImage => _thumbnailImage;
  set thumbnailImage(File? value) {
    _thumbnailImage = value;
    notifyListeners();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  bool _isPublished = false;
  bool get isPublished => _isPublished;
  set isPublished(bool value) {
    _isPublished = value;
    notifyListeners();
  }

  bool _isInitialLoading = true;
  bool get isInitialLoading => _isInitialLoading;
  set isInitialLoading(bool value) {
    _isInitialLoading = value;
    notifyListeners();
  }

  int? _newBatchDurationDays;
  int? get newBatchDurationDays => _newBatchDurationDays;
  set newBatchDurationDays(int? value) {
    _newBatchDurationDays = value;
    notifyListeners();
  }

  int? _courseValidityDays;
  int? get courseValidityDays => _courseValidityDays;
  set courseValidityDays(int? value) {
    _courseValidityDays = value;
    notifyListeners();
  }

  bool _hasCertificate = false;
  bool get hasCertificate => _hasCertificate;
  set hasCertificate(bool value) {
    _hasCertificate = value;
    notifyListeners();
  }

  File? _certificate1Image;
  File? get certificate1Image => _certificate1Image;
  set certificate1Image(File? value) {
    _certificate1Image = value;
    notifyListeners();
  }

  File? _certificate2Image;
  File? get certificate2Image => _certificate2Image;
  set certificate2Image(File? value) {
    _certificate2Image = value;
    notifyListeners();
  }

  int _selectedCertSlot = 1;
  int get selectedCertSlot => _selectedCertSlot;
  set selectedCertSlot(int value) {
    _selectedCertSlot = value;
    notifyListeners();
  }

  bool _isOfflineDownloadEnabled = true;
  bool get isOfflineDownloadEnabled => _isOfflineDownloadEnabled;
  set isOfflineDownloadEnabled(bool value) {
    _isOfflineDownloadEnabled = value;
    notifyListeners();
  }

  bool _isBigScreenEnabled = false;
  bool get isBigScreenEnabled => _isBigScreenEnabled;
  set isBigScreenEnabled(bool value) {
    _isBigScreenEnabled = value;
    notifyListeners();
  }

  bool _isSavingDraft = false;
  bool get isSavingDraft => _isSavingDraft;
  set isSavingDraft(bool value) {
    _isSavingDraft = value;
    notifyListeners();
  }

  bool isRestoringDraft = false;
  bool tightVerticalMode = false;

  String? _difficulty;
  String? get difficulty => _difficulty;
  set difficulty(String? value) {
    _difficulty = value;
    notifyListeners();
  }

  String? _selectedLanguage;
  String? get selectedLanguage => _selectedLanguage;
  set selectedLanguage(String? value) {
    _selectedLanguage = value;
    notifyListeners();
  }

  String? _selectedCourseMode;
  String? get selectedCourseMode => _selectedCourseMode;
  set selectedCourseMode(String? value) {
    _selectedCourseMode = value;
    notifyListeners();
  }

  String? _selectedSupportType;
  String? get selectedSupportType => _selectedSupportType;
  set selectedSupportType(String? value) {
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
    _isUploading = value;
    notifyListeners();
  }

  double _totalProgress = 0.0;
  double get totalProgress => _totalProgress;
  set totalProgress(double value) {
    _totalProgress = value;
    notifyListeners();
  }

  String _uploadStatus = '';
  String get uploadStatus => _uploadStatus;
  set uploadStatus(String value) {
    _uploadStatus = value;
    notifyListeners();
  }

  // Lists for UI
  final List<String> difficultyLevels = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> categories = ['Hardware', 'Software'];
  final List<String> languages = ['Hindi', 'English', 'Bengali'];
  final List<String> courseModes = ['Recorded', 'Live Session'];
  final List<String> supportTypes = ['WhatsApp Group', 'No Support'];

  // Highlights & FAQs
  final List<TextEditingController> highlightControllers = [];
  final List<Map<String, TextEditingController>> faqControllers = [];

  // Error States
  bool thumbnailError = false;
  bool titleError = false;
  bool descError = false;
  bool categoryError = false;
  bool difficultyError = false;
  bool batchDurationError = false;
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
  bool courseContentError = false;

  // Focus Nodes
  final titleFocus = FocusNode();
  final descFocus = FocusNode();
  final mrpFocus = FocusNode();
  final discountFocus = FocusNode();

  // Computed Properties for UI validation checks
  bool get hasContent =>
      thumbnailImage != null ||
      titleController.text.trim().isNotEmpty ||
      descController.text.trim().isNotEmpty ||
      selectedCategory != null ||
      difficulty != null ||
      newBatchDurationDays != null ||
      highlightControllers.any((c) => c.text.trim().isNotEmpty) ||
      faqControllers.any((f) =>
          (f['q']?.text.trim().isNotEmpty ?? false) ||
          (f['a']?.text.trim().isNotEmpty ?? false));

  bool get hasSetupContent =>
      mrpController.text.trim().isNotEmpty ||
      discountAmountController.text.trim().isNotEmpty ||
      selectedLanguage != null ||
      selectedCourseMode != null ||
      selectedSupportType != null ||
      whatsappController.text.trim().isNotEmpty ||
      courseValidityDays != null ||
      certificate1Image != null ||
      certificate2Image != null ||
      websiteUrlController.text.trim().isNotEmpty;

  void updateState() {
    notifyListeners();
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
    durationController.dispose();
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
