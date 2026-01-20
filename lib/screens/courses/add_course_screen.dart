import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/dashboard_provider.dart';
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
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/clipboard_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../content_viewers/image_viewer_screen.dart';
import '../content_viewers/video_player_screen.dart';
import '../content_viewers/pdf_viewer_screen.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class CourseUploadTask {
  final String label;
  double progress;
  CourseUploadTask({required this.label, this.progress = 0.0});
}

class _AddCourseScreenState extends State<AddCourseScreen> {
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
  final _finalPriceController = TextEditingController(); // Selling Price (Read Only)
  
  final _durationController = TextEditingController();
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
  int _newBatchDurationDays = 90;
  int? _courseValidityDays; // null by default, 0 for Lifetime
  bool _hasCertificate = false;
  File? _certificate1Image;
  File? _certificate2Image;
  int _selectedCertSlot = 1; // 1 or 2
  bool _isOfflineDownloadEnabled = true;
  bool _isSavingDraft = false;
  final List<Map<String, dynamic>> _demoVideos = [];
  final _customValidityController = TextEditingController(); // For custom days
  String _difficulty = 'Beginner'; // Acts as Course Type
  
  final List<String> _difficultyLevels = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> _categories = ['Hardware', 'Software'];

  // Parallel Upload Progress State
  List<CourseUploadTask> _uploadTasks = [];
  bool _isUploading = false;
  double _totalProgress = 0.0;
  String _uploadStatus = '';
  @override
  void initState() {
    super.initState();
    _mrpController.addListener(_calculateFinalPrice);
    _discountAmountController.addListener(_calculateFinalPrice);
    
    // Auto-save listeners for basic info
    _titleController.addListener(_saveCourseDraft);
    _descController.addListener(_saveCourseDraft);
    _mrpController.addListener(_saveCourseDraft);
    _discountAmountController.addListener(_saveCourseDraft);
    
    // Load Draft
    _loadCourseDraft().then((_) {
      if (mounted) setState(() => _isInitialLoading = false);
    });
  }

  // --- Persistence Logic ---
  Future<void> _loadCourseDraft() async {
    try {
       setState(() => _isSavingDraft = true);
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
            _difficulty = draft['difficulty'] ?? 'Beginner';
            
             if (draft['contents'] != null) {
                _courseContents.clear();
                _courseContents.addAll(List<Map<String, dynamic>>.from(draft['contents']));
             }
             if (draft['demoVideos'] != null) {
                _demoVideos.clear();
                _demoVideos.addAll(List<Map<String, dynamic>>.from(draft['demoVideos']));
             }
                // _courseValidityDays = draft['validity']; // IGNORED: Force null by default as per user request
                _courseValidityDays = null; 
                _hasCertificate = draft['certificate'] ?? false;
                _selectedCertSlot = draft['certSlot'] ?? 1;
                _isOfflineDownloadEnabled = draft['offlineDownload'] ?? true;
                _isPublished = draft['isPublished'] ?? false;
                if (draft['customDays'] != null) {
                  _customValidityController.text = draft['customDays'].toString();
                }
          });
         
         // Silent restoration, no SnackBar
      }
    } catch (e) {
       // debugPrint("Error loading draft: $e");
    }
  }

  Future<void> _saveCourseDraft() async {
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
          'contents': _courseContents,
          'validity': _courseValidityDays,
          'certificate': _hasCertificate,
          'certSlot': _selectedCertSlot,
          'offlineDownload': _isOfflineDownloadEnabled,
          'isPublished': _isPublished,
          'demoVideos': _demoVideos,
          'customDays': int.tryParse(_customValidityController.text),
       };
      
       await prefs.setString('course_creation_draft', jsonEncode(draft));
       
       if (mounted) {
         Future.delayed(const Duration(seconds: 1), () {
           if (mounted) setState(() => _isSavingDraft = false);
         });
       }
    } catch (e) {
       // debugPrint("Error saving draft: $e");
    }
  }



  void _calculateFinalPrice() {
    final double mrp = double.tryParse(_mrpController.text) ?? 0;
    final double discountAmt = double.tryParse(_discountAmountController.text) ?? 0;
    
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
    _titleController.dispose();
    _descController.dispose();
    _mrpController.dispose();
    _discountAmountController.dispose();
    _finalPriceController.dispose();
    _durationController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    _customValidityController.dispose();

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
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
              ),
              child: Column(
                children: [
                  Lottie.network(
                    'https://assets10.lottiefiles.com/packages/lf20_pqnfmone.json', // Confetti Lottie
                    width: 200, height: 200,
                    animate: true,
                    repeat: false,
                    errorBuilder: (c, e, s) => const Icon(Icons.check_circle, color: Colors.green, size: 100),
                  ),
                  const Text('Congratulations! 🎉', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Your course has been created successfully.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                       Navigator.pop(context); // Close Dialog
                       Navigator.pop(context, true); // Close Screen and Return Success
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
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
    // 1. Basic Info Check
    if (_thumbnailImage == null) {
      _jumpToStep(0);
      _showWarning('Please select a course thumbnail (Step 1)');
      return false;
    }
    if (_titleController.text.trim().isEmpty) {
      _jumpToStep(0);
      _showWarning('Please enter course title (Step 1)');
      return false;
    }
    if (_selectedCategory == null) {
      _jumpToStep(0);
      _showWarning('Please select a category (Step 1)');
      return false;
    }
    if (_mrpController.text.isEmpty) {
      _jumpToStep(0);
      _showWarning('Please enter selling price (Step 1)');
      return false;
    }

    // 2. Advance Settings Check
    if (_courseValidityDays == null) {
      _showWarning('Please select Course Validity duration (Step 3)');
      return false;
    }
    
    // 3. Certificate Check (If enabled)
    if (_hasCertificate) {
       if (_certificate1Image == null && _certificate2Image == null) {
         _showWarning('Please upload at least one certificate design (Step 3)');
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rate_review_outlined, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text('Quick Course Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const Divider(height: 24),
          _buildReviewItem(Icons.title, 'Title', _titleController.text.isEmpty ? 'Not Set' : _titleController.text, () => _jumpToStep(0)),
          _buildReviewItem(Icons.category_outlined, 'Category', _selectedCategory ?? 'Not Selected', () => _jumpToStep(0)),
          _buildReviewItem(Icons.payments_outlined, 'Price', '₹${_finalPriceController.text}', () => _jumpToStep(0)),
          _buildReviewItem(Icons.video_collection_outlined, 'Content', '${_getAllVideosFromContents(_courseContents).length} Videos', () => _jumpToStep(1)),
          _buildReviewItem(Icons.history_toggle_off, 'Validity', _getValidityText(_courseValidityDays), null),
          _buildReviewItem(Icons.workspace_premium_outlined, 'Certificate', _hasCertificate ? 'Enabled' : 'Disabled', null),
          _buildReviewItem(Icons.public, 'Status', _isPublished ? 'Public' : 'Hidden', null),
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

  Widget _buildReviewItem(IconData icon, String label, String value, VoidCallback? onEdit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              if (onEdit != null) Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
   void _nextStep() async {
    if (_currentStep < 2) {
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 50));
      await _pageController.nextPage(duration: 250.ms, curve: Curves.easeInOut);
    }
  }
  void _prevStep() async {
    if (_currentStep > 0) {
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 50));
      await _pageController.previousPage(duration: 250.ms, curve: Curves.easeInOut);
    }
  }

   Future<void> _submitCourse() async {
    if (!_validateAllFields()) return; 

    setState(() {
      _isLoading = true;
      _isUploading = true;
      _uploadTasks = [];
    });

    try {
      await WakelockPlus.enable(); // Keep screen on during upload

      // 1. Initialize Tasks
      if (_thumbnailImage != null) _uploadTasks.add(CourseUploadTask(label: 'Course Thumbnail'));
      if (_hasCertificate && _certificate1Image != null) _uploadTasks.add(CourseUploadTask(label: 'Certificate Design A'));
      if (_hasCertificate && _certificate2Image != null) _uploadTasks.add(CourseUploadTask(label: 'Certificate Design B'));
      
      final allLocalFiles = _getAllLocalFilesFromContents(_courseContents);
      for (var file in allLocalFiles) {
        _uploadTasks.add(CourseUploadTask(label: '${file['type'].toString().toUpperCase()}: ${file['name']}'));
      }

      // 2. Start Parallel Uploads
      setState(() {}); // Refresh UI to show tasks

      String thumbnailUrl = '';
      String? cert1Url;
      String? cert2Url;

      // Wrap upload functions to update our task list
      Future<String> uploadWithProgress(File file, String folder, int taskIndex) async {
        return await _bunnyService.uploadImage(
          filePath: file.path,
          folder: folder,
          onProgress: (sent, total) {
            if (mounted) {
              setState(() {
                _uploadTasks[taskIndex].progress = sent / total;
                _calculateOverallProgress();
              });
            }
          },
        );
      }

      int currentTaskIndex = 0;
      List<Future<void>> uploadFutures = [];

      // START HEAVY SYSTEM: Protection Layer (Service + WakeLock)
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        service.startService();
      }

      if (_thumbnailImage != null) {
        final tIdx = currentTaskIndex++;
        uploadFutures.add(uploadWithProgress(_thumbnailImage!, 'thumbnails', tIdx)
          .then((url) => thumbnailUrl = url));
      }

      if (_hasCertificate && _certificate1Image != null) {
        final c1Idx = currentTaskIndex++;
        uploadFutures.add(uploadWithProgress(_certificate1Image!, 'certificates', c1Idx)
          .then((url) => cert1Url = url));
      }

      if (_hasCertificate && _certificate2Image != null) {
        final c2Idx = currentTaskIndex++;
        uploadFutures.add(uploadWithProgress(_certificate2Image!, 'certificates', c2Idx)
          .then((url) => cert2Url = url));
      }

      // Generate Session ID for Unique Folder
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Add All File Uploads to Task Queue (Delayed Execution)
      List<Future<void> Function()> contentTasks = [];
      
      for (int i = 0; i < allLocalFiles.length; i++) {
        final fIdx = currentTaskIndex++;
        final item = allLocalFiles[i];
        final path = item['path'];
        final name = item['name'];
        final type = item['type'];
        
        // Determine remote folder based on type
        String folder = 'others';
        if (type == 'video') folder = 'videos';
        else if (type == 'pdf') folder = 'pdfs';
        else if (type == 'image') folder = 'images';
        // Use Index to ensure uniqueness on server even if filenames differ
        final uniqueName = '${fIdx}_$name';

        // Add task closure to queue
        contentTasks.add(() async {
          await _bunnyService.uploadFile(
            filePath: path,
            remotePath: 'courses/$sessionId/$folder/$uniqueName', 
            onProgress: (sent, total) {
              if (mounted) {
                setState(() {
                  _uploadTasks[fIdx].progress = sent / total;
                  _calculateOverallProgress();
                  
                  // Update Notification Bar (Heavy System)
                  service.invoke('update_notification', {
                    'status': 'Uploading... ${(fIdx + 1)}/${_uploadTasks.length}',
                    'progress': (_totalProgress * 100).toInt(),
                  });
                });
              }
            },
          ).then((url) {
            // DIRECT UPDATE (By Reference)
            item['path'] = url;
            item['isLocal'] = false;

            // Sync Demo Videos (Match by original path since that's what we have locally)
            if (type == 'video') {
               for (var demo in _demoVideos) {
                  if (demo['path'] == path) { // Match by original path
                     demo['path'] = url;
                     demo['isLocal'] = false;
                  }
               }
            }
          });
        });
      }

      // 1. Wait for Thumbnails/Certificates (Fast)
      if (uploadFutures.isNotEmpty) {
        await Future.wait(uploadFutures);
      }

      // 2. Process Content Queue with Concurrency Limit (Safe)
      if (contentTasks.isNotEmpty) {
        await _processQueue(contentTasks, concurrent: 5);
      }

      // Stop Service on Success
      service.invoke("stop");
      WakelockPlus.disable();

      final String finalDesc = _descController.text.trim();
      final int finalValidity = _courseValidityDays == -1 
          ? (int.tryParse(_customValidityController.text) ?? 0) 
          : _courseValidityDays!;

      final newCourse = CourseModel(
        id: '', 
        title: _titleController.text.trim(),
        category: _selectedCategory!, 
        price: int.parse(_finalPriceController.text),
        discountPrice: int.parse(_mrpController.text),
        description: finalDesc,
        thumbnailUrl: thumbnailUrl,
        duration: '', 
        difficulty: _difficulty,
        enrolledStudents: 0,
        rating: 0.0,
        totalVideos: _getAllVideosFromContents(_courseContents).length,
        isPublished: _isPublished,
        createdAt: DateTime.now(),
        newBatchDays: _newBatchDurationDays,
        courseValidityDays: finalValidity,
        hasCertificate: _hasCertificate,
        certificateUrl1: cert1Url,
        certificateUrl2: cert2Url,
        selectedCertificateSlot: _selectedCertSlot,
        demoVideos: _demoVideos,
        isOfflineDownloadEnabled: _isOfflineDownloadEnabled,
        contents: _courseContents,
      );

      if (mounted) {
        await Provider.of<DashboardProvider>(context, listen: false).addCourse(newCourse);
        setState(() {
          _isUploading = false;
          _isLoading = false;
        });
        _showSuccessCelebration();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      await WakelockPlus.disable(); // Allow screen to turn off
      FlutterBackgroundService().invoke("stop"); // Ensure service stops
      if (mounted) setState(() => _isLoading = false);
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
  List<Map<String, dynamic>> _getAllLocalFilesFromContents(List<dynamic> items) {
    List<Map<String, dynamic>> files = [];
    for (var item in items) {
      if ((item['type'] == 'video' || item['type'] == 'pdf' || item['type'] == 'zip' || item['type'] == 'image') && item['isLocal'] == true) {
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
               physics: const NeverScrollableScrollPhysics(), // Force button usage
               onPageChanged: (idx) {
                 setState(() => _currentStep = idx);
               },
               children: [
                 KeepAliveWrapper(child: _buildStep1Basic()),
                 KeepAliveWrapper(child: _buildStep2Content()),
                 KeepAliveWrapper(child: _buildStep3Advance()),
               ],
             ),
             if (_isUploading) _buildUploadingOverlay(),
             if (_isLoading && !_isUploading) const Center(child: CircularProgressIndicator()),
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
                 width: 150, height: 150,
                 animate: true,
                 repeat: true,
                 errorBuilder: (c, e, s) => const Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.white),
               ),
               const Text('Uploading Course Materials', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               Text('Upload will continue even if you switch apps', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
               const SizedBox(height: 40),
               
               // Overall Progress
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 40),
                 child: Column(
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text('Overall Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                         Text('${(_totalProgress * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                       ],
                     ),
                     const SizedBox(height: 12),
                     ClipRRect(
                       borderRadius: BorderRadius.circular(10),
                       child: LinearProgressIndicator(
                         value: _totalProgress,
                         minHeight: 12,
                         backgroundColor: Colors.white.withOpacity(0.1),
                         valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                       ),
                     ),
                   ],
                 ),
               ),
               
               const SizedBox(height: 40),
               const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 24),
                 child: Align(alignment: Alignment.centerLeft, child: Text('BATCH DETAILS', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
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
                       decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             children: [
                               Icon(task.progress == 1.0 ? Icons.check_circle : Icons.upload_file, color: task.progress == 1.0 ? Colors.green : Colors.blue, size: 20),
                               const SizedBox(width: 12),
                               Expanded(child: Text(task.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
                               Text('${(task.progress * 100).toInt()}%', style: TextStyle(color: task.progress == 1.0 ? Colors.green : Colors.grey, fontSize: 11)),
                             ],
                           ),
                           if (task.progress < 1.0) ...[
                             const SizedBox(height: 10),
                             LinearProgressIndicator(value: task.progress, minHeight: 4, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(task.progress == 1.0 ? Colors.green : Colors.blue)),
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
                     Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                     const SizedBox(width: 12),
                     Expanded(child: Text('Please do not close or kill the app until the upload is complete.', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))),
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
            child: Text('Drag and Drop Mode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
            child: Text('${_selectedIndices.length} Selected', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
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
                           for(int i=0; i<_courseContents.length; i++) {
                             _selectedIndices.add(i);
                           }
                        }
                     });
                  },
                  child: Text(_selectedIndices.length == _courseContents.length ? 'Unselect' : 'All', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
              ),
            ),
            IconButton(icon: const Icon(Icons.copy), onPressed: () => _handleBulkCopyCut(false)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _handleBulkDelete),
          ],
          elevation: 2,
       );
    }
    return AppBar(
      title: const Text('Add New Course', style: TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      elevation: 0,
    );
  }






  


  Widget _buildNavButtons() {
    return Padding(
      padding: EdgeInsets.only(top: 32, bottom: 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep == 2 ? (_isLoading ? null : _submitCourse) : _nextStep,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_currentStep == 2 ? 'Create Course' : 'Next Step', style: const TextStyle(color: Colors.white))
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
            isDragMode: false
          ),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create New Course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                if (_isSavingDraft) 
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_done_outlined, size: 12, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text('Draft Saved', style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                 // 1. Image
                const Text('Course Cover (16:9 Size)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickImage,
                  child: AspectRatio(
                    aspectRatio: 16 / 9, // 16:9 Ratio
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _thumbnailImage == null ? Colors.grey.shade300 : AppTheme.primaryColor.withOpacity(0.5), width: _thumbnailImage == null ? 1 : 2),
                        image: _thumbnailImage != null
                            ? DecorationImage(image: FileImage(_thumbnailImage!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _thumbnailImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded, size: 48, color: AppTheme.primaryColor.withOpacity(0.8)),
                                const SizedBox(height: 8),
                                Text('Select 16:9 Image', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
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
                  label: 'Course Title', 
                  icon: Icons.title, 
                  maxLength: 35
                ),

                // 3. Description
                _buildTextField(
                  controller: _descController,
                  label: 'Description',
                  maxLines: 5,
                  alignTop: true, 
                ),

                // 4. Pricing (Row of 3) - Removed icons for compact view on narrow screens
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Expanded(flex: 2, child: _buildTextField(controller: _mrpController, label: 'MRP', keyboardType: TextInputType.number)),
                     const SizedBox(width: 8),
                     Expanded(flex: 3, child: _buildTextField(controller: _discountAmountController, label: 'Discount ₹', keyboardType: TextInputType.number)),
                     const SizedBox(width: 8),
                     Expanded(flex: 2, child: _buildTextField(controller: _finalPriceController, label: 'Final', keyboardType: TextInputType.number, readOnly: true)),
                  ],
                ),

                // 5. Category & Type
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(labelText: 'Category', floatingLabelBehavior: FloatingLabelBehavior.always, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).cardColor),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _difficulty,
                        decoration: InputDecoration(labelText: 'Course Type', floatingLabelBehavior: FloatingLabelBehavior.always, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).cardColor),
                        items: _difficultyLevels.map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _difficulty = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<int>(
                   initialValue: _newBatchDurationDays,
                   decoration: InputDecoration(labelText: 'New Badge Duration', floatingLabelBehavior: FloatingLabelBehavior.always, prefixIcon: const Icon(Icons.timer_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).cardColor),
                   items: const [DropdownMenuItem(value: 30, child: Text('1 Month')), DropdownMenuItem(value: 60, child: Text('2 Months')), DropdownMenuItem(value: 90, child: Text('3 Months'))],
                   onChanged: (v) => setState(() => _newBatchDurationDays = v!),
                ),
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

  Future<void> _pickDemoVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
    if (result != null && result.paths.isNotEmpty) {
      setState(() {
        for (var path in result.paths) {
          if (path != null) {
            _demoVideos.add({
              'name': path.split('/').last,
              'path': path,
              'isLocal': true,
            });
          }
        }
      });
      unawaited(_saveCourseDraft());
    }
  }

  // Helper to get all videos from contents recursively
  List<Map<String, dynamic>> _getAllVideosFromContents(List<dynamic> items) {
    List<Map<String, dynamic>> videos = [];
    for (var item in items) {
      if (item['type'] == 'video') {
         videos.add(Map<String, dynamic>.from(item));
      } else if (item['type'] == 'folder' && item['contents'] != null) { // Changed 'children' to 'contents' based on existing code
         videos.addAll(_getAllVideosFromContents(item['contents']));
      }
    }
    return videos;
    return videos;
  }

  void _syncDemoVideos() {
    final allAvailable = _getAllVideosFromContents(_courseContents);
    final availableNames = allAvailable.map((v) => v['name']).toSet();
    
    setState(() {
       _demoVideos.removeWhere((demo) => !availableNames.contains(demo['name']));
    });
  }

  Future<void> _showDemoSelectionDialog() async {
    final allVideos = _getAllVideosFromContents(_courseContents);
    
    if (allVideos.isEmpty) {
      _showWarning('No videos found in Contents. Please add videos in Step 2 first.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Demo Videos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: allVideos.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final video = allVideos[index];
                    final isAlreadyDemo = _demoVideos.any((v) => v['name'] == video['name']);
                    
                    return CheckboxListTile(
                      value: isAlreadyDemo,
                      title: Text(video['name'], style: const TextStyle(fontSize: 14)),
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) {
                         setState(() {
                            if (val == true) {
                               _demoVideos.add(video);
                            } else {
                               _demoVideos.removeWhere((v) => v['name'] == video['name']);
                            }
                         });
                         // Update Dialog UI
                         setDialogState(() {});
                         unawaited(_saveCourseDraft());
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
              ],
            );
          }
        );
      }
    );
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
         content: Text('Are you sure you want to delete ${_selectedIndices.length} items?'),
         actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                 final List<int> indices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
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
            )
         ],
       )
     );
  }

  void _handleBulkCopyCut(bool isCut) {
      if (_selectedIndices.isEmpty) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isCut ? 'Cut Items?' : 'Copy Items?'),
          content: Text('${isCut ? 'Cut' : 'Copy'} ${_selectedIndices.length} items to clipboard?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () {
                _performCopyCut(isCut);
                Navigator.pop(context);
            }, child: Text(isCut ? 'Cut' : 'Copy'))
          ]
        )
      );
  }

  void _performCopyCut(bool isCut) {
      final List<int> indices = _selectedIndices.toList()..sort((a, b) => a.compareTo(b));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${itemsToCopy.length} items ${isCut ? 'Cut' : 'Copied'}')));
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
    return Stack(
      children: [
        CustomScrollView(
          key: const ValueKey('step2_scroll_view'),
          slivers: [
             SliverPersistentHeader(
               key: const ValueKey('step2_header'),
               delegate: CollapsingStepIndicator(
                 currentStep: 1,
                 isSelectionMode: _isSelectionMode,
                 isDragMode: _isDragModeActive
               ),
               pinned: true,
             ),
             
             // Dynamic helper to ensure FAB scrolls with content and doesn't block header
             SliverToBoxAdapter(
               child: (!_isSelectionMode && !_isDragModeActive)
                 ? Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, right: 24, bottom: 0),
                      child: InkWell(
                         onTap: _showAddContentMenu,
                         borderRadius: BorderRadius.circular(30),
                         child: Container(
                           height: 50,
                           width: 50,
                           decoration: BoxDecoration(
                             color: AppTheme.primaryColor,
                             shape: BoxShape.circle,
                             boxShadow: [
                               BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                             ],
                           ),
                           child: const Icon(Icons.add, color: Colors.white, size: 28),
                         ),
                       ),
                    ),
                  )
                 : const SizedBox.shrink(),
             ),

             SliverPadding(
               key: const ValueKey('step2_content_padding'),
               padding: EdgeInsets.fromLTRB(24, (_isSelectionMode || _isDragModeActive) ? 20 : 12, 24, 24),
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
                            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No content added yet', style: TextStyle(color: Colors.grey.shade400)),
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
                           onEnterSelectionMode: () => _enterSelectionMode(index),
                           onStartHold: _startHoldTimer,
                           onCancelHold: _cancelHoldTimer,
                           onRename: () => _renameContent(index),
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
                 child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildNavButtons(),
                 ),
               ),
            ),
          ],
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
                contentList: (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [],
              )
            )
          );
          
          if (result != null && result is List<Map<String, dynamic>>) {
             setState(() {
                _courseContents[index]['contents'] = result;
             });
             unawaited(_saveCourseDraft());
          }
      } else if (type == 'image') {
          unawaited(Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(
            filePath: path,
            title: item['name'],
          ))));
      } else if (type == 'video') {
          final videoList = _courseContents.where((element) => element['type'] == 'video').toList();
          final initialIndex = videoList.indexOf(item);
          unawaited(Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(
            playlist: videoList, 
            initialIndex: initialIndex >= 0 ? initialIndex : 0,
          ))));
      } else if (type == 'pdf') {
          unawaited(Navigator.push(context, MaterialPageRoute(builder: (_) => PDFViewerScreen(
            filePath: path,
            title: item['name'],
          ))));
      }
  }

  void _renameContent(int index) {
      final TextEditingController renameController = TextEditingController(text: _courseContents[index]['name']);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rename Content'),
          content: TextField(
            controller: renameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter new name', border: OutlineInputBorder()),
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
                  _syncDemoVideos();
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
        content: Text('Are you sure you want to remove "${_courseContents[index]['name']}"?'),
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
                _syncDemoVideos();
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
                MaterialPageRoute(builder: (_) => SimpleFileExplorer(
                  allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                ))
              );
              
              if (result != null && result is List && result.isNotEmpty) {
                  setDialogState(() => isProcessing = true);
                  final String filePath = result.first as String;
                  
                  try {
                    final File file = File(filePath);
                    final decodedImage = await decodeImageFromList(file.readAsBytesSync());
                    
                    final double ratio = decodedImage.width / decodedImage.height;
                    // 16:9 is approx 1.77. Allow 1.7 to 1.85
                    if (ratio < 1.7 || ratio > 1.85) {
                      setDialogState(() {
                         errorMessage = "Invalid Ratio: ${ratio.toStringAsFixed(2)}\n\n"
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
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.red.withOpacity(0.5))
                       ),
                       child: Row(
                         children: [
                           const Icon(Icons.error_outline, color: Colors.red),
                           const SizedBox(width: 8),
                           Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                         ],
                       ),
                     ),

                  if (hasThumbnail)
                    Column(
                      children: [
                         ClipRRect(
                           borderRadius: BorderRadius.circular(12),
                           child: AspectRatio(
                             aspectRatio: 16/9,
                             child: Image.file(
                               File(currentThumbnail!), 
                               fit: BoxFit.cover,
                               errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image)),
                             )
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid)
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No Thumbnail', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  
                  if (isProcessing)
                    const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())
                  else
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                       children: [
                         ElevatedButton.icon(
                           onPressed: pickAndValidate,
                           icon: const Icon(Icons.add_photo_alternate),
                           label: Text(hasThumbnail ? 'Change' : 'Add Image'),
                           style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                         ),
                         if (hasThumbnail)
                           TextButton.icon(
                             onPressed: () {
                                setDialogState(() => currentThumbnail = null);
                             },
                             icon: const Icon(Icons.delete, color: Colors.red),
                             label: const Text('Remove', style: TextStyle(color: Colors.red)),
                           )
                       ],
                    )
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thumbnail Saved!')));
                  },
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Close')
                ),
              ],
            );
          }
        );
      }
    );
  }



  void _pasteContent() {
    if (ContentClipboard.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
      return;
    }

    setState(() {
      for (var item in ContentClipboard.items!) {
         final newItem = Map<String, dynamic>.from(jsonDecode(jsonEncode(item)));
         newItem['name'] = '${newItem['name']} (Copy)';
         newItem['isLocal'] = true; // Essential for persistence
         _courseContents.insert(0, newItem);
      }
    });
    _saveCourseDraft();
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ContentClipboard.items!.length} items pasted')));
  }

  void _showAddContentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add to Course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildOptionItem(Icons.create_new_folder, 'Folder', Colors.orange, () => _showCreateFolderDialog()),
                  _buildOptionItem(Icons.video_library, 'Video', Colors.red, () => _pickContentFile('video', ['mp4', 'mkv', 'avi'])),
                  _buildOptionItem(Icons.picture_as_pdf, 'PDF', Colors.redAccent, () => _pickContentFile('pdf', ['pdf'])),
                  _buildOptionItem(Icons.image, 'Image', Colors.purple, () => _pickContentFile('image', ['jpg', 'jpeg', 'png', 'webp'])),
                  _buildOptionItem(Icons.folder_zip, 'Zip', Colors.blueGrey, () => _pickContentFile('zip', ['zip', 'rar'])),
                  _buildOptionItem(Icons.content_paste, 'Paste', Colors.grey, _pasteContent),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () { Navigator.pop(context); onTap(); },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    final folderNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Folder'),
        content: TextField(
          controller: folderNameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Folder Name', 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (folderNameController.text.trim().isNotEmpty) {
                setState(() {
                  _courseContents.insert(0, {
                    'type': 'folder', 
                    'name': folderNameController.text.trim(),
                    'contents': <Map<String, dynamic>>[],
                    'isLocal': true,
                  });
                });
                _saveCourseDraft();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickContentFile(String type, [List<String>? allowedExtensions]) async {
      // ZERO CACHE: Use custom explorer for ALL types
      final result = await Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => SimpleFileExplorer(
          allowedExtensions: allowedExtensions ?? [],
        ))
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

  Widget _buildStep3Advance() {
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: 2,
            isSelectionMode: false,
            isDragMode: false
          ),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Course Validity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                   isExpanded: true,
                    value: _courseValidityDays,
                    hint: const Text('Select Validity'),
                    decoration: InputDecoration(
                       labelText: 'Course Validity', 
                       floatingLabelBehavior: FloatingLabelBehavior.always, 
                       prefixIcon: const Icon(Icons.history_toggle_off), 
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
                       filled: true, 
                       fillColor: Theme.of(context).cardColor
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Lifetime Access')), 
                      DropdownMenuItem(value: 184, child: Text('6 Months')),
                      DropdownMenuItem(value: 365, child: Text('1 Year')),
                      DropdownMenuItem(value: 730, child: Text('2 Years')),
                      DropdownMenuItem(value: 1095, child: Text('3 Years')),
                    ],
                    onChanged: (v) => setState(() => _courseValidityDays = v),
                 ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Certification Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _hasCertificate ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _hasCertificate ? 'ENABLED' : 'DISABLED',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _hasCertificate ? Colors.green : Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Enable Certificate', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_hasCertificate ? 'Certificate will be issued on completion' : 'No certificate for this course'),
                  value: _hasCertificate,
                  onChanged: (v) => setState(() => _hasCertificate = v),
                  activeColor: AppTheme.primaryColor,
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _hasCertificate ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade200)),
                ),
                if (_hasCertificate) ...[
                  const SizedBox(height: 24),
                  const Text('Upoad Two Certificate Designs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('Strictly 3508 x 2480 Pixels (A4 Landscape)', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('Design A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _selectedCertSlot == 1 ? AppTheme.primaryColor : Colors.grey)),
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
                                if (_selectedCertSlot == 1) Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 24)),
                                Positioned(
                                  bottom: 8, left: 8, 
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _selectedCertSlot = 1),
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size(0, 0),
                                      backgroundColor: _selectedCertSlot == 1 ? AppTheme.primaryColor : Theme.of(context).cardColor,
                                    ),
                                    child: Text('Select', style: TextStyle(fontSize: 10, color: _selectedCertSlot == 1 ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color)),
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
                            Text('Design B', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _selectedCertSlot == 2 ? AppTheme.primaryColor : Colors.grey)),
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
                                if (_selectedCertSlot == 2) Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 24)),
                                Positioned(
                                  bottom: 8, left: 8, 
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _selectedCertSlot = 2),
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size(0, 0),
                                      backgroundColor: _selectedCertSlot == 2 ? AppTheme.primaryColor : Theme.of(context).cardColor,
                                    ),
                                    child: Text('Select', style: TextStyle(fontSize: 10, color: _selectedCertSlot == 2 ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color)),
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
                const SizedBox(height: 32),
                
                // 3. Offline Download Function
                const Text('Offline Features', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Allow Offline Download', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Students can download videos for offline viewing'),
                  value: _isOfflineDownloadEnabled,
                  onChanged: (v) => setState(() => _isOfflineDownloadEnabled = v),
                  activeColor: AppTheme.primaryColor,
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                ),
                const SizedBox(height: 32),

                // 4. Demo Videos Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Demo Videos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      onPressed: _courseContents.isEmpty ? null : () => _showDemoSelectionDialog(),
                      icon: const Icon(Icons.playlist_add_check, size: 20),
                      label: const Text('Select from Contents'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                    ),
                  ],
                ),
                const Text('Free videos shown to all users as previews', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                if (_demoVideos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200, style: BorderStyle.none)),
                    child: Column(
                      children: [
                        Icon(Icons.video_library_outlined, color: Colors.grey.shade400, size: 32),
                        const SizedBox(height: 8),
                        Text('No demo videos added yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  )
                else
                  Theme(
                    data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _demoVideos.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _demoVideos.removeAt(oldIndex);
                          _demoVideos.insert(newIndex, item);
                        });
                        unawaited(_saveCourseDraft());
                      },
                      itemBuilder: (context, index) {
                        final video = _demoVideos[index];
                        return Container(
                          key: ValueKey(video['name'] + index.toString()),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                          child: Row(
                            children: [
                              const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
                              const SizedBox(width: 8),
                              Container(width: 60, height: 40, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 20)),
                              const SizedBox(width: 12),
                              Expanded(child: Text(video['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20), onPressed: () => setState(() => _demoVideos.removeAt(index))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 32),

                // 5. Publish Toggle
                const Text('Publish Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(_isPublished ? 'Course is Public' : 'Course is Hidden (Draft)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_isPublished ? 'Visible to all students on the app' : 'Only visible to admins'),
                  value: _isPublished,
                  onChanged: (v) => setState(() => _isPublished = v),
                  activeColor: Colors.green,
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _isPublished ? Colors.green.withOpacity(0.3) : Colors.grey.shade200)),
                ),
                
                const SizedBox(height: 24),
                _buildCourseReviewCard(),
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

  Widget _buildImageUploader({File? image, required VoidCallback onTap, required String label, required IconData icon, double aspectRatio = 16/9}) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor, style: BorderStyle.solid),
            image: image != null ? DecorationImage(image: FileImage(image), fit: BoxFit.contain) : null,
          ),
          child: image == null ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.grey, size: 30),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ) : null,
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
                content: Text('Error: Image must be 3508x2480 px. Current: ${decodedImage.width}x${decodedImage.height}'),
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
    }
  }




  // Helper
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon, // Optional now
    TextInputType keyboardType = TextInputType.text,
    int? maxLines = 1,
    int? maxLength,
    bool readOnly = false,
    bool alignTop = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        readOnly: readOnly,
        textAlignVertical: alignTop ? TextAlignVertical.top : TextAlignVertical.center,
        style: TextStyle(
          color: readOnly ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8) : Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always, 
          alignLabelWithHint: alignTop,
          prefixIcon: icon != null ? (alignTop 
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.start, 
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Icon(icon, color: Colors.grey),
                    ),
                  ],
                )
              : Icon(icon, color: Colors.grey)) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: readOnly 
              ? (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100)
              : Theme.of(context).cardColor,
          counterText: maxLength != null ? null : '',
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: List.generate(5, (index) => 
          Shimmer.fromColors(
            baseColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Container(
              height: 70,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Concurrency Limited Queue Processor
  Future<void> _processQueue(List<Future<void> Function()> tasks, {int concurrent = 2}) async {
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

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}


