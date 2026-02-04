import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/course_model.dart';
import '../utils/simple_file_explorer.dart';
import '../../services/bunny_cdn_service.dart';
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'components/collapsing_step_indicator.dart';
import 'folder_detail_screen.dart';
import 'components/course_content_list_item.dart';
import '../../utils/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/clipboard_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../content_viewers/image_viewer_screen.dart';
import '../content_viewers/video_player_screen.dart';
import '../content_viewers/pdf_viewer_screen.dart';
import '../uploads/upload_progress_screen.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class CourseUploadTask {
  final String id;
  final String label;
  double progress;
  String status;

  CourseUploadTask({
    required this.id,
    required this.label,
    this.progress = 0.0,
    this.status = 'pending',
  });

  factory CourseUploadTask.fromMap(Map<String, dynamic> map) {
    return CourseUploadTask(
      id: map['id'] ?? '',
      label: map['remotePath']?.toString().split('/').last ?? 'File',
      progress: (map['progress'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'pending',
    );
  }
}

class _AddCourseScreenState extends State<AddCourseScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _bunnyService = BunnyCDNService();
  final _pageController = PageController();
  final _scrollController = ScrollController();
  int _currentStep = 0;

  // Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  // Pricing Controllers
  final _mrpController = TextEditingController(); // Original Price
  final _discountAmountController = TextEditingController(); // Amount to deduct
  final _finalPriceController =
      TextEditingController(); // Selling Price (Read Only)

  final _durationController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _specialTagController = TextEditingController(); // For "Special Offer" badges
  // Content Management
  final List<Map<String, dynamic>> _courseContents = [];

  // Selection Mode
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  // State Variables
  String? _selectedCategory;
  File? _thumbnailImage;
  bool _isLoading = false;
  bool _isPublished = false;
  bool _isInitialLoading = true;
  int? _newBatchDurationDays; // null by default as per user request
  int? _courseValidityDays; // null by default, 0 for Lifetime
  bool _hasCertificate = false;
  File? _certificate1Image;
  File? _certificate2Image;
  int _selectedCertSlot = 1; // 1 or 2
  bool _isOfflineDownloadEnabled = true;
  bool _isBigScreenEnabled = false;
  bool _isSavingDraft = false;
  bool _isRestoringDraft = false; // Flag to stop auto-save during initial load
  Timer? _saveDebounce;

  final _customValidityController = TextEditingController(); // For custom days
  String? _difficulty; // null by default as per user request

  final List<String> _difficultyLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];
  final List<String> _categories = ['Hardware', 'Software'];
  final List<String> _languages = ['Hindi', 'English', 'Bengali'];
  final List<String> _courseModes = ['Recorded', 'Live Session'];
  final List<String> _supportTypes = ['WhatsApp Group', 'No Support'];

  String? _selectedLanguage;
  String? _selectedCourseMode;
  String? _selectedSupportType;

  // Parallel Upload Progress State
  List<CourseUploadTask> _uploadTasks = [];
  bool _isUploading = false;
  double _totalProgress = 0.0;
  String _uploadStatus = '';

  // Design State (Dynamic for Layout Management)
  static const double _defRadius = 3.0;
  static const double _defInputPad = 10.0;
  static const double _defBorderOp = 0.12;
  static const double _defFillOp = 0.0;
  static const double _defSecSpace = 32.0;
  static const double _defFieldSpace = 16.0;
  static const double _defScreenPad = 10.0;
  static const double _defLabelSize = 14.0;

  double _globalRadius = _defRadius;
  double _inputVerticalPadding = _defInputPad;
  double _borderOpacity = _defBorderOp;
  double _fillOpacity = _defFillOp;
  double _screenPadding = _defScreenPad;
  double _labelFontSize = _defLabelSize;

  bool _tightVerticalMode = false;

  // Granular Spacing Variables (Fixed Values)
  double _s1HeaderSpace = 10.0;
  double _s1ImageSpace = 20.0;
  double _s1FieldSpace = 16.0;
  double _s2HeaderSpace = 10.0;
  double _s2PricingSpace = 20.0;
  double _s2LanguageSpace = 12.0;
  double _s2ValiditySpace = 12.0;
  double _s2PCSpace = 12.0;
  
  // Content Spacing
  double _contentItemLeftOffset = 5.0; 
  double _videoThumbTop = 0.50;
  double _videoThumbBottom = 0.50;
  double _imageThumbTop = 0.50;
  double _imageThumbBottom = 0.50;
  double _itemBottomSpacing = 5.0; // Fixed at 5.0
  
  // Menu & Lock Positioning (Fixed)
  double _menuOffset = 14.0;
  double _lockLeftOffset = -3.0;
  double _lockTopOffset = 0.0;
  double _lockSize = 14.0;
  
  // Label Positioning (Fixed)
  double _videoLabelOffset = 12.0;
  double _imageLabelOffset = 26.5;
  double _pdfLabelOffset = 16.5;
  double _folderLabelOffset = 15.5;
  double _tagLabelFontSize = 6.0;
  
  double _certToBigScreenSpace = 1.0;
  double _bigScreenToNavSpace = 24.0;
  double _contentIconOffset = 0.0; // New offset for content icons

  // Menu Panel Offsets & Size (Fixed)
  final double _menuPanelDX = -23.03;
  final double _menuPanelDY = 16.0;
  final double _menuPanelWidth = 125.0;
  final double _menuPanelHeight = 200.0;

  // Highlights & FAQs Controllers
  final List<TextEditingController> _highlightControllers = [];
  final List<Map<String, TextEditingController>> _faqControllers = [];

  // Validation & Focus
  bool _thumbnailError = false;
  bool _titleError = false;
  bool _descError = false;
  bool _categoryError = false;
  bool _difficultyError = false;
  bool _batchDurationError = false;
  bool _highlightsError = false;
  bool _faqsError = false;

  // Step 2 Errors
  bool _mrpError = false;
  bool _languageError = false;
  bool _courseModeError = false;
  bool _supportTypeError = false;
  bool _wpGroupLinkError = false;
  bool _validityError = false;
  bool _certError = false;
  bool _bigScreenUrlError = false;
  bool _discountError = false;
  bool _courseContentError = false;
  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();
  final _mrpFocus = FocusNode();
  final _discountFocus = FocusNode();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint("AddCourseScreen Init - Design Fixed");
    _mrpController.addListener(_calculateFinalPrice);
    _discountAmountController.addListener(_calculateFinalPrice);

    // Auto-save listeners for basic info
    _titleController.addListener(() => _saveCourseDraft());
    _descController.addListener(() => _saveCourseDraft());
    
    _mrpController.addListener(() {
      if (_mrpError && _mrpController.text.trim().isNotEmpty) {
        setState(() => _mrpError = false);
      }
      _saveCourseDraft();
    });
    
    _discountAmountController.addListener(() {
      if (_discountError && _discountAmountController.text.trim().isNotEmpty) {
        setState(() => _discountError = false);
      }
      _saveCourseDraft();
    });
    
    _whatsappController.addListener(() {
      if (_wpGroupLinkError && _whatsappController.text.trim().isNotEmpty) {
        setState(() => _wpGroupLinkError = false);
      }
      _saveCourseDraft();
    });
    
    _websiteUrlController.addListener(() {
      if (_bigScreenUrlError && _websiteUrlController.text.trim().isNotEmpty) {
        setState(() => _bigScreenUrlError = false);
      }
      _saveCourseDraft();
    });

    _specialTagController.addListener(() => _saveCourseDraft());

    // Load Draft
    _loadCourseDraft().then((_) {
      if (mounted) setState(() => _isInitialLoading = false);
    });

    // Background Service Progress Listener
    final service = FlutterBackgroundService();
    service.on('update').listen((event) {
      if (event != null && mounted) {
        final List<dynamic>? queue = event['queue'];
        if (queue != null) {
          setState(() {
            _uploadTasks = queue.map((t) => CourseUploadTask.fromMap(Map<String, dynamic>.from(t))).toList();
            _calculateOverallProgress();
          });
        }
      }
    });

    service.on('all_completed').listen((event) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Force save when app goes to background
      _saveCourseDraft(immediate: true);
    }
  }

  // --- Persistence Logic ---
  Future<void> _loadCourseDraft() async {
    try {
      _isRestoringDraft = true; // Block auto-save listeners
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('course_creation_draft');
      if (jsonString != null) {
        final Map<String, dynamic> draft = jsonDecode(jsonString);

        setState(() {
          _titleController.text = draft['title'] ?? '';
          _descController.text = draft['desc'] ?? '';
          _mrpController.text = draft['mrp'] ?? '';
          _discountAmountController.text = draft['discount'] ?? '';
          _selectedCategory = draft['category'];
          _difficulty = draft['difficulty'];
          _selectedLanguage = draft['language'];
          _selectedCourseMode = draft['courseMode'];
          _selectedSupportType = draft['supportType'];
          _whatsappController.text = draft['whatsappNumber'] ?? '';
          _specialTagController.text = draft['specialTag'] ?? '';
          _isBigScreenEnabled = draft['isBigScreenEnabled'] ?? false;
          _websiteUrlController.text = draft['websiteUrl'] ?? '';

          if (draft['contents'] != null) {
            _courseContents.clear();
            _courseContents.addAll(
              List<Map<String, dynamic>>.from(draft['contents']),
            );
          }

          _courseValidityDays = draft['validity'];
          _hasCertificate = draft['certificate'] ?? false;
          _selectedCertSlot = draft['certSlot'] ?? 1;
          _isOfflineDownloadEnabled = draft['offlineDownload'] ?? true;
          _isPublished = draft['isPublished'] ?? false;
          _newBatchDurationDays = draft['newBatchDuration'];

          if (draft['customDays'] != null) {
            _customValidityController.text = draft['customDays'].toString();
          }

          // Restore Image Paths (if files still exist)
          if (draft['thumbnailPath'] != null) {
            final file = File(draft['thumbnailPath']);
            if (file.existsSync()) _thumbnailImage = file;
          }
          if (draft['cert1Path'] != null) {
            final file = File(draft['cert1Path']);
            if (file.existsSync()) _certificate1Image = file;
          }
          if (draft['cert2Path'] != null) {
            final file = File(draft['cert2Path']);
            if (file.existsSync()) _certificate2Image = file;
          }

          // Restore Highlights
          if (draft['highlights'] != null) {
            _highlightControllers.clear();
            for (var h in draft['highlights']) {
              _highlightControllers.add(TextEditingController(text: h));
            }
          }

          // Restore FAQs
          if (draft['faqs'] != null) {
            _faqControllers.clear();
            for (var f in draft['faqs']) {
              _faqControllers.add({
                'q': TextEditingController(text: f['question']),
                'a': TextEditingController(text: f['answer']),
              });
            }
          }
        });

        // Silent restoration, no SnackBar
      }
    } catch (e) {
      // debugPrint("Error loading draft: $e");
    } finally {
      _isRestoringDraft = false;
    }
  }

  Future<void> _saveCourseDraft({bool immediate = false}) async {
    if (_isRestoringDraft) return; // Don't save while we are loading from Disk!
    // Debounce: Cancel previous timer if active
    if (_saveDebounce?.isActive ?? false) _saveDebounce!.cancel();

    if (immediate) {
      await _executeDraftSave();
      return;
    }

    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      await _executeDraftSave();
    });
  }

  Future<void> _executeDraftSave() async {
    if (!mounted) return;
    try {
      setState(() => _isSavingDraft = true);
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> draft = {
        'title': _titleController.text,
        'desc': _descController.text,
        'mrp': _mrpController.text,
        'discount': _discountAmountController.text,
        'category': _selectedCategory,
        'difficulty': _difficulty,
        // Only save shallow copy of contents for draft to avoid huge JSON if lots of local files?
        // Actually contents are maps, so okay.
        'contents': _courseContents,
        'validity': _courseValidityDays,
        'certificate': _hasCertificate,
        'certSlot': _selectedCertSlot,
        'offlineDownload': _isOfflineDownloadEnabled,
        'isPublished': _isPublished,
        'language': _selectedLanguage,
        'courseMode': _selectedCourseMode,
        'supportType': _selectedSupportType,
        'whatsappNumber': _whatsappController.text.trim(),
        'specialTag': _specialTagController.text.trim(),
        'isBigScreenEnabled': _isBigScreenEnabled,
        'websiteUrl': _websiteUrlController.text.trim(),

        'customDays': int.tryParse(_customValidityController.text),
        'thumbnailPath': _thumbnailImage?.path,
        'newBatchDuration': _newBatchDurationDays,
        'cert1Path': _certificate1Image?.path,
        'cert2Path': _certificate2Image?.path,
        'highlights': _highlightControllers.map((c) => c.text).toList(),
        'faqs': _faqControllers
            .map((f) => {'question': f['q']!.text, 'answer': f['a']!.text})
            .toList(),
      };

      await prefs.setString('course_creation_draft', jsonEncode(draft));

      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isSavingDraft = false);
        });
      }
    } catch (e) {
      // debugPrint("Error saving draft: $e");
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  void _calculateFinalPrice() {
    final double mrp = double.tryParse(_mrpController.text) ?? 0;
    final double discountAmt =
        double.tryParse(_discountAmountController.text) ?? 0;

    if (mrp > 0) {
      double finalPrice = mrp - discountAmt;
      if (finalPrice < 0) finalPrice = 0;
      _finalPriceController.text = finalPrice.round().toString();
    } else {
      _finalPriceController.text = '0';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel(); // Fix memory leak - dispose timer
    _titleController.dispose();
    _descController.dispose();
    _mrpController.dispose();
    _discountAmountController.dispose();
    _finalPriceController.dispose();
    _durationController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    _customValidityController.dispose();

    // Dispose FocusNodes
    _titleFocus.dispose();
    _descFocus.dispose();
    _mrpFocus.dispose();
    _discountFocus.dispose();

    for (var c in _highlightControllers) {
      c.dispose();
    }
    for (var f in _faqControllers) {
      f['q']?.dispose(); // Safe null check
      f['a']?.dispose(); // Safe null check
    }

    // Storage Optimization: Clear temporary files from picker cache
    unawaited(FilePicker.platform.clearTemporaryFiles());

    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final File file = File(pickedFile.path);
      final decodedImage = await decodeImageFromList(file.readAsBytesSync());

      // Validation: Check for 16:9 Ratio (approx 1.77) with tolerance
      final double ratio = decodedImage.width / decodedImage.height;
      if (ratio < 1.7 || ratio > 1.85) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Image must be YouTube Size (16:9 Ratio).'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return; // Reject
      }

      setState(() => _thumbnailImage = file);
      unawaited(_saveCourseDraft());
    }
  }

  void _showSuccessCelebration() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(3.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Lottie.network(
                    'https://assets10.lottiefiles.com/packages/lf20_pqnfmone.json', // Confetti Lottie
                    width: 200,
                    height: 200,
                    animate: true,
                    repeat: false,
                    errorBuilder: (c, e, s) => const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 100,
                    ),
                  ),
                  const Text(
                    'Congratulations! 🎉',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your course has been created successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close Dialog
                      Navigator.pop(
                        context,
                        true,
                      ); // Close Screen and Return Success
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  bool _validateAllFields() {
    if (!_validateStep0()) return false;
    if (!_validateStep1_5()) return false;
    return true;
  }

  bool _validateStep1_5() {
    bool isValid = true;
    String? firstError;

    setState(() {
      _mrpError = false;
      _discountError = false;
      _languageError = false;
      _courseModeError = false;
      _supportTypeError = false;
      _wpGroupLinkError = false;
      _validityError = false;
      _certError = false;
      _bigScreenUrlError = false;
    });

    if (_mrpController.text.trim().isEmpty) {
      setState(() => _mrpError = true);
      firstError ??= 'Please enter MRP (Price)';
      isValid = false;
    }

    if (_discountAmountController.text.trim().isEmpty) {
      setState(() => _discountError = true);
      firstError ??= 'Please enter Discount Amount';
      isValid = false;
    }

    if (_selectedLanguage == null) {
      setState(() => _languageError = true);
      firstError ??= 'Please select Course Language';
      isValid = false;
    }

    if (_selectedCourseMode == null) {
      setState(() => _courseModeError = true);
      firstError ??= 'Please select Course Mode';
      isValid = false;
    }

    if (_selectedSupportType == null) {
      setState(() => _supportTypeError = true);
      firstError ??= 'Please select Support Type';
      isValid = false;
    }

    if (_selectedSupportType == 'WhatsApp Group' && _whatsappController.text.trim().isEmpty) {
      setState(() => _wpGroupLinkError = true);
      firstError ??= 'Please paste WhatsApp Group Link';
      isValid = false;
    }

    if (_courseValidityDays == null) {
      setState(() => _validityError = true);
      firstError ??= 'Please select Course Validity';
      isValid = false;
    }

    if (_hasCertificate && _certificate1Image == null && _certificate2Image == null) {
      setState(() => _certError = true);
      firstError ??= 'Please upload at least one certificate design';
      isValid = false;
    }

    if (_isBigScreenEnabled && _websiteUrlController.text.trim().isEmpty) {
      setState(() => _bigScreenUrlError = true);
      firstError ??= 'Please enter Website Login URL';
      isValid = false;
    }

    if (!isValid) {
      _jumpToStep(1);
      if (firstError != null) _showWarning(firstError);
    }

    return isValid;
  }

  void _jumpToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
    );
  }

  void _showWarning(String message) {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: 85 + MediaQuery.of(context).padding.bottom,
          left: 24,
          right: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildCourseReviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(3.0),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Quick Course Review',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // --- Step 1: Basic Info ---
            Text('BASIC INFO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.withOpacity(0.7), letterSpacing: 1.1)),
            const SizedBox(height: 12),
            _buildReviewItem(
              Icons.title,
              'Title',
              _titleController.text.isEmpty ? 'Not Set' : _titleController.text,
              () => _jumpToStep(0),
            ),
            _buildReviewItem(
              Icons.category_outlined,
              'Category',
              _selectedCategory ?? 'Not Selected',
              () => _jumpToStep(0),
            ),
            _buildReviewItem(
              Icons.new_releases_outlined,
              'Badge',
              _newBatchDurationDays != null ? '$_newBatchDurationDays Days' : 'Not Set',
              () => _jumpToStep(0),
            ),
            
            const SizedBox(height: 8),
            const Divider(height: 24),
            
            // --- Step 1.5: Setup ---
            Text('SETUP & PRICING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.withOpacity(0.7), letterSpacing: 1.1)),
            const SizedBox(height: 12),
            _buildReviewItem(
              Icons.payments_outlined,
              'Pricing',
              '₹${_mrpController.text} (MRP) - ₹${_discountAmountController.text} (Disc) = ₹${_finalPriceController.text}',
              () => _jumpToStep(1),
            ),
            _buildReviewItem(
              Icons.language,
              'Language',
              _selectedLanguage ?? 'Not Set',
              () => _jumpToStep(1),
            ),
            _buildReviewItem(
              Icons.computer,
              'Mode',
              _selectedCourseMode ?? 'Not Set',
              () => _jumpToStep(1),
            ),
            _buildReviewItem(
              Icons.support_agent,
              'Support',
              _selectedSupportType ?? 'Not Set',
              () => _jumpToStep(1),
            ),
            _buildReviewItem(
              Icons.history_toggle_off,
              'Validity',
              _getValidityText(_courseValidityDays),
              () => _jumpToStep(1),
            ),
            _buildReviewItem(
              Icons.laptop_chromebook,
              'Web/PC',
              _isBigScreenEnabled ? 'Allowed' : 'Not Allowed',
              () => _jumpToStep(1),
            ),
            _buildReviewItem(
              Icons.download_for_offline_outlined,
              'Downloads',
              _isOfflineDownloadEnabled ? 'Enabled' : 'Disabled',
              () => _jumpToStep(3),
            ),
            if (_specialTagController.text.isNotEmpty)
              _buildReviewItem(
                Icons.local_offer_outlined,
                'Special Tag',
                _specialTagController.text,
                () => _jumpToStep(3),
              ),
            _buildReviewItem(
              Icons.video_collection_outlined,
              'Videos',
              '${_countItemsRecursively(_courseContents, 'video')} Videos Added',
              () => _jumpToStep(2),
            ),
            _buildReviewItem(
              Icons.picture_as_pdf_outlined,
              'Resources',
              '${_countItemsRecursively(_courseContents, 'pdf')} PDFs Added',
              () => _jumpToStep(2),
            ),
          ],
        ),
    );
  }

  String _getValidityText(int? days) {
    if (days == null) return 'Not Selected';
    if (days == 0) return 'Lifetime Access';
    if (days == 184) return '6 Months';
    if (days == 365) return '1 Year';
    if (days == 730) return '2 Years';
    if (days == 1095) return '3 Years';
    return '$days Days';
  }

  Widget _buildReviewItem(
    IconData icon,
    String label,
    String value,
    VoidCallback? onEdit,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(3.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '$label: ',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onEdit != null)
                const Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
  void _nextStep() async {
    if (_currentStep == 0 && !_validateStep0()) return;
    if (_currentStep == 1 && !_validateStep1_5()) return;
    
    if (_currentStep == 2) {
      if (_courseContents.isEmpty) {
        setState(() => _courseContentError = true);
        _showWarning('Please add at least one content to proceed');
        return;
      } else {
        setState(() => _courseContentError = false);
      }
    }

    if (_currentStep < 3) {
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 50));
      await _pageController.nextPage(duration: 250.ms, curve: Curves.easeInOut);
    }
  }

  bool get _hasContent =>
      _thumbnailImage != null ||
      _titleController.text.trim().isNotEmpty ||
      _descController.text.trim().isNotEmpty ||
      _selectedCategory != null ||
      _difficulty != null ||
      _newBatchDurationDays != null ||
      _highlightControllers.any((c) => c.text.trim().isNotEmpty) ||
      _faqControllers.any((f) =>
          (f['q']?.text.trim().isNotEmpty ?? false) ||
          (f['a']?.text.trim().isNotEmpty ?? false));

  bool get _hasSetupContent =>
      _mrpController.text.trim().isNotEmpty ||
      _discountAmountController.text.trim().isNotEmpty ||
      _selectedLanguage != null ||
      _selectedCourseMode != null ||
      _selectedSupportType != null ||
      _whatsappController.text.trim().isNotEmpty ||
      _courseValidityDays != null ||
      _certificate1Image != null ||
      _certificate2Image != null ||
      _websiteUrlController.text.trim().isNotEmpty;

  bool _validateStep0() {
    bool isValid = true;
    String? firstErrorOne;

    // Reset all errors
    setState(() {
      _thumbnailError = false;
      _titleError = false;
      _descError = false;
      _categoryError = false;
      _difficultyError = false;
      _batchDurationError = false;
    });

    // 1. Check Thumbnail
    if (_thumbnailImage == null) {
      setState(() => _thumbnailError = true);
      isValid = false;
      firstErrorOne ??= 'thumbnail';
    }

    // 2. Check Title
    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = true);
      isValid = false;
      firstErrorOne ??= 'title';
    }

    // 3. Check Description
    if (_descController.text.trim().isEmpty) {
      setState(() => _descError = true);
      isValid = false;
      firstErrorOne ??= 'desc';
    }

    // 4. Check Category
    if (_selectedCategory == null) {
      setState(() => _categoryError = true);
      isValid = false;
      firstErrorOne ??= 'category';
    }

    // 5. Check Difficulty
    if (_difficulty == null) {
      setState(() => _difficultyError = true);
      isValid = false;
      firstErrorOne ??= 'difficulty';
    }

    // 6. Check Duration
    if (_newBatchDurationDays == null) {
      setState(() => _batchDurationError = true);
      isValid = false;
      firstErrorOne ??= 'duration';
    }

    // 7. Check Highlights
    bool hasEmptyHighlight = _highlightControllers.any((c) => c.text.trim().isEmpty);
    if (_highlightControllers.isEmpty || hasEmptyHighlight) {
      setState(() => _highlightsError = true);
      isValid = false;
      firstErrorOne ??= 'highlights';
    }

    // 8. Check FAQs
    bool hasEmptyFaq = _faqControllers.any((f) => 
        (f['q']?.text.trim().isEmpty ?? true) || 
        (f['a']?.text.trim().isEmpty ?? true)
    );
    if (_faqControllers.isEmpty || hasEmptyFaq) {
      setState(() => _faqsError = true);
      isValid = false;
      firstErrorOne ??= 'faqs';
    }

    if (!isValid) {
      if (firstErrorOne == 'thumbnail') {
        _scrollController.animateTo(0, duration: 300.ms, curve: Curves.easeOut);
        _showWarning('Please upload a cover image');
      } else if (firstErrorOne == 'title') {
        _titleFocus.requestFocus();
        _showWarning('Please enter a course title');
      } else if (firstErrorOne == 'desc') {
        _descFocus.requestFocus();
        _showWarning('Please enter a course description');
      } else if (firstErrorOne == 'category') {
        _showWarning('Please select a course category');
      } else if (firstErrorOne == 'difficulty') {
        _showWarning('Please select a course type');
      } else if (firstErrorOne == 'duration') {
        _showWarning('Please select new badge duration');
      } else if (firstErrorOne == 'highlights') {
         // Auto scroll to Highlights section
        _scrollController.animateTo(600, duration: 300.ms, curve: Curves.easeOut);
        _showWarning('Please add at least one highlight');
      } else if (firstErrorOne == 'faqs') {
         // Auto scroll to FAQs section
        _scrollController.animateTo(800, duration: 300.ms, curve: Curves.easeOut);
        _showWarning('Please add at least one FAQ');
      }
      return false;
    }
    return true;
  }


  void _prevStep() async {
    if (_currentStep > 0) {
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 50));
      await _pageController.previousPage(
        duration: 250.ms,
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitCourse() async {
    if (!_validateAllFields()) return;
    if (_courseContents.isEmpty) {
      setState(() => _courseContentError = true);
      _showWarning('Please add at least one content to the course');
      _jumpToStep(2);
      return;
    }

    // SAFETY LOCK: Check if another course is already uploading
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('pending_course_v1')) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Upload in Progress ⚠️"),
          content: const Text(
            "Another course is currently being uploaded in the background.\n\nTo ensure data safety, please wait for it to complete before creating a new one.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
      _uploadTasks = [];
    });

    try {
      await WakelockPlus.enable(); // Keep screen on during upload

      final String finalDesc = _descController.text.trim();
      final int finalValidity = _courseValidityDays == -1
          ? (int.tryParse(_customValidityController.text) ?? 0)
          : _courseValidityDays!;

      // SAFE COPY: Deduplication and Persistence
      final appDir = await getApplicationDocumentsDirectory();
      final safeDir = Directory('${appDir.path}/pending_uploads');
      if (!safeDir.existsSync()) safeDir.createSync(recursive: true);

      final Map<String, String> copiedPathMap = {};

      Future<String> copyToSafe(String rawPath) async {
        if (copiedPathMap.containsKey(rawPath)) return copiedPathMap[rawPath]!;

        final f = File(rawPath);
        if (!f.existsSync()) return rawPath;

        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(rawPath)}';
        final newPath = '${safeDir.path}/$filename';
        await f.copy(newPath);
        copiedPathMap[rawPath] = newPath;
        return newPath;
      }

      if (_thumbnailImage != null) {
        final newPath = await copyToSafe(_thumbnailImage!.path);
        _thumbnailImage = File(newPath);
      }
      if (_certificate1Image != null) {
        final newPath = await copyToSafe(_certificate1Image!.path);
        _certificate1Image = File(newPath);
      }
      if (_certificate2Image != null) {
        final newPath = await copyToSafe(_certificate2Image!.path);
        _certificate2Image = File(newPath);
      }

      // Recursive Safe Copy for ALL Content
      Future<void> safeCopyAllContent(List<dynamic> items) async {
        for (var item in items) {
          final String type = item['type'];

          if ((type == 'video' || type == 'pdf' || type == 'image') &&
              item['isLocal'] == true) {
            final String fPath = item['path'];
            if (fPath.isNotEmpty) {
              item['path'] = await copyToSafe(fPath);
            }
          }

          if (item['thumbnail'] != null && item['thumbnail'] is String) {
            final String tPath = item['thumbnail'];
            if (tPath.isNotEmpty && !tPath.startsWith('http')) {
              item['thumbnail'] = await copyToSafe(tPath);
            }
          }

          if (type == 'folder' && item['contents'] != null) {
            await safeCopyAllContent(item['contents']);
          }
        }
      }

      await safeCopyAllContent(_courseContents);



      // 0. Generate ID Upfront
      final newDocId = FirebaseFirestore.instance
          .collection('courses')
          .doc()
          .id;

      // Create "Draft" Course Model
      final draftCourse = CourseModel(
        id: newDocId,
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        price: int.tryParse(_mrpController.text) ?? 0,
        discountPrice: int.tryParse(_finalPriceController.text) ?? 0,
        description: finalDesc,
        thumbnailUrl: _thumbnailImage?.path ?? '',
        duration: _durationController.text.trim(),
        difficulty: _difficulty!,
        enrolledStudents: 0,
        rating: 0.0,
        totalVideos: _getAllVideosFromContents(_courseContents).length,
        isPublished: _isPublished,
        createdAt: DateTime.now(),
        newBatchDays: _newBatchDurationDays!,
        courseValidityDays: finalValidity,
        hasCertificate: _hasCertificate,
        certificateUrl1: _certificate1Image?.path,
        certificateUrl2: _certificate2Image?.path,
        selectedCertificateSlot: _selectedCertSlot,
        demoVideos: [],
        isOfflineDownloadEnabled: _isOfflineDownloadEnabled,
        language: _selectedLanguage!,
        courseMode: _selectedCourseMode!,
        supportType: _selectedSupportType!,
        whatsappNumber: _whatsappController.text.trim(),
        isBigScreenEnabled: _isBigScreenEnabled,
        websiteUrl: _websiteUrlController.text.trim(),
        contents: _courseContents,
        highlights: _highlightControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        faqs: _faqControllers
            .map(
              (f) => {
                'question': f['q']!.text.trim(),
                'answer': f['a']!.text.trim(),
              },
            )
            .where((f) => f['question']!.isNotEmpty && f['answer']!.isNotEmpty)
            .toList(),
      );

      // Generate Session ID
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final List<Map<String, dynamic>> fileTasks = [];
      final Set<String> processedFilePaths = {};

      void addTask(String filePath, String remotePath, String id, {String? thumbnail}) {
        if (processedFilePaths.contains(filePath)) return;
        processedFilePaths.add(filePath);
        fileTasks.add({
          'filePath': filePath,
          'remotePath': remotePath,
          'id': id,
          'thumbnail': thumbnail,
        });
      }

      // 1. Add Thumbnail Task
      if (_thumbnailImage != null) {
        addTask(
          _thumbnailImage!.path,
          'courses/$sessionId/thumbnails/thumb_${path.basename(_thumbnailImage!.path)}',
          'thumb',
        );
      }

      // 2. Add Certificate Tasks
      if (_hasCertificate) {
        if (_certificate1Image != null) {
          addTask(
            _certificate1Image!.path,
            'courses/$sessionId/certificates/cert1_${path.basename(_certificate1Image!.path)}',
            'cert1',
          );
        }
        if (_certificate2Image != null) {
          addTask(
            _certificate2Image!.path,
            'courses/$sessionId/certificates/cert2_${path.basename(_certificate2Image!.path)}',
            'cert2',
          );
        }
      }



      // 4. Recursively Collect ALL Files & Thumbnails
      int globalCounter = 0;
      void processItemRecursive(dynamic item) {
        final int currentIndex = globalCounter++;
        final String type = item['type'];

        if ((type == 'video' || type == 'pdf' || type == 'image') &&
            item['isLocal'] == true) {
          final filePath = item['path'];
          if (filePath != null && filePath is String) {
            String folder = 'others';
            if (type == 'video') {
              folder = 'videos';
            } else if (type == 'pdf')
              folder = 'pdfs';
            else if (type == 'image')
              folder = 'images';

            final uniqueName = '${currentIndex}_${item['name']}';
            addTask(
              filePath,
              'courses/$sessionId/$folder/$uniqueName',
              filePath,
              thumbnail: (type == 'video' && item['thumbnail'] != null) ? item['thumbnail'] : null,
            );
          }
        }

        if (item['thumbnail'] != null && item['thumbnail'] is String) {
          final String thumbPath = item['thumbnail'];
          if (thumbPath.isNotEmpty && !thumbPath.startsWith('http')) {
            addTask(
              thumbPath,
              'courses/$sessionId/thumbnails/thumb_${currentIndex}_${path.basename(thumbPath)}',
              thumbPath,
            );
          }
        }

        if (type == 'folder' && item['contents'] != null) {
          for (var sub in item['contents']) {
            processItemRecursive(sub);
          }
        }
      }

      for (var item in _courseContents) {
        processItemRecursive(item);
      }

      // 4. Send to Service (Fire and Forget)
      // Note: We strip Timestamp/Dates to simple Iso8601 strings for JSON safety
      final courseMap = draftCourse.toMap();
      courseMap['createdAt'] = DateTime.now()
          .toIso8601String(); // Service will convert back to Timestamp

      final service = FlutterBackgroundService();

      // Ensure it's running BEFORE sending
      if (!await service.isRunning()) {
        print("🚀 Service not running, starting now...");
        await service.startService();
        await Future.delayed(
          const Duration(seconds: 4),
        ); // Give it time to boot
      }

      print("📤 Sending 'submit_course' to background service...");
      service.invoke('submit_course', {
        'course': courseMap,
        'files': fileTasks,
      });

      // REDUNDANCY: In case the background isolate was busy/starting, send again after a short delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        service.invoke('submit_course', {
          'course': courseMap,
          'files': fileTasks,
        });
        service.invoke('get_status');
      });

      service.invoke('get_status');

      // 5. Success UI
      // We don't wait for upload. We tell user it started.

      if (mounted) {
        setState(() {
          _isUploading = true;
        });

        // Clear Local Draft
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('course_creation_draft');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload Started in Background 🚀'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // IMMEDIATE NAVIGATION: No delay, direct push
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const UploadProgressScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Wakelock might be managed by service now, but we can disable ours
      await WakelockPlus.disable();
    }
  }

  void _calculateOverallProgress() {
    if (_uploadTasks.isEmpty) return;
    double total = 0;
    for (var task in _uploadTasks) {
      total += task.progress;
    }
    _totalProgress = total / _uploadTasks.length;
  }


  // Helper to get ALL local files for upload
  List<Map<String, dynamic>> _getAllLocalFilesFromContents(
    List<dynamic> items,
  ) {
    final List<Map<String, dynamic>> files = [];
    for (var item in items) {
      if ((item['type'] == 'video' ||
              item['type'] == 'pdf' ||
              item['type'] == 'zip' ||
              item['type'] == 'image') &&
          item['isLocal'] == true) {
        files.add(item); // PASS BY REFERENCE
      } else if (item['type'] == 'folder' && item['contents'] != null) {
        files.addAll(_getAllLocalFilesFromContents(item['contents']));
      }
    }
    return files;
  }

  bool _isDragModeActive = false;
  Timer? _holdTimer;

  void _startHoldTimer() {
    if (_isSelectionMode) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 600), () {
      HapticFeedback.heavyImpact();
      setState(() {
        _isDragModeActive = true;
      });
    });
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
  }

  // --- Highlights Management ---
  void _addHighlight() {
    setState(() {
      _highlightsError = false;
      _highlightControllers.add(TextEditingController());
    });
  }

  void _removeHighlight(int index) {
    if (index >= 0 && index < _highlightControllers.length) {
      setState(() {
        _highlightsError = false;
        _highlightControllers[index].dispose();
        _highlightControllers.removeAt(index);
      });
      _saveCourseDraft();
    }
  }

  // --- FAQs Management ---
  void _addFAQ() {
    setState(() {
      _faqsError = false;
      _faqControllers.add({
        'q': TextEditingController(),
        'a': TextEditingController(),
      });
    });
  }

  void _removeFAQ(int index) {
    if (index >= 0 && index < _faqControllers.length) {
      setState(() {
        _faqsError = false;
        _faqControllers[index]['q']?.dispose();
        _faqControllers[index]['a']?.dispose();
        _faqControllers.removeAt(index);
      });
      _saveCourseDraft();
    }
  }

  void _clearBasicDraft() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Basic Info?'),
        content: const Text(
          'This will reset everything on this screen (Step 1). Content and Settings in Step 2 & 3 will remain safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _titleController.clear();
                _descController.clear();
                _selectedCategory = null;
                _difficulty = null;
                _newBatchDurationDays = null;
                _thumbnailImage = null;

                for (var c in _highlightControllers) {
                  c.dispose();
                }
                _highlightControllers.clear();

                for (var f in _faqControllers) {
                  f['q']?.dispose();
                  f['a']?.dispose();
                }
                _faqControllers.clear();
              });
              _saveCourseDraft();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _clearSetupDraft() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Setup Info?'),
        content: const Text(
          'This will reset Pricing, Validity, Language and Certificate settings. Basic Info and Content will remain safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _mrpController.clear();
                _discountAmountController.clear();
                _finalPriceController.clear();
                _selectedLanguage = null;
                _selectedCourseMode = null;
                _selectedSupportType = null;
                _whatsappController.clear();
                _courseValidityDays = null;
                _hasCertificate = false;
                _certificate1Image = null;
                _certificate2Image = null;
                _selectedCertSlot = 1;
                _isBigScreenEnabled = false;
                _websiteUrlController.clear();
              });
              _saveCourseDraft();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics:
                  const NeverScrollableScrollPhysics(), // Force button usage
              onPageChanged: (idx) {
                setState(() => _currentStep = idx);
              },
              children: [
                KeepAliveWrapper(child: _buildStep1Basic()),
                KeepAliveWrapper(child: _buildStep1_5Setup()),
                KeepAliveWrapper(child: _buildStep2Content()),
                KeepAliveWrapper(child: _buildStep3Advance()),
              ],
            ),
            if (_isUploading) _buildUploadingOverlay(),
            if (_isLoading && !_isUploading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }



  Widget _buildUploadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      width: double.infinity,
      height: double.infinity,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Lottie.network(
                'https://assets9.lottiefiles.com/packages/lf20_yzn8uNCX7t.json', // Uploading animation
                width: 150,
                height: 150,
                animate: true,
                repeat: true,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.cloud_upload_outlined,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Uploading Course Materials',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload will continue even if you switch apps',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 40),

              // Overall Progress
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Overall Progress',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${(_totalProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3.0),
                      child: LinearProgressIndicator(
                        value: _totalProgress,
                        minHeight: 12,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'BATCH DETAILS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Individual Task List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _uploadTasks.length,
                  itemBuilder: (context, index) {
                    final task = _uploadTasks[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                task.progress == 1.0
                                    ? Icons.check_circle
                                    : Icons.upload_file,
                                color: task.progress == 1.0
                                    ? Colors.green
                                    : Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  task.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                '${(task.progress * 100).toInt()}%',
                                style: TextStyle(
                                  color: task.progress == 1.0
                                      ? Colors.green
                                      : Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (task.progress < 1.0) ...[
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: task.progress,
                              minHeight: 4,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                task.progress == 1.0
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Warning Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1)),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please do not close or kill the app until the upload is complete.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isDragModeActive) {
      return AppBar(
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _isDragModeActive = false),
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Drag and Drop Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        elevation: 2,
      );
    }
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _isSelectionMode = false;
            _selectedIndices.clear();
          }),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${_selectedIndices.length} Selected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedIndices.length == _courseContents.length) {
                    _selectedIndices.clear();
                  } else {
                    _selectedIndices.clear();
                    for (int i = 0; i < _courseContents.length; i++) {
                      _selectedIndices.add(i);
                    }
                  }
                });
              },
              child: Text(
                _selectedIndices.length == _courseContents.length
                    ? 'Unselect'
                    : 'All',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _handleBulkCopyCut(false),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: _handleBulkDelete,
          ),
        ],
        elevation: 2,
      );
    }
    return AppBar(
      title: const Text(
        'Add Course',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      elevation: 0,
      actions: [
        if (_currentStep == 2) // Content Step (Index shifted)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: InkWell(
                onTap: _showAddContentMenu,
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavButtons() {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: ElevatedButton(
                onPressed: _prevStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Back',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 24),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep == 3
                  ? (_isLoading ? null : _submitCourse)
                  : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.0),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _currentStep == 3 ? 'Create Course' : 'Next Step',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEPS REWRITTEN ---

  Widget _buildStep1Basic() {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: 0,
            isSelectionMode: false,
            isDragMode: false,
          ),
          pinned: true, 
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: _screenPadding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Create New Course',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _labelFontSize + 2, // Slightly larger than section labels
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _clearBasicDraft,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text(
                        'Clear Draft',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                      ),
                    ),
                  ],
                ),
                Visibility(
                  visible: _hasContent,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Container(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3.0),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.05),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Safe & Synced',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: _s1HeaderSpace),
                // 1. Image
                Text(
                  'Course Cover (16:9 Size)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: _labelFontSize),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickImage,
                  child: AspectRatio(
                    aspectRatio: 16 / 9, // 16:9 Ratio
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(_globalRadius),
                        border: Border.all(
                          color: _thumbnailImage == null
                              ? (_thumbnailError
                                  ? Colors.red.withOpacity(0.8)
                                  : Theme.of(
                                      context,
                                    ).dividerColor.withOpacity(_borderOpacity))
                              : AppTheme.primaryColor.withOpacity(0.5),
                          width: (_thumbnailImage == null && _thumbnailError) ? 2 : (_thumbnailImage == null ? 1 : 2),
                          style: BorderStyle.solid,
                        ),
                        boxShadow: _thumbnailImage == null
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                        image: _thumbnailImage != null
                            ? DecorationImage(
                                image: FileImage(_thumbnailImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _thumbnailImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 48,
                                  color: AppTheme.primaryColor.withOpacity(0.8),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Select 16:9 Image',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
                SizedBox(height: _s1ImageSpace),

                // 2. Title
                _buildTextField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  label: 'Course Title',
                  hint: 'Advanced Mobile Repairing',
                  icon: Icons.title,
                  maxLength: 40, // Updated to 40 characters
                  hasError: _titleError,
                ),

                // 3. Description
                _buildTextField(
                  controller: _descController,
                  focusNode: _descFocus,
                  label: 'Description',
                  hint: 'Explain what students will learn...',
                  maxLines: 5,
                  alignTop: true,
                  hasError: _descError,
                ),


                // 5. Category & Type
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        initialValue: _selectedCategory,
                        hint: Text(
                          'Select Category',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: _inputVerticalPadding,
                            horizontal: 16,
                          ),
                          labelText: 'Category',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                            borderSide: BorderSide(
                              color: _categoryError
                                  ? Colors.red
                                  : Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: _borderOpacity),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                          ),
                          filled: true,
                          fillColor: AppTheme.primaryColor.withValues(
                            alpha: _fillOpacity,
                          ),
                        ),
                        items: _categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            if (_selectedCategory == v) {
                              _selectedCategory = null;
                            } else {
                              _selectedCategory = v;
                            }
                          });
                          unawaited(_saveCourseDraft());
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        initialValue: _difficulty,
                        hint: Text(
                          'Select Type',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: _inputVerticalPadding,
                            horizontal: 16,
                          ),
                          labelText: 'Course Type',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                            borderSide: BorderSide(
                              color: _difficultyError
                                  ? Colors.red
                                  : Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: _borderOpacity),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                          ),
                          filled: true,
                          fillColor: AppTheme.primaryColor.withValues(
                            alpha: _fillOpacity,
                          ),
                        ),
                        items: _difficultyLevels
                            .map(
                              (l) => DropdownMenuItem(
                                value: l,
                                child: Text(l, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            if (_difficulty == v) {
                              _difficulty = null;
                            } else {
                              _difficulty = v;
                            }
                          });
                          unawaited(_saveCourseDraft());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<int>(
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  initialValue: _newBatchDurationDays,
                  hint: Text(
                    'Select Duration',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      vertical: _inputVerticalPadding,
                      horizontal: 16,
                    ),
                    labelText: 'New Badge Duration',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_globalRadius),
                      borderSide: BorderSide(
                        color: _batchDurationError
                            ? Colors.red
                            : Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: _borderOpacity),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_globalRadius),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_globalRadius),
                    ),
                    filled: true,
                    fillColor: AppTheme.primaryColor.withValues(
                      alpha: _fillOpacity,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('1 Month')),
                    DropdownMenuItem(value: 60, child: Text('2 Months')),
                    DropdownMenuItem(value: 90, child: Text('3 Months')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      if (_newBatchDurationDays == v) {
                        _newBatchDurationDays = null;
                      } else {
                        _newBatchDurationDays = v;
                      }
                    });
                    unawaited(_saveCourseDraft());
                  },
                ),

                const SizedBox(height: 20),

                // 6. Highlights Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Highlights',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addHighlight,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_highlightControllers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      _highlightsError ? 'Please add at least one highlight *' : 'No highlights added.',
                      style: TextStyle(
                        color: _highlightsError ? Colors.red : Colors.grey,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        fontWeight: _highlightsError ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  )
                else
                  ..._highlightControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    return Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 20,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: controller,
                            label: 'Highlight',
                            hint: 'Practical Chip Level Training',
                            onChanged: (_) => unawaited(_saveCourseDraft()),
                            hasError: _highlightsError && controller.text.trim().isEmpty,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 20,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => _removeHighlight(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    );
                  }),

                // 7. FAQs Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FAQs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addFAQ,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (_faqControllers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      _faqsError ? 'Please add at least one FAQ *' : 'No FAQs added.',
                      style: TextStyle(
                        color: _faqsError ? Colors.red : Colors.grey,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        fontWeight: _faqsError ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  )
                else
                  ..._faqControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final faq = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: _borderOpacity),
                        ),
                        borderRadius: BorderRadius.circular(_globalRadius),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: faq['q'] as TextEditingController,
                                  label: 'Question',
                                  hint: 'e.g. Who can join this course?',
                                  hasError: _faqsError && (faq['q']?.text.trim().isEmpty ?? true),
                                  onChanged: (_) =>
                                      unawaited(_saveCourseDraft()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () => _removeFAQ(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),
                          // Removed SizedBox(height: 12) as Question field has 20px padding
                          _buildTextField(
                            controller: faq['a'] as TextEditingController,
                            label: 'Answer',
                            hint: 'Anyone with basic mobile knowledge...',
                            bottomPadding: 0.0,
                            hasError: _faqsError && (faq['a']?.text.trim().isEmpty ?? true),
                            onChanged: (_) => unawaited(_saveCourseDraft()),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildNavButtons(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  // Helper to get all videos from contents recursively
  List<Map<String, dynamic>> _getAllVideosFromContents(List<dynamic> items) {
    final List<Map<String, dynamic>> videos = [];
    for (var item in items) {
      if (item['type'] == 'video') {
        videos.add(Map<String, dynamic>.from(item));
      } else if (item['type'] == 'folder' && item['contents'] != null) {
        // Changed 'children' to 'contents' based on existing code
        videos.addAll(_getAllVideosFromContents(item['contents']));
      }
    }
    return videos;
  }

  // Helper to count items of a specific type recursively
  int _countItemsRecursively(List<dynamic> items, String type) {
    int count = 0;
    for (var item in items) {
      if (item['type'] == type) {
        count++;
      } else if (item['type'] == 'folder' && item['contents'] != null) {
        count += _countItemsRecursively(item['contents'], type);
      }
    }
    return count;
  }





  // MARK: - Bulk Selection Helpers
  void _enterSelectionMode(int index) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedIndices.clear();
      _selectedIndices.add(index);
    });
  }

  void _toggleSelection(int index) {
    if (!_isSelectionMode) return;
    HapticFeedback.heavyImpact();
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        // Removed auto-close logic: if (_selectedIndices.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _handleBulkDelete() {
    if (_selectedIndices.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Items?'),
        content: Text(
          'Are you sure you want to delete ${_selectedIndices.length} items?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final List<int> indices = _selectedIndices.toList()
                ..sort((a, b) => b.compareTo(a));
              setState(() {
                for (int i in indices) {
                  if (i < _courseContents.length) {
                    final item = _courseContents[i];
                    final path = item['path'];
                    if (path != null && path.contains('/cache/')) {
                      try {
                        final file = File(path);
                        if (file.existsSync()) file.deleteSync();
                      } catch (_) {}
                    }
                    _courseContents.removeAt(i);
                  }
                }
                _isSelectionMode = false;
                _selectedIndices.clear();
              });
              _saveCourseDraft();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleBulkCopyCut(bool isCut) {
    if (_selectedIndices.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCut ? 'Cut Items?' : 'Copy Items?'),
        content: Text(
          '${isCut ? 'Cut' : 'Copy'} ${_selectedIndices.length} items to clipboard?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _performCopyCut(isCut);
              Navigator.pop(context);
            },
            child: Text(isCut ? 'Cut' : 'Copy'),
          ),
        ],
      ),
    );
  }

  void _performCopyCut(bool isCut) {
    final List<int> indices = _selectedIndices.toList()
      ..sort((a, b) => a.compareTo(b));
    final List<Map<String, dynamic>> itemsToCopy = [];
    for (int i in indices) {
      if (i < _courseContents.length) itemsToCopy.add(_courseContents[i]);
    }

    setState(() {
      if (isCut) {
        ContentClipboard.cut(itemsToCopy);
        final List<int> revIndices = indices.reversed.toList();
        for (int i in revIndices) {
          _courseContents.removeAt(i);
        }
        _isSelectionMode = false;
        _selectedIndices.clear();
      } else {
        ContentClipboard.copy(itemsToCopy);
        _isSelectionMode = false;
        _selectedIndices.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${itemsToCopy.length} items ${isCut ? 'Cut' : 'Copied'}',
        ),
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _courseContents.removeAt(oldIndex);
      _courseContents.insert(newIndex, item);
    });
  }

  Widget _buildStep2Content() {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: 2,
            isSelectionMode: _isSelectionMode,
            isDragMode: _isDragModeActive,
          ),
          pinned: true, 
        ),

        // Dynamic helper to ensure FAB scrolls with content and doesn't block header
        // Removed plus button from body

        SliverPadding(
          key: const ValueKey('step2_content_padding'),
          padding: EdgeInsets.symmetric(horizontal: _screenPadding),
          sliver: _isInitialLoading
                  ? SliverToBoxAdapter(child: _buildShimmerList())
                  : _courseContents.isEmpty
                  ? SliverToBoxAdapter(
                      key: const ValueKey('add_course_empty_state'),
                      child: Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _courseContentError 
                                ? 'Add at least one content to proceed *' 
                                : 'No content added yet',
                              style: TextStyle(
                                color: _courseContentError ? Colors.red : Colors.grey.shade400,
                                fontWeight: _courseContentError ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverReorderableList(
                      key: const ValueKey('course_content_reorderable_list'),
                      itemCount: _courseContents.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final item = _courseContents[index];
                        final isSelected = _selectedIndices.contains(index);

                        return CourseContentListItem(
                          key: ObjectKey(item),
                          item: item,
                          index: index,
                          isSelected: isSelected,
                          isSelectionMode: _isSelectionMode,
                          isDragMode: _isDragModeActive,
                          leftOffset: _contentItemLeftOffset,
                          videoThumbTop: _videoThumbTop,
                          videoThumbBottom: _videoThumbBottom,
                          imageThumbTop: _imageThumbTop,
                          imageThumbBottom: _imageThumbBottom,
                          bottomSpacing: _itemBottomSpacing,
                          menuOffset: _menuOffset,
                          lockLeftOffset: _lockLeftOffset,
                          lockTopOffset: _lockTopOffset,
                          lockSize: _lockSize,
                          videoLabelOffset: _videoLabelOffset,
                          imageLabelOffset: _imageLabelOffset,
                          pdfLabelOffset: _pdfLabelOffset,
                          folderLabelOffset: _folderLabelOffset,
                          tagLabelFontSize: _tagLabelFontSize,
                          menuPanelOffsetDX: _menuPanelDX,
                          menuPanelOffsetDY: _menuPanelDY,
                          menuPanelWidth: _menuPanelWidth,
                          menuPanelHeight: _menuPanelHeight,
                          onTap: () => _handleContentTap(item, index),
                          onToggleSelection: () => _toggleSelection(index),
                          onEnterSelectionMode: () =>
                              _enterSelectionMode(index),
                          onStartHold: _startHoldTimer,
                          onCancelHold: _cancelHoldTimer,
                          onRename: () => _renameContent(index), 
                          onToggleLock: () { 
                            setState(() { 
                              _courseContents[index]['isLocked'] = !(_courseContents[index]['isLocked'] ?? true); 
                            }); 
                            _saveCourseDraft(); 
                          },
                          onRemove: () => _confirmRemoveContent(index),
                          onAddThumbnail: () =>
                              _showThumbnailManagerDialog(index),
                        );
                      },
                    ),
            ),

            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildNavButtons(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  void _handleContentTap(Map<String, dynamic> item, int index) async {
    if (_isSelectionMode) {
      _toggleSelection(index);
      return;
    }

    final String path = item['path'] ?? '';
    final String type = item['type'];

    if (type == 'folder') {
      // Pass data back from subfolder to update main draft
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FolderDetailScreen(
            folderName: item['name'],
            contentList:
                (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [],
          ),
        ),
      );

      if (result != null && result is List<Map<String, dynamic>>) {
        setState(() {
          _courseContents[index]['contents'] = result;
        });
        unawaited(_saveCourseDraft());
      }
    } else if (type == 'image') {
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ImageViewerScreen(filePath: path, title: item['name']),
          ),
        ),
      );
    } else if (type == 'video') {
      final videoList = _courseContents
          .where((element) => element['type'] == 'video')
          .map((v) {
            // Ensure thumbnail data is passed to playlist
            final map = Map<String, dynamic>.from(v);
            map['thumbnail'] = v['thumbnail'];
            return map;
          }).toList();
      final initialIndex = _courseContents
          .where((element) => element['type'] == 'video')
          .toList()
          .indexOf(item);
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              playlist: videoList,
              initialIndex: initialIndex >= 0 ? initialIndex : 0,
            ),
          ),
        ),
      );
    } else if (type == 'pdf') {
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PDFViewerScreen(filePath: path, title: item['name']),
          ),
        ),
      );
    }
  }

  void _renameContent(int index) {
    final TextEditingController renameController = TextEditingController(
      text: _courseContents[index]['name'],
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Content'),
        content: TextField(
          controller: renameController,
          autofocus: true,
          maxLength: 40, // Limited to 40 characters
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            counterText: "", // Hide counter for cleaner UI
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (renameController.text.trim().isNotEmpty) {
                setState(() {
                  _courseContents[index]['name'] = renameController.text.trim();
                });

                _saveCourseDraft();
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveContent(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Content'),
        content: Text(
          'Are you sure you want to remove "${_courseContents[index]['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Free up cache space
              final item = _courseContents[index];
              final path = item['path'];
              if (path != null && path.contains('/cache/')) {
                try {
                  final file = File(path);
                  if (file.existsSync()) file.deleteSync();
                } catch (_) {}
              }

              setState(() {
                _courseContents.removeAt(index);

              });
              _saveCourseDraft();
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showThumbnailManagerDialog(int index) {
    String? errorMessage;
    bool isProcessing = false;
    // Local state for the dialog
    String? currentThumbnail = _courseContents[index]['thumbnail'];

    showDialog(
      context: context,
      barrierDismissible: false, // Force user to choose Save or Close
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool hasThumbnail = currentThumbnail != null;

            Future<void> pickAndValidate() async {
              // ZERO CACHE: Use custom explorer
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SimpleFileExplorer(
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                  ),
                ),
              );

              if (result != null && result is List && result.isNotEmpty) {
                setDialogState(() => isProcessing = true);
                final String filePath = result.first as String;

                try {
                  final File file = File(filePath);
                  final decodedImage = await decodeImageFromList(
                    file.readAsBytesSync(),
                  );

                  final double ratio = decodedImage.width / decodedImage.height;
                  // 16:9 is approx 1.77. Allow 1.7 to 1.85
                  if (ratio < 1.7 || ratio > 1.85) {
                    setDialogState(() {
                      errorMessage =
                          "Invalid Ratio: ${ratio.toStringAsFixed(2)}\n\n"
                          "Required: 16:9 (YouTube Standard)\n"
                          "Please crop your image to 1920x1080.";
                      isProcessing = false;
                    });
                    return;
                  }

                  // Valid - Update LOCAL Dialog State only
                  setDialogState(() {
                    currentThumbnail = filePath;
                    errorMessage = null;
                    isProcessing = false;
                  });
                } catch (e) {
                  setDialogState(() {
                    errorMessage = "Error processing image: $e";
                    isProcessing = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Manage Thumbnail'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3.0),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (hasThumbnail)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3.0),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.file(
                              File(currentThumbnail!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Center(child: Icon(Icons.broken_image)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  else
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3.0),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          style: BorderStyle.solid,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No Thumbnail',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                  if (isProcessing)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: pickAndValidate,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: Text(hasThumbnail ? 'Change' : 'Add Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (hasThumbnail)
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() => currentThumbnail = null);
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // SAVE ACTION
                    setState(() {
                      _courseContents[index]['thumbnail'] = currentThumbnail;
                    });
                    _saveCourseDraft();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thumbnail Saved!')),
                    );
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _pasteContent() {
    if (ContentClipboard.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
      }
      return;
    }

    final List<Map<String, dynamic>> itemsToPaste = [];
    final List<String> skippedNames = [];
    final Set<String> existingNames = _courseContents.map((e) => e['name'].toString()).toSet();

    for (var item in ContentClipboard.items!) {
      if (existingNames.contains(item['name'])) {
        skippedNames.add(item['name']);
      } else {
        itemsToPaste.add(Map<String, dynamic>.from(jsonDecode(jsonEncode(item))));
      }
    }

    if (itemsToPaste.isEmpty && skippedNames.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conflict: "${skippedNames.join(', ')}" already exists in this root.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    setState(() {
      for (var newItem in itemsToPaste) {
        newItem['isLocal'] = true;
        _courseContents.insert(0, newItem);
      }
      
      if (ContentClipboard.action == 'cut') {
        ContentClipboard.clear();
      }
    });

    if (skippedNames.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pasted ${itemsToPaste.length} items. Skipped ${skippedNames.length} duplicates.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
    _saveCourseDraft();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ContentClipboard.items!.length} items pasted'),
        ),
      );
    }
  }

  void _showAddContentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3.0)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add to Course',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildOptionItem(
                    Icons.create_new_folder,
                    'Folder',
                    Colors.orange,
                    () => _showCreateFolderDialog(),
                  ),
                  _buildOptionItem(
                    Icons.video_library,
                    'Video',
                    Colors.red,
                    () => _pickContentFile('video', ['mp4', 'mkv', 'avi']),
                  ),
                  _buildOptionItem(
                    Icons.picture_as_pdf,
                    'PDF',
                    Colors.redAccent,
                    () => _pickContentFile('pdf', ['pdf']),
                  ),
                  _buildOptionItem(
                    Icons.image,
                    'Image',
                    Colors.purple,
                    () => _pickContentFile('image', [
                      'jpg',
                      'jpeg',
                      'png',
                      'webp',
                    ]),
                  ),
                  
                  _buildOptionItem(
                    Icons.content_paste,
                    'Paste',
                    Colors.grey,
                    _pasteContent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    final folderNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
        title: const Text('New Folder'),
        content: TextField(
          controller: folderNameController,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: 'Folder Name',
            counterText: "",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(3.0)),
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (folderNameController.text.trim().isNotEmpty) {
                setState(() {
                  _courseContents.insert(0, {
                    'type': 'folder',
                    'name': folderNameController.text.trim(),
                    'contents': <Map<String, dynamic>>[],
                    'isLocal': true,
                    'isLocked': true,
                  });
                });
                _saveCourseDraft();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3.0),
              ),
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickContentFile(
    String type, [
    List<String>? allowedExtensions,
  ]) async {
    // ZERO CACHE: Use custom explorer for ALL types
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SimpleFileExplorer(allowedExtensions: allowedExtensions ?? []),
      ),
    );

    if (result != null && result is List) {
      final List<String> paths = result.cast<String>();
      if (paths.isEmpty) return;

      final List<Map<String, dynamic>> newItems = [];
      for (var path in paths) {
        String name = path.split('/').last;
        if (name.length > 40) {
          final extensionIndex = name.lastIndexOf('.');
          if (extensionIndex != -1 && name.length - extensionIndex < 10) {
            // Keep extension if possible
            final ext = name.substring(extensionIndex);
            name = name.substring(0, 40 - ext.length) + ext;
          } else {
            name = name.substring(0, 40);
          }
        }
        newItems.add({
          'type': type,
          'name': name,
          'path': path,
          'isLocal': true,
          'isLocked': true,
          'thumbnail': null,
        });
      }

      setState(() {
        _courseContents.insertAll(0, newItems);
      });

      // Only process video if needed (currently disabled)
      if (type == 'video') {
        unawaited(_processVideos(newItems));
      } else {
        unawaited(_saveCourseDraft());
      }
    }
  }

  Future<void> _processVideos(List<Map<String, dynamic>> items) async {
    // DISABLED: Thumbnail Generation to prevent cache bloat
    unawaited(_saveCourseDraft());
  }

  Widget _buildStep1_5Setup() {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: 1,
            isSelectionMode: false,
            isDragMode: false,
          ),
          pinned: true, 
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: _screenPadding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Course Setup',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _labelFontSize + 2,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _clearSetupDraft,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text(
                        'Clear Draft',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                      ),
                    ),
                  ],
                ),
                Visibility(
                  visible: _hasSetupContent,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3.0),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isSavingDraft
                            ? const SizedBox(
                                height: 12,
                                width: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green,
                              ),
                        const SizedBox(width: 8),
                        Text(
                          _isSavingDraft ? 'Syncing...' : 'Safe & Synced',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: _s2HeaderSpace),
                SizedBox(height: _s2PricingSpace),
                // 1. Pricing
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _mrpController,
                        focusNode: _mrpFocus,
                        label: 'MRP',
                        hint: '5000',
                        keyboardType: TextInputType.number,
                        hasError: _mrpError,
                        verticalPadding: 7,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(
                        controller: _discountAmountController,
                        focusNode: _discountFocus,
                        label: 'Discount',
                        hint: '1000',
                        keyboardType: TextInputType.number,
                        hasError: _discountError,
                        verticalPadding: 7,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(
                        controller: _finalPriceController,
                        label: 'Final',
                        hint: '0',
                        keyboardType: TextInputType.number,
                        readOnly: true,
                        verticalPadding: 7,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _s2LanguageSpace),

                // 2. Language & Support
                DropdownButtonFormField<String>(
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  value: _selectedLanguage,
                  hint: Text(
                    'Select Language',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      vertical: _inputVerticalPadding, 
                      horizontal: 16
                    ),
                    labelText: 'Course Language',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: const Icon(Icons.language, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_globalRadius),
                      borderSide: BorderSide(color: _languageError ? Colors.red : Theme.of(context).dividerColor.withValues(alpha: _borderOpacity)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_globalRadius),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(_globalRadius)),
                    filled: true,
                    fillColor: AppTheme.primaryColor.withValues(alpha: _fillOpacity),
                  ),
                  items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (v) {
                    setState(() {
                      if (_selectedLanguage == v) {
                        _selectedLanguage = null;
                      } else {
                        _selectedLanguage = v;
                        _languageError = false;
                      }
                    });
                    unawaited(_saveCourseDraft());
                  },
                ),
                SizedBox(height: _tightVerticalMode ? 0 : 16),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        value: _selectedCourseMode,
                        hint: Text(
                          'Select Mode',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: _inputVerticalPadding, 
                            horizontal: 16
                          ),
                          labelText: 'Course Mode',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                            borderSide: BorderSide(color: _courseModeError ? Colors.red : Theme.of(context).dividerColor.withValues(alpha: _borderOpacity)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(_globalRadius)),
                          filled: true,
                          fillColor: AppTheme.primaryColor.withValues(alpha: _fillOpacity),
                        ),
                        items: _courseModes.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) {
                          setState(() {
                            if (_selectedCourseMode == v) {
                              _selectedCourseMode = null;
                            } else {
                              _selectedCourseMode = v;
                              _courseModeError = false;
                            }
                          });
                          unawaited(_saveCourseDraft());
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        value: _selectedSupportType,
                        hint: Text(
                          'Select Type',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: _inputVerticalPadding, 
                            horizontal: 16
                          ),
                          labelText: 'Support Type',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                            borderSide: BorderSide(color: _supportTypeError ? Colors.red : Theme.of(context).dividerColor.withValues(alpha: _borderOpacity)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(_globalRadius)),
                          filled: true,
                          fillColor: AppTheme.primaryColor.withValues(alpha: _fillOpacity),
                        ),
                        items: _supportTypes.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) {
                          setState(() {
                            if (_selectedSupportType == v) {
                              _selectedSupportType = null;
                            } else {
                              _selectedSupportType = v;
                              _supportTypeError = false;
                            }
                          });
                          unawaited(_saveCourseDraft());
                        },
                      ),
                    ),
                  ],
                ),
                if (_selectedSupportType == 'WhatsApp Group') ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _whatsappController,
                    label: 'Support WP Group Link',
                    hint: 'Paste WhatsApp Group Invite Link',
                    icon: Icons.link,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => unawaited(_saveCourseDraft()),
                    hasError: _wpGroupLinkError,
                  ),
                ],
                SizedBox(height: _s2ValiditySpace),

                // 3. Validity & Certificate
                _buildValiditySelector(),
                const SizedBox(height: 24),
                _buildCertificateSettings(),
                SizedBox(height: _certToBigScreenSpace),

                // 4. PC/Web Support
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Watch on Big Screens',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Allow access via Web/Desktop',
                  ),
                  value: _isBigScreenEnabled,
                  onChanged: (v) {
                    setState(() => _isBigScreenEnabled = v);
                    unawaited(_saveCourseDraft());
                  },
                  activeThumbColor: AppTheme.primaryColor,
                ),
                if (_isBigScreenEnabled) ...[
                  SizedBox(height: _tightVerticalMode ? 0 : 12),
                  _buildTextField(
                    controller: _websiteUrlController,
                    label: 'Website Login URL',
                    hint: 'https://yourwebsite.com/login',
                    icon: Icons.language,
                    onChanged: (_) => unawaited(_saveCourseDraft()),
                    hasError: _bigScreenUrlError,
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildNavButtons(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildValiditySelector() {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      value: _courseValidityDays,
      hint: const Text('Select Validity'),
      decoration: InputDecoration(
        labelText: 'Course Validity',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: const Icon(Icons.history_toggle_off),
        contentPadding: EdgeInsets.symmetric(
          vertical: _inputVerticalPadding,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_globalRadius),
          borderSide: BorderSide(
            color: _validityError ? Colors.red : Theme.of(context).dividerColor.withValues(alpha: _borderOpacity),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_globalRadius),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_globalRadius),
        ),
        filled: true,
        fillColor: AppTheme.primaryColor.withValues(alpha: _fillOpacity),
      ),
      items: const [
        DropdownMenuItem(value: 0, child: Text('Lifetime Access')),
        DropdownMenuItem(value: 184, child: Text('6 Months')),
        DropdownMenuItem(value: 365, child: Text('1 Year')),
        DropdownMenuItem(value: 730, child: Text('2 Years')),
        DropdownMenuItem(value: 1095, child: Text('3 Years')),
      ],
      onChanged: (v) {
        setState(() {
          if (_courseValidityDays == v) {
            _courseValidityDays = null;
          } else {
            _courseValidityDays = v;
            _validityError = false;
          }
        });
        unawaited(_saveCourseDraft());
      },
    );
  }

  Widget _buildCertificateSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Enable Certificate',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            _hasCertificate
                ? 'Certificate will be issued on completion'
                : 'No certificate for this course',
          ),
          value: _hasCertificate,
          onChanged: (v) {
            setState(() => _hasCertificate = v);
            unawaited(_saveCourseDraft());
          },
          activeThumbColor: AppTheme.primaryColor,
        ),
        if (_hasCertificate) ...[
          const SizedBox(height: 24),
          const Text(
            'Upload Two Certificate Designs',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Strictly 3508 x 2480 Pixels (A4 Landscape)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Design A',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedCertSlot == 1
                            ? AppTheme.primaryColor
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        _buildImageUploader(
                          image: _certificate1Image,
                          onTap: () => _pickCertificateImage(1),
                          label: 'Box 1',
                          icon: Icons.upload_file,
                          aspectRatio: 1.414,
                        ),
                        if (_selectedCertSlot == 1)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _selectedCertSlot = 1);
                              unawaited(_saveCourseDraft());
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 0),
                              backgroundColor: _selectedCertSlot == 1
                                  ? AppTheme.primaryColor
                                  : Theme.of(context).cardColor,
                            ),
                            child: Text(
                              'Select',
                              style: TextStyle(
                                fontSize: 10,
                                color: _selectedCertSlot == 1
                                    ? Colors.white
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Design B',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedCertSlot == 2
                            ? AppTheme.primaryColor
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        _buildImageUploader(
                          image: _certificate2Image,
                          onTap: () => _pickCertificateImage(2),
                          label: 'Box 2',
                          icon: Icons.upload_file,
                          aspectRatio: 1.414,
                        ),
                        if (_selectedCertSlot == 2)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _selectedCertSlot = 2);
                              unawaited(_saveCourseDraft());
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 0),
                              backgroundColor: _selectedCertSlot == 2
                                  ? AppTheme.primaryColor
                                  : Theme.of(context).cardColor,
                            ),
                            child: Text(
                              'Select',
                              style: TextStyle(
                                fontSize: 10,
                                color: _selectedCertSlot == 2
                                    ? Colors.white
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStep3Advance() {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: 3,
            isSelectionMode: false,
            isDragMode: false,
          ),
          pinned: true,
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: _screenPadding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Review Card
                _buildCourseReviewCard(),
                const SizedBox(height: 32),

                // 4.5 Special Badge/Tag
                const Text(
                  'Special Course Badge (Tag)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _specialTagController,
                  label: 'Badge Text',
                  hint: 'e.g. Special Offer, Best Seller',
                  icon: Icons.local_offer,
                  maxLength: 20,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    'Special Offer',
                    'Best Seller',
                    'Trending',
                    'Limited Seats',
                  ].map((tag) {
                    return ActionChip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _specialTagController.text = tag;
                        _saveCourseDraft();
                      },
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.05),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // 5. Offline Download Toggle
                const Text(
                  'Distribution Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'Offline Downloads',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Allow students to download videos inside the app',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isOfflineDownloadEnabled,
                  onChanged: (v) {
                    setState(() => _isOfflineDownloadEnabled = v);
                    unawaited(_saveCourseDraft());
                  },
                  activeThumbColor: AppTheme.primaryColor,
                  tileColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_globalRadius),
                    side: BorderSide(
                      color: Colors.grey.withOpacity(_borderOpacity),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 6. Publish Status
                const Text(
                  'Publish Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(
                    _isPublished
                        ? 'Course is Public'
                        : 'Course is Hidden (Draft)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _isPublished
                        ? 'Visible to all students on the app'
                        : 'Only visible to admins',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _isPublished,
                  onChanged: (v) {
                    setState(() => _isPublished = v);
                    unawaited(_saveCourseDraft());
                  },
                  activeThumbColor: Colors.green,
                  tileColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_globalRadius),
                    side: BorderSide(
                      color: _isPublished
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey.withOpacity(_borderOpacity),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildNavButtons(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploader({
    File? image,
    required VoidCallback onTap,
    required String label,
    required IconData icon,
    double aspectRatio = 16 / 9,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_globalRadius),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(_borderOpacity),
              style: BorderStyle.solid,
            ),
            image: image != null
                ? DecorationImage(image: FileImage(image), fit: BoxFit.contain)
                : null,
          ),
          child: image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.grey, size: 30),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _pickCertificateImage(int slot) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final File file = File(pickedFile.path);

      // Validation for Custom Certificate Size
      final decodedImage = await decodeImageFromList(file.readAsBytesSync());
      if (decodedImage.width != 3508 || decodedImage.height != 2480) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: Image must be 3508x2480 px. Current: ${decodedImage.width}x${decodedImage.height}',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      setState(() {
        if (slot == 1) {
          _certificate1Image = file;
          _selectedCertSlot = 1; // Auto select if uploaded
        } else if (slot == 2) {
          _certificate2Image = file;
          _selectedCertSlot = 2; // Auto select if uploaded
        }
      });
      unawaited(_saveCourseDraft());
    }
  }

  // Helper
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon, // Optional now
    TextInputType keyboardType = TextInputType.text,
    int? maxLines = 1,
    int? maxLength,
    bool readOnly = false,
    bool alignTop = false,
    void Function(String)? onChanged,
    FocusNode? focusNode,
    double bottomPadding = 20.0,
    bool hasError = false,
    double? verticalPadding,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: _tightVerticalMode ? 0 : bottomPadding),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        readOnly: readOnly,
        onChanged: onChanged,
        textAlignVertical: alignTop
            ? TextAlignVertical.top
            : TextAlignVertical.center,
        style: TextStyle(
          color: Colors.white,
          fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          alignLabelWithHint: alignTop,
          prefixIcon: icon != null
              ? (alignTop
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Icon(icon, color: Colors.grey),
                          ),
                        ],
                      )
                    : Icon(icon, color: Colors.grey))
              : null,
          contentPadding: EdgeInsets.symmetric(
            vertical: verticalPadding ?? _inputVerticalPadding,
            horizontal: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_globalRadius),
            borderSide: BorderSide(
              color: hasError
                  ? Colors.red
                  : Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: _borderOpacity),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_globalRadius),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_globalRadius),
          ),
          filled: true,
          fillColor: AppTheme.primaryColor.withValues(alpha: _fillOpacity),
          counterText: maxLength != null ? null : '',
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: List.generate(
          5,
          (index) => Shimmer.fromColors(
            baseColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]!
                : Colors.grey[300]!,
            highlightColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]!
                : Colors.grey[100]!,
            child: Container(
              height: 70,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(3.0),
              ),
            ),
          ),
        ),
      ),
    );
  }


}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});
  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

