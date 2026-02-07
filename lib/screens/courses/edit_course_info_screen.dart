import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../../models/course_model.dart';
import '../../services/firestore_service.dart';
import '../../services/bunny_cdn_service.dart';
import 'package:path/path.dart' as path;
import '../../utils/app_theme.dart';
import '../utils/simple_file_explorer.dart';
import 'folder_detail_screen.dart';
import 'components/course_content_list_item.dart';
import 'components/collapsing_step_indicator.dart';
import '../content_viewers/image_viewer_screen.dart';
import '../content_viewers/video_player_screen.dart';
import '../content_viewers/pdf_viewer_screen.dart';
import '../../utils/clipboard_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:flutter_background_service/flutter_background_service.dart';

class EditCourseInfoScreen extends StatefulWidget {
  final CourseModel course;
  const EditCourseInfoScreen({super.key, required this.course});

  @override
  State<EditCourseInfoScreen> createState() => _EditCourseInfoScreenState();
}

class _EditCourseInfoScreenState extends State<EditCourseInfoScreen> {
  final _pageController = PageController();
  final _scrollController = ScrollController();
  final _bunnyService = BunnyCDNService();

  // Step Management
  int _currentStep = 0;

  // Controllers
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _mrpController;
  late TextEditingController _discountController;
  late TextEditingController _finalPriceController;
  late TextEditingController _customValidityController;
  late TextEditingController _whatsappController;
  late TextEditingController _websiteUrlController;

  // State Variables
  String? _selectedCategory;
  String? _difficulty;
  final List<String> _languages = [
    'Hindi',
    'English',
    'Hinglish',
    'Bengali',
    'Marathi',
    'Gujarati',
    'Tamil',
    'Kannada',
    'Telugu',
    'Malayalam',
  ];
  final List<String> _courseModes = ['Recorded', 'Live Session'];
  final List<String> _supportTypes = ['WhatsApp Group', 'No Support'];

  String _selectedLanguage = 'Hindi';
  String _selectedCourseMode = 'Recorded';
  String _selectedSupportType = 'WhatsApp Group';
  File? _thumbnailImage;
  String? _currentThumbnailUrl;
  bool _thumbnailChanged = false;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String _specialTagColor = 'Blue';
  bool _isSpecialTagVisible = true;
  int _specialTagDurationDays = 30;
  static const List<String> _tagColors = ['Blue', 'Red', 'Green', 'Pink'];
  int? _courseValidityDays;
  bool _hasCertificate = false;
  File? _certificate1Image;
  File? _certificate2Image;
  String? _currentCert1Url;
  String? _currentCert2Url;
  bool _cert1Changed = false;
  bool _cert2Changed = false;
  int _selectedCertSlot = 1;
  bool _isOfflineDownloadEnabled = true;
  bool _isBigScreenEnabled = false;
  bool _isPublished = false;

  // Contents Management (New Tab)
  List<Map<String, dynamic>> _courseContents = [];
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};
  bool _isDragModeActive = false;
  Timer? _holdTimer;

  // Highlights & FAQs
  final List<TextEditingController> _highlightControllers = [];
  final List<Map<String, TextEditingController>> _faqControllers = [];

  static const List<String> _difficultyLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];
  static const List<String> _categories = ['Hardware', 'Software'];

  // Focus Nodes
  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();
  final _mrpFocus = FocusNode();
  final _discountFocus = FocusNode();

  bool _thumbnailError = false;

  // Design State - Const for better performance
  static const double _globalRadius = 3.0;
  static const double _inputVerticalPadding = 10.0;
  static const double _borderOpacity = 0.12;
  static const double _fillOpacity = 0.0;

  // Cached BorderRadius to avoid repeated creation
  static final BorderRadius _globalBorderRadius = BorderRadius.circular(
    _globalRadius,
  );

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadCourseData();
  }

  void _initializeControllers() {
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _mrpController = TextEditingController();
    _discountController = TextEditingController();
    _finalPriceController = TextEditingController();
    _customValidityController = TextEditingController();
    _whatsappController = TextEditingController();
    _websiteUrlController = TextEditingController();

    _mrpController.addListener(_calculateFinalPrice);
    _discountController.addListener(_calculateFinalPrice);
  }

  void _calculateFinalPrice() {
    final double mrp = double.tryParse(_mrpController.text) ?? 0;
    final double discountAmt = double.tryParse(_discountController.text) ?? 0;

    if (mrp > 0) {
      double finalPrice = mrp - discountAmt;
      if (finalPrice < 0) finalPrice = 0;
      _finalPriceController.text = finalPrice.round().toString();
    } else {
      _finalPriceController.text = '0';
    }
  }

  Future<void> _loadCourseData() async {
    setState(() => _isInitialLoading = true);

    try {
      final course = widget.course;

      _titleController.text = course.title;
      _descController.text = course.description;
      _mrpController.text = course.price.toString();
      _discountController.text = (course.price - course.discountPrice)
          .toString();
      _selectedCategory = course.category;
      _difficulty = course.difficulty;
      _currentThumbnailUrl = course.thumbnailUrl;
      _specialTagColor = course.specialTagColor;
      _isSpecialTagVisible = course.isSpecialTagVisible;
      _specialTagDurationDays = course.specialTagDurationDays;
      _courseValidityDays = course.courseValidityDays;
      _hasCertificate = course.hasCertificate;
      _selectedCertSlot = course.selectedCertificateSlot;
      _isOfflineDownloadEnabled = course.isOfflineDownloadEnabled;
      _isPublished = course.isPublished;
      _selectedLanguage = course.language;
      _selectedCourseMode = course.courseMode;
      _selectedSupportType = course.supportType;
      _whatsappController.text = course.whatsappNumber;
      _isBigScreenEnabled = course.isBigScreenEnabled;
      _websiteUrlController.text = course.websiteUrl;

      // Load certificate URLs
      if (course.certificateUrl1 != null &&
          course.certificateUrl1!.isNotEmpty) {
        _currentCert1Url = course.certificateUrl1;
      }
      if (course.certificateUrl2 != null &&
          course.certificateUrl2!.isNotEmpty) {
        _currentCert2Url = course.certificateUrl2;
      }

      // Load Contents
      _courseContents = List<Map<String, dynamic>>.from(
        course.contents.map((x) => Map<String, dynamic>.from(x)),
      );

      // Load custom validity if needed
      if (_courseValidityDays != null &&
          _courseValidityDays != 0 &&
          _courseValidityDays != 184 &&
          _courseValidityDays != 365 &&
          _courseValidityDays != 730 &&
          _courseValidityDays != 1095) {
        _customValidityController.text = _courseValidityDays.toString();
        _courseValidityDays = -1; // Custom marker
      }

      // Load highlights
      if (course.highlights.isNotEmpty) {
        for (var h in course.highlights) {
          _highlightControllers.add(TextEditingController(text: h));
        }
      }

      // Load FAQs
      if (course.faqs.isNotEmpty) {
        for (var faq in course.faqs) {
          _faqControllers.add({
            'q': TextEditingController(text: faq['question'] ?? ''),
            'a': TextEditingController(text: faq['answer'] ?? ''),
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading course data: $e');
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _mrpController.dispose();
    _discountController.dispose();
    _finalPriceController.dispose();
    _customValidityController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    _whatsappController.dispose();
    _websiteUrlController.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    _mrpFocus.dispose();
    _discountFocus.dispose();

    // Cancel timer to prevent memory leaks
    _holdTimer?.cancel();

    for (var c in _highlightControllers) {
      c.dispose();
    }
    for (var f in _faqControllers) {
      f['q']?.dispose();
      f['a']?.dispose();
    }

    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final File file = File(pickedFile.path);
      final decodedImage = await decodeImageFromList(file.readAsBytesSync());

      // Validation: Check for 16:9 Ratio
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
        return;
      }

      setState(() {
        _thumbnailImage = file;
        _thumbnailChanged = true;
      });
    }
  }

  Future<void> _pickCertificate(int slot) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        if (slot == 1) {
          _certificate1Image = File(pickedFile.path);
          _cert1Changed = true;
        } else {
          _certificate2Image = File(pickedFile.path);
          _cert2Changed = true;
        }
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && !_validateStep0()) return;
    if (_currentStep == 1 && !_validateStep1()) return;

    if (_currentStep < 3) {
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      FocusScope.of(context).unfocus();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateStep0() {
    setState(() => _thumbnailError = false);

    if (_thumbnailImage == null && _currentThumbnailUrl == null) {
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

    return true;
  }

  bool _validateStep1() {
    if (_mrpController.text.trim().isEmpty) {
      _mrpFocus.requestFocus();
      _showWarning('Please enter MRP (Price) in Step 2');
      return false;
    }
    if (_courseValidityDays == null) {
      _showWarning('Please select Course Validity duration in Step 2');
      return false;
    }
    if (_hasCertificate) {
      final hasCert1 = _certificate1Image != null || _currentCert1Url != null;
      final hasCert2 = _certificate2Image != null || _currentCert2Url != null;
      if (!hasCert1 && !hasCert2) {
        _showWarning('Please upload at least one certificate design in Step 2');
        return false;
      }
    }
    return true;
  }

  bool _validateAllFields() {
    if (!_validateStep0()) return false;
    if (!_validateStep1()) return false;
    return true;
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

  Future<void> _updateCourse() async {
    if (!_validateAllFields()) return;

    setState(() => _isLoading = true);

    try {
      final firestore = FirestoreService();
      final Map<String, dynamic> updateData = {};

      // Basic Info
      updateData['title'] = _titleController.text.trim();
      updateData['description'] = _descController.text.trim();
      updateData['price'] =
          int.tryParse(_mrpController.text) ?? widget.course.price;
      updateData['discountPrice'] =
          int.tryParse(_finalPriceController.text) ??
          widget.course.discountPrice;
      updateData['category'] = _selectedCategory;
      updateData['difficulty'] = _difficulty;
      updateData['specialTagColor'] = _specialTagColor;
      updateData['isSpecialTagVisible'] = _isSpecialTagVisible;
      updateData['specialTagDurationDays'] = _specialTagDurationDays;
      updateData['language'] = _selectedLanguage;
      updateData['courseMode'] = _selectedCourseMode;
      updateData['supportType'] = _selectedSupportType;
      updateData['whatsappNumber'] = _whatsappController.text.trim();
      updateData['isBigScreenEnabled'] = _isBigScreenEnabled;
      updateData['websiteUrl'] = _websiteUrlController.text.trim();

      // Validity
      final int finalValidity = _courseValidityDays == -1
          ? (int.tryParse(_customValidityController.text) ?? 0)
          : _courseValidityDays!;
      updateData['courseValidityDays'] = finalValidity;

      // Certificate
      updateData['hasCertificate'] = _hasCertificate;
      updateData['selectedCertificateSlot'] = _selectedCertSlot;

      // Settings
      updateData['isOfflineDownloadEnabled'] = _isOfflineDownloadEnabled;
      updateData['isPublished'] = _isPublished;

      // Highlights
      updateData['highlights'] = _highlightControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // FAQs
      updateData['faqs'] = _faqControllers
          .where(
            (f) =>
                f['q']!.text.trim().isNotEmpty &&
                f['a']!.text.trim().isNotEmpty,
          )
          .map(
            (f) => {
              'question': f['q']!.text.trim(),
              'answer': f['a']!.text.trim(),
            },
          )
          .toList();

      // Contents
      updateData['contents'] = _courseContents;

      // START BACKGROUND UPDATE
      final localFiles = _collectLocalFiles(updateData);

      if (localFiles.isNotEmpty) {
        // Use Background Service
        print(
          "🚀 Starting Background Update with ${localFiles.length} files...",
        );
        FlutterBackgroundService().invoke('update_course', {
          'courseId': widget.course.id,
          'updateData': updateData,
          'files': localFiles,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Update started in background. You can leave this screen.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // No files to upload, direct update
        await firestore.updateCourse(widget.course.id, updateData);
        if (mounted) {
          _showSuccessDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating course: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
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
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Lottie.network(
                    'https://assets10.lottiefiles.com/packages/lf20_pqnfmone.json',
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
                    'Success! ✅',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Course updated successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close Dialog
                      Navigator.pop(context, true); // Close Screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF050505) : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050505) : Colors.white,
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentStep = index;
          });
        },
        children: [
          KeepAliveWrapper(child: _buildBasicInfoTab()),
          KeepAliveWrapper(child: _buildSetupTab()),
          KeepAliveWrapper(child: _buildContentsTab()),
          KeepAliveWrapper(child: _buildAdvancedTab()),
        ],
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
        title: const Text(
          'Drag and Drop Mode',
          style: TextStyle(color: Colors.white, fontSize: 16),
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
        title: Text(
          '${_selectedIndices.length} Selected',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmRemoveContent(null), // Bulk delete
          ),
        ],
        elevation: 2,
      );
    }

    return AppBar(
      title: Text(
        'Edit Course Info',
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_currentStep == 2) // Content Step (Index shifted)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: InkWell(
                onTap: _showAddContentMenu,
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Header Removed - Using CollapsingStepIndicator

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryColor
                : Colors.grey.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: isCurrent
                ? const Icon(Icons.edit, size: 16, color: Colors.white)
                : isActive
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? AppTheme.primaryColor : Colors.grey.shade500,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: _currentStep > step
            ? AppTheme.primaryColor
            : Colors.grey.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: _currentStep,
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
                      'Edit Course Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    // Draft Status Indicator (Always shown as synced in edit mode)
                    Container(
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
                  ],
                ),
                const SizedBox(height: 24),

                // 1. Image
                const Text(
                  'Course Cover (16:9 Size)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                _buildThumbnailPicker(),
                const SizedBox(height: 24),

                // 2. Title
                _buildTextField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  label: 'Course Title',
                  hint: 'Advanced Mobile Repairing',
                  icon: Icons.title,
                  maxLength: 40,
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
                    Expanded(child: _buildCategoryDropdown()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDifficultyDropdown()),
                  ],
                ),
                const SizedBox(height: 16),



                const SizedBox(height: 16),

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
                      onPressed: () {
                        setState(
                          () => _highlightControllers.add(
                            TextEditingController(),
                          ),
                        );
                      },
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
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: controller,
                              label: 'Highlight',
                              hint: 'Practical Chip Level Training',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  controller.dispose();
                                  _highlightControllers.removeAt(index);
                                });
                              },
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
                      onPressed: () {
                        setState(() {
                          _faqControllers.add({
                            'q': TextEditingController(),
                            'a': TextEditingController(),
                          });
                        });
                      },
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
                                  controller: faq['q']!,
                                  label: 'Question',
                                  hint: 'e.g. Who can join this course?',
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
                                  onPressed: () {
                                    setState(() {
                                      faq['q']?.dispose();
                                      faq['a']?.dispose();
                                      _faqControllers.removeAt(index);
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: faq['a']!,
                            label: 'Answer',
                            hint: 'Anyone with basic mobile knowledge...',
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomNavigation(),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupTab() {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: _currentStep,
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
                        controller: _discountController,
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
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  initialValue: _selectedLanguage,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: _inputVerticalPadding,
                      horizontal: 16,
                    ),
                    labelText: 'Course Language',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: const Icon(Icons.language, size: 20),
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
                  items: _languages
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedLanguage = v);
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        initialValue: _selectedCourseMode,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: _inputVerticalPadding,
                            horizontal: 16,
                          ),
                          labelText: 'Course Mode',
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
                        items: _courseModes
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(m, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null)
                            setState(() => _selectedCourseMode = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        initialValue: _selectedSupportType,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: _inputVerticalPadding,
                            horizontal: 16,
                          ),
                          labelText: 'Support Type',
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
                        items: _supportTypes
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null)
                            setState(() => _selectedSupportType = v);
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
                  subtitle: const Text('Allow access via Web/Desktop'),
                  value: _isBigScreenEnabled,
                  onChanged: (v) => setState(() => _isBigScreenEnabled = v),
                  activeThumbColor: AppTheme.primaryColor,
                ),
                if (_isBigScreenEnabled) ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _websiteUrlController,
                    label: 'Website Login URL',
                    hint: 'https://yourwebsite.com/login',
                    icon: Icons.language,
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
            child: _buildBottomNavigation(),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedTab() {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: _currentStep,
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
                const SizedBox(height: 12),

                // Offline Download
                const Text(
                  'Offline Features',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'Allow Offline Download',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Students can download videos for offline viewing',
                  ),
                  value: _isOfflineDownloadEnabled,
                  onChanged: (v) =>
                      setState(() => _isOfflineDownloadEnabled = v),
                  activeThumbColor: AppTheme.primaryColor,
                  tileColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_globalRadius),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: _borderOpacity),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const SizedBox(height: 12),

                // Published Status
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
                  onChanged: (v) => setState(() => _isPublished = v),
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
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomNavigation(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        32,
        24,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_currentStep < 3 ? _nextStep : _updateCourse),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.0),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep < 3 ? 'Next' : 'Update Course',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_globalRadius),
            border: Border.all(
              color: (_thumbnailImage == null && _currentThumbnailUrl == null)
                  ? (_thumbnailError
                        ? Colors.red.withOpacity(0.8)
                        : Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: _borderOpacity))
                  : AppTheme.primaryColor.withOpacity(0.5),
              width:
                  ((_thumbnailImage == null && _currentThumbnailUrl == null) &&
                      _thumbnailError)
                  ? 2
                  : 1,
              style: BorderStyle.solid,
            ),
            boxShadow: (_thumbnailImage == null && _currentThumbnailUrl == null)
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
                : (_currentThumbnailUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_currentThumbnailUrl!),
                          fit: BoxFit.cover,
                        )
                      : null),
          ),
          child: (_thumbnailImage == null && _currentThumbnailUrl == null)
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
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      initialValue: _selectedCategory,
      hint: Text(
        'Select Category',
        style: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
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
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_globalRadius),
        ),
        filled: true,
        fillColor: AppTheme.primaryColor.withValues(alpha: _fillOpacity),
      ),
      items: _categories
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(c, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedCategory = v),
    );
  }

  Widget _buildDifficultyDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      initialValue: _difficulty,
      hint: Text(
        'Select Type',
        style: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
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
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_globalRadius),
        ),
        filled: true,
        fillColor: AppTheme.primaryColor.withValues(alpha: _fillOpacity),
      ),
      items: _difficultyLevels
          .map(
            (l) => DropdownMenuItem(
              value: l,
              child: Text(l, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _difficulty = v),
    );
  }



  Widget _buildValiditySelector() {
    return Column(
      children: [
        DropdownButtonFormField<int>(
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          initialValue: _courseValidityDays,
          hint: const Text('Select Validity'),
          decoration: InputDecoration(
            labelText: 'Course Validity',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            prefixIcon: const Icon(Icons.history_toggle_off),
            contentPadding: const EdgeInsets.symmetric(
              vertical: _inputVerticalPadding,
              horizontal: 16,
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
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
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
            DropdownMenuItem(value: -1, child: Text('Other (Custom Days)')),
          ],
          onChanged: (v) => setState(() => _courseValidityDays = v),
        ),
        if (_courseValidityDays == -1) ...[
          const SizedBox(height: 16),
          _buildTextField(
            controller: _customValidityController,
            label: 'Enter Days',
            hint: 'e.g. 45',
            keyboardType: TextInputType.number,
            icon: Icons.calendar_today,
          ),
        ],
      ],
    );
  }

  Widget _buildCertificateSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Certification Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
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
          onChanged: (val) => setState(() => _hasCertificate = val),
          activeThumbColor: AppTheme.primaryColor,
          tileColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_globalRadius),
            side: BorderSide(
              color: _hasCertificate
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: _borderOpacity),
            ),
          ),
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
                        _buildCertificateUpload(1),
                        if (_selectedCertSlot == 1)
                          const Positioned(
                            top: 8,
                            right: 12,
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
                        _buildCertificateUpload(2),
                        if (_selectedCertSlot == 2)
                          const Positioned(
                            top: 8,
                            right: 12,
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

  Widget _buildCertificateUpload(int slot) {
    final file = slot == 1 ? _certificate1Image : _certificate2Image;
    final url = slot == 1 ? _currentCert1Url : _currentCert2Url;
    final hasImage = file != null || url != null;

    return GestureDetector(
      onTap: () => _pickCertificate(slot),
      child: AspectRatio(
        aspectRatio: 1.414,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_globalRadius),
            border: Border.all(
              color: Theme.of(
                context,
              ).dividerColor.withValues(alpha: _borderOpacity),
              style: BorderStyle.solid,
            ),
            image: hasImage
                ? DecorationImage(
                    image: file != null
                        ? FileImage(file)
                        : NetworkImage(url!) as ImageProvider,
                    fit: BoxFit.contain,
                  )
                : null,
          ),
          child: !hasImage
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload_file, size: 24, color: Colors.grey),
                    const SizedBox(height: 4),
                    Text(
                      'Slot $slot',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
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
          contentPadding: const EdgeInsets.symmetric(
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
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 2,
            ),
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

  // --- CONTENT TAB HELPERS ---

  Widget _buildContentsTab() {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: _currentStep,
            isSelectionMode: _isSelectionMode,
            isDragMode: _isDragModeActive,
          ),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          sliver: _courseContents.isEmpty
              ? SliverToBoxAdapter(
                  child: Container(
                    height: 300,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No content added yet',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showAddContentMenu,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Content'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverReorderableList(
                  itemCount: _courseContents.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) newIndex -= 1;
                      final item = _courseContents.removeAt(oldIndex);
                      _courseContents.insert(newIndex, item);
                    });
                  },
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
                      onEnterSelectionMode: () => _enterSelectionMode(index),
                      onStartHold: _startHoldTimer,
                      onCancelHold: _cancelHoldTimer,
                      onRename: () => _renameContent(index),
                      onToggleLock: () {
                        setState(() {
                          _courseContents[index]['isLocked'] =
                              !(_courseContents[index]['isLocked'] ?? true);
                        });
                      },
                      onRemove: () => _confirmRemoveContent(index),
                      onAddThumbnail: () => _showThumbnailManagerDialog(index),
                    );
                  },
                ),
        ),

        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomNavigation(),
          ),
        ),
      ],
    );
  }

  void _showThumbnailManagerDialog(int index) {
    String? errorMessage;
    bool isProcessing = false;
    String? currentThumbnail = _courseContents[index]['thumbnail'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool hasThumbnail = currentThumbnail != null;

            Future<void> pickAndValidate() async {
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
                  if (ratio < 1.7 || ratio > 1.85) {
                    setDialogState(() {
                      errorMessage =
                          "Invalid Ratio: ${ratio.toStringAsFixed(2)}\n\nRequired: 16:9 (YouTube Standard)\nPlease crop your image to 1920x1080.";
                      isProcessing = false;
                    });
                    return;
                  }

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
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.5),
                        ),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.file(
                          File(currentThumbnail!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
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
                      padding: EdgeInsets.all(16),
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
                            onPressed: () =>
                                setDialogState(() => currentThumbnail = null),
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
                    setState(() {
                      _courseContents[index]['thumbnail'] = currentThumbnail;
                    });
                    Navigator.pop(context);
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

  void _showAddContentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
              color: color.withValues(alpha: 0.1),
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
        title: const Text('New Folder'),
        content: TextField(
          controller: folderNameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
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
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickContentFile(String type, [List<String>? extensions]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SimpleFileExplorer(allowedExtensions: extensions ?? []),
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
        });
      }

      setState(() {
        _courseContents.insertAll(0, newItems);
      });

      // Auto generate thumbnails if video
      if (type == 'video') {
        unawaited(_processAutoThumbnails(newItems));
      }
    }
  }

  Future<void> _processAutoThumbnails(List<Map<String, dynamic>> items) async {
    for (var item in items) {
      if (item['type'] == 'video' && item['path'] != null) {
        try {
          final thumb = await VideoThumbnail.thumbnailFile(
            video: item['path'],
            thumbnailPath: (await path_provider.getTemporaryDirectory()).path,
            imageFormat: ImageFormat.JPEG,
            quality: 50,
          );
          if (thumb != null && mounted) {
            setState(() {
              item['thumbnail'] = thumb;
            });
          }
        } catch (e) {
          debugPrint("Thumbnail Error: $e");
        }
      }
    }
  }

  void _handleContentTap(Map<String, dynamic> item, int index) async {
    if (_isSelectionMode) {
      _toggleSelection(index);
      return;
    }

    if (item['type'] == 'folder') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FolderDetailScreen(
            folderName: item['name'],
            contentList:
                (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [],
            isReadOnly: false,
          ),
        ),
      );

      if (result != null && result is List<Map<String, dynamic>>) {
        setState(() {
          _courseContents[index]['contents'] = result;
        });
      }
    } else {
      final path = item['path'] ?? item['url'];
      if (path == null) return;
      final bool isNetwork = !path.startsWith('/');

      if (item['type'] == 'image') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewerScreen(
              filePath: path,
              title: item['name'],
              isNetwork: isNetwork,
            ),
          ),
        );
      } else if (item['type'] == 'video') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              playlist: [_courseContents[index]],
              initialIndex: 0,
            ),
          ),
        );
      } else if (item['type'] == 'pdf') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PDFViewerScreen(
              filePath: path,
              title: item['name'],
              isNetwork: isNetwork,
            ),
          ),
        );
      }
    }
  }

  void _toggleSelection(int index) {
    if (!_isSelectionMode) return;
    HapticFeedback.heavyImpact();
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _enterSelectionMode(int index) {
    _holdTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedIndices.clear();
      _selectedIndices.add(index);
    });
  }

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

  void _cancelHoldTimer() => _holdTimer?.cancel();

  void _renameContent(int index) {
    final text = _courseContents[index]['name'];
    final ctrl = TextEditingController(text: text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                setState(() {
                  _courseContents[index]['name'] = ctrl.text.trim();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveContent(int? index) {
    final isBulk = index == null;
    final count = isBulk ? _selectedIndices.length : 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBulk ? 'Remove $count Items?' : 'Remove Content?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                if (isBulk) {
                  final sortedIndices = _selectedIndices.toList()
                    ..sort((a, b) => b.compareTo(a)); // Descending
                  for (var i in sortedIndices) {
                    if (i < _courseContents.length) _courseContents.removeAt(i);
                  }
                  _selectedIndices.clear();
                  _isSelectionMode = false;
                } else {
                  _courseContents.removeAt(index);
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _pasteContent() {
    if (ContentClipboard.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
      return;
    }

    final items = ContentClipboard.items!;
    setState(() {
      for (var item in items) {
        final newItem = Map<String, dynamic>.from(item);
        newItem['isLocal'] = true;
        _courseContents.insert(0, newItem);
      }
      if (ContentClipboard.action == 'cut') ContentClipboard.clear();
    });
  }

  List<Map<String, dynamic>> _collectLocalFiles(
    Map<String, dynamic> updateData,
  ) {
    final List<Map<String, dynamic>> localFiles = [];

    // 1. Top Level Images
    if (_thumbnailChanged && _thumbnailImage != null) {
      updateData['thumbnailUrl'] =
          _thumbnailImage!.path; // Store Local Path temporarily
      localFiles.add({
        'filePath': _thumbnailImage!.path,
        'remotePath':
            'course_thumbnails/${path.basename(_thumbnailImage!.path)}',
        'type': 'image',
      });
    }

    if (_hasCertificate) {
      if (_cert1Changed && _certificate1Image != null) {
        updateData['certificateUrl1'] = _certificate1Image!.path;
        localFiles.add({
          'filePath': _certificate1Image!.path,
          'remotePath':
              'certificates/${path.basename(_certificate1Image!.path)}',
          'type': 'image',
        });
      }
      if (_cert2Changed && _certificate2Image != null) {
        updateData['certificateUrl2'] = _certificate2Image!.path;
        localFiles.add({
          'filePath': _certificate2Image!.path,
          'remotePath':
              'certificates/${path.basename(_certificate2Image!.path)}',
          'type': 'image',
        });
      }
    }

    // 3. Contents
    void traverse(List<dynamic> items) {
      for (var item in items) {
        if (item['isLocal'] == true && item['path'] != null) {
          final String p = item['path'];
          if (item['type'] == 'video') {
            localFiles.add({'filePath': p, 'type': 'video'});
            // Check for local thumbnail
            if (item['thumbnail'] != null &&
                !item['thumbnail'].toString().startsWith('http')) {
              localFiles.add({
                'filePath': item['thumbnail'],
                'remotePath':
                    'course_thumbnails/${path.basename(item['thumbnail'])}',
                'type': 'image',
              });
            }
          } else if (item['type'] == 'pdf') {
            localFiles.add({
              'filePath': p,
              'remotePath': 'files/${widget.course.id}/${path.basename(p)}',
              'type': 'pdf',
            });
          } else if (item['type'] == 'zip') {
            localFiles.add({
              'filePath': p,
              'remotePath': 'files/${widget.course.id}/${path.basename(p)}',
              'type': 'zip',
            });
          } else if (item['type'] == 'image') {
            localFiles.add({
              'filePath': p,
              'remotePath': 'course_content/${path.basename(p)}',
              'type': 'image',
            });
          }
        }
        if (item['type'] == 'folder' && item['contents'] != null) {
          traverse(item['contents']);
        }
      }
    }

    traverse(_courseContents);

    return localFiles;
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
