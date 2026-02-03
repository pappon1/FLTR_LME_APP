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
  final List<String> _languages = ['Hindi', 'English', 'Hinglish', 'Bengali', 'Marathi', 'Gujarati', 'Tamil', 'Kannada', 'Telugu', 'Malayalam'];
  final List<String> _courseModes = ['Recorded', 'Live Session'];
  final List<String> _supportTypes = ['WhatsApp Group', 'No Support'];

  String _selectedLanguage = 'Hindi';
  String _selectedCourseMode = 'Recorded';
  String _selectedSupportType = 'WhatsApp Group';

  // Parallel Upload Progress State
  List<CourseUploadTask> _uploadTasks = [];
  bool _isUploading = false;
  double _totalProgress = 0.0;
  final String _uploadStatus = '';

  // Design State
  final double _globalRadius = 3.0;
  final double _inputVerticalPadding = 10.0;
  final double _borderOpacity = 0.12;
  final double _fillOpacity = 0.0;

  // Highlights & FAQs Controllers
  final List<TextEditingController> _highlightControllers = [];
  final List<Map<String, TextEditingController>> _faqControllers = [];

  // Validation & Focus
  bool _thumbnailError = false;
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
    _mrpController.addListener(() => _saveCourseDraft());
    _discountAmountController.addListener(() => _saveCourseDraft());
    _whatsappController.addListener(() => _saveCourseDraft());
    _websiteUrlController.addListener(() => _saveCourseDraft());

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
          _selectedLanguage = draft['language'] ?? 'Hindi';
          _selectedCourseMode = draft['courseMode'] ?? 'Recorded';
          _selectedSupportType = draft['supportType'] ?? 'WhatsApp Group';
          _whatsappController.text = draft['whatsappNumber'] ?? '';
          _isBigScreenEnabled = draft['isBigScreenEnabled'] ?? false;
          _websiteUrlController.text = draft['websiteUrl'] ?? '';

          if (draft['contents'] != null) {
            _courseContents.clear();
            _courseContents.addAll(
              List<Map<String, dynamic>>.from(draft['contents']),
            );
          }

          // _courseValidityDays = draft['validity']; // IGNORED: Force null by default as per user request
          // _courseValidityDays = draft['validity']; // IGNORED: Force null by default as per user request
          _courseValidityDays = null;
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
    if (_mrpController.text.trim().isEmpty) {
      _jumpToStep(1);
      _showWarning('Please enter MRP (Price) in Step 2');
      return false;
    }
    if (_courseValidityDays == null) {
      _jumpToStep(1);
      _showWarning('Please select Course Validity duration in Step 2');
      return false;
    }
    if (_courseValidityDays == -1 && _customValidityController.text.trim().isEmpty) {
      _jumpToStep(1);
      _showWarning('Please enter custom validity days in Step 2');
      return false;
    }
    if (_hasCertificate) {
      if (_certificate1Image == null && _certificate2Image == null) {
        _jumpToStep(1);
        _showWarning('Please upload at least one certificate design in Step 2');
        return false;
      }
    }
    return true;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
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
            Icons.payments_outlined,
            'Price',
            '₹${_finalPriceController.text}',
            () => _jumpToStep(0),
          ),
          _buildReviewItem(
            Icons.video_collection_outlined,
            'Content',
            '${_getAllVideosFromContents(_courseContents).length} Videos',
            () => _jumpToStep(1),
          ),
          _buildReviewItem(
            Icons.history_toggle_off,
            'Validity',
            _getValidityText(_courseValidityDays),
            null,
          ),
          _buildReviewItem(
            Icons.workspace_premium_outlined,
            'Certificate',
            _hasCertificate ? 'Enabled' : 'Disabled',
            null,
          ),
          _buildReviewItem(
            Icons.public,
            'Status',
            _isPublished ? 'Public' : 'Hidden',
            null,
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

    if (_currentStep < 3) {
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 50));
      await _pageController.nextPage(duration: 250.ms, curve: Curves.easeInOut);
    }
  }

  bool _validateStep0() {
    setState(() => _thumbnailError = false);

    if (_thumbnailImage == null) {
      setState(() => _thumbnailError = true);
      _showWarning('Please select a course cover image');
      return false;
    }
    if (_titleController.text.trim().isEmpty) {
      _titleFocus.requestFocus();
      _showWarning('Please enter a course title');
      return false;
    }
    if (_descController.text.trim().isEmpty) {
      _descFocus.requestFocus();
      _showWarning('Please enter a course description');
      return false;
    }
    if (_selectedCategory == null) {
      _showWarning('Please select a course category');
      return false;
    }
    if (_difficulty == null) {
      _showWarning('Please select a course type');
      return false;
    }
    if (_newBatchDurationDays == null) {
      _showWarning('Please select new badge duration');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content to the course')),
      );
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
        language: _selectedLanguage,
        courseMode: _selectedCourseMode,
        supportType: _selectedSupportType,
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
      _highlightControllers.add(TextEditingController());
    });
  }

  void _removeHighlight(int index) {
    if (index >= 0 && index < _highlightControllers.length) {
      setState(() {
        _highlightControllers[index].dispose();
        _highlightControllers.removeAt(index);
      });
      _saveCourseDraft();
    }
  }

  // --- FAQs Management ---
  void _addFAQ() {
    setState(() {
      _faqControllers.add({
        'q': TextEditingController(),
        'a': TextEditingController(),
      });
    });
  }

  void _removeFAQ(int index) {
    if (index >= 0 && index < _faqControllers.length) {
      setState(() {
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
                _mrpController.clear();
                _discountAmountController.clear();
                _finalPriceController.clear();
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
        top: 32,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep == 3
                  ? (_isLoading ? null : _submitCourse)
                  : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                        style: const TextStyle(color: Colors.white),
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create New Course',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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
                if (_isSavingDraft)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, child) => Transform.translate(
                      offset: Offset(0, (1 - value) * -10),
                      child: Opacity(
                        opacity: value,
                        child: Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 12),
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
                    ),
                  ),
                const SizedBox(height: 24),
                // 1. Image
                const Text(
                  'Course Cover (16:9 Size)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                const SizedBox(height: 24),

                // 2. Title
                _buildTextField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  label: 'Course Title',
                  hint: 'Advanced Mobile Repairing',
                  icon: Icons.title,
                  maxLength: 40, // Updated to 40 characters
                ),

                // 3. Description
                _buildTextField(
                  controller: _descController,
                  focusNode: _descFocus,
                  label: 'Description',
                  hint: 'Explain what students will learn...',
                  maxLines: 5,
                  alignTop: true,
                ),


                // 5. Category & Type
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedCategory,
                        hint: Text(
                          'Select Category',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.4),
                            fontSize: 13,
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
                              color: Theme.of(
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
                          setState(() => _selectedCategory = v);
                          unawaited(_saveCourseDraft());
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _difficulty,
                        hint: Text(
                          'Select Type',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.4),
                            fontSize: 13,
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
                              color: Theme.of(
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
                          setState(() => _difficulty = v);
                          unawaited(_saveCourseDraft());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
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
                        color: Theme.of(
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
                    setState(() => _newBatchDurationDays = v);
                    unawaited(_saveCourseDraft());
                  },
                ),

                const SizedBox(height: 32),

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
                  const Text(
                    'No highlights added.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  ..._highlightControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(
                              top: 0,
                            ), // Already centered by row
                            child: Icon(
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
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 16,
                            ), // Match _buildTextField's bottom padding
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
                      ),
                    );
                  }),

                const SizedBox(height: 32),

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
                const SizedBox(height: 8),
                if (_faqControllers.isEmpty)
                  const Text(
                    'No FAQs added.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  ..._faqControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final faq = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
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
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: faq['a'] as TextEditingController,
                            label: 'Answer',
                            hint: 'Anyone with basic mobile knowledge...',
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
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildNavButtons(),
            ),
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                              'No content added yet',
                              style: TextStyle(color: Colors.grey.shade400),
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
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildNavButtons(),
                ),
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
          .toList();
      final initialIndex = videoList.indexOf(item);
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
          decoration: InputDecoration(
            labelText: 'Folder Name',
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
        newItems.add({
          'type': type,
          'name': path.split('/').last,
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
          padding: const EdgeInsets.all(24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Pricing
                const Text(
                  'Pricing Setup',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _mrpController,
                        focusNode: _mrpFocus,
                        label: 'MRP',
                        hint: '5000',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        controller: _discountAmountController,
                        focusNode: _discountFocus,
                        label: 'Discount ₹',
                        hint: '1000',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _finalPriceController,
                        label: 'Final',
                        hint: 'Automatic',
                        keyboardType: TextInputType.number,
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // 2. Language & Support
                const Text(
                  'Language & Support',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguage,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: _inputVerticalPadding, horizontal: 16),
                    labelText: 'Course Language',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: const Icon(Icons.language, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_globalRadius),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: _borderOpacity)),
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
                    if (v != null) setState(() => _selectedLanguage = v);
                    unawaited(_saveCourseDraft());
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedCourseMode,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(vertical: _inputVerticalPadding, horizontal: 16),
                          labelText: 'Course Mode',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                            borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: _borderOpacity)),
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
                          if (v != null) setState(() => _selectedCourseMode = v);
                          unawaited(_saveCourseDraft());
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedSupportType,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(vertical: _inputVerticalPadding, horizontal: 16),
                          labelText: 'Support Type',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_globalRadius),
                            borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: _borderOpacity)),
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
                          if (v != null) setState(() => _selectedSupportType = v);
                          unawaited(_saveCourseDraft());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _whatsappController,
                  label: 'Support WhatsApp Number',
                  hint: 'e.g. 919876543210',
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => unawaited(_saveCourseDraft()),
                ),
                const SizedBox(height: 32),

                // 3. Validity & Certificate
                const Text(
                  'Validity & Certificate',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildValiditySelector(),
                const SizedBox(height: 24),
                _buildCertificateSettings(),
                const SizedBox(height: 32),

                // 4. PC/Web Support
                const Text(
                  'PC & Web Support',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _websiteUrlController,
                    label: 'Website Login URL',
                    hint: 'https://yourwebsite.com/login',
                    icon: Icons.language,
                    onChanged: (_) => unawaited(_saveCourseDraft()),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildNavButtons(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValiditySelector() {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: _courseValidityDays,
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
            color: Theme.of(context).dividerColor.withValues(alpha: _borderOpacity),
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
        setState(() => _courseValidityDays = v);
        unawaited(_saveCourseDraft());
      },
    );
  }

  Widget _buildCertificateSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Certification Management',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _hasCertificate
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3.0),
              ),
              child: Text(
                _hasCertificate ? 'ENABLED' : 'DISABLED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _hasCertificate ? Colors.green : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                            onPressed: () =>
                                setState(() => _selectedCertSlot = 1),
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
                            onPressed: () =>
                                setState(() => _selectedCertSlot = 2),
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Review Card
                _buildCourseReviewCard(),
                const SizedBox(height: 32),

                // 5. Publish Toggle
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

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildNavButtons(),
            ),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
          color: readOnly
              ? Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8)
              : Theme.of(context).textTheme.bodyMedium?.color,
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
            vertical: _inputVerticalPadding,
            horizontal: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_globalRadius),
            borderSide: BorderSide(
              color: Theme.of(
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

  // Concurrency Limited Queue Processor
  Future<void> _processQueue(
    List<Future<void> Function()> tasks, {
    int concurrent = 2,
  }) async {
    final queue = List.of(tasks);
    final active = <Future<void>>[];

    while (queue.isNotEmpty || active.isNotEmpty) {
      while (active.length < concurrent && queue.isNotEmpty) {
        final task = queue.removeAt(0);
        final future = task();
        active.add(future);
        future.then((_) => active.remove(future));
      }
      if (active.isEmpty) break;
      await Future.any(active); // Wait for at least one to finish
    }
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

