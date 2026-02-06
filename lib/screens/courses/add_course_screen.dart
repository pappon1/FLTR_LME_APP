import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../utils/app_theme.dart';

// Modular Imports
import 'add_course/local_logic/state_manager.dart';
import 'add_course/local_logic/draft_manager.dart';
import 'add_course/local_logic/validation.dart';
import 'add_course/local_logic/content_manager.dart';
import 'add_course/local_logic/navigation_logic.dart';
import 'add_course/local_logic/step0_logic.dart';
import 'add_course/local_logic/step1_logic.dart';
import 'add_course/local_logic/step2_logic.dart';
import 'add_course/backend_service/submit_handler.dart';
import 'add_course/backend_service/models/course_upload_task.dart';

// UI Components
import 'add_course/ui/components/course_app_bar.dart';
import 'add_course/ui/components/uploading_overlay.dart';
import 'add_course/ui/components/keep_alive_wrapper.dart';
import 'add_course/ui/steps/step_0_basic.dart';
import 'add_course/ui/steps/step_1_setup.dart';
import 'add_course/ui/steps/step_2_content.dart';
import 'add_course/ui/steps/step_3_advance.dart';

// External Screen Imports (Keep existing)
import '../content_viewers/image_viewer_screen.dart';
import '../content_viewers/video_player_screen.dart';
import '../content_viewers/pdf_viewer_screen.dart' show PDFViewerScreen;
import 'folder_detail_screen.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> with WidgetsBindingObserver {
  late CourseStateManager state;
  late DraftManager draftManager;
  late ValidationLogic validation;
  late ContentManager contentManager;
  late NavigationLogic navigation;
  late Step0Logic step0Logic;
  late Step1Logic step1Logic;
  late Step2Logic step2Logic;
  late SubmitHandler submitHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    state = CourseStateManager();
    draftManager = DraftManager(state);
    validation = ValidationLogic(state);
    contentManager = ContentManager(state, draftManager);
    navigation = NavigationLogic(state, state.pageController, validation, draftManager, context);
    step0Logic = Step0Logic(state, draftManager);
    step1Logic = Step1Logic(state, draftManager);
    step2Logic = Step2Logic(state, draftManager);
    submitHandler = SubmitHandler(state, validation);

    // Listen to state changes
    state.addListener(() {
      if (mounted) setState(() {});
    });


    // Initial listeners
    state.mrpController.addListener(_calculateFinalPrice);
    state.discountAmountController.addListener(_calculateFinalPrice);
    
    // Auto-save listeners with error clearing
    state.titleController.addListener(() {
      if (state.titleError && state.titleController.text.trim().isNotEmpty) {
        state.titleError = false;
        state.updateState();
      }
      draftManager.saveCourseDraft();
    });
    
    state.descController.addListener(() {
      if (state.descError && state.descController.text.trim().isNotEmpty) {
        state.descError = false;
        state.updateState();
      }
      draftManager.saveCourseDraft();
    });
    
    state.mrpController.addListener(() => _handleFieldChange(() => state.mrpError = false));
    state.discountAmountController.addListener(() => _handleFieldChange(() => state.discountError = false));
    state.whatsappController.addListener(() => _handleFieldChange(() => state.wpGroupLinkError = false));
    state.websiteUrlController.addListener(() => _handleFieldChange(() => state.bigScreenUrlError = false));
    state.specialTagController.addListener(() => draftManager.saveCourseDraft());


    // Load Draft
    draftManager.loadCourseDraft().then((_) {
      if (mounted) state.isInitialLoading = false;
      state.updateState();
    });

    // Background Service Progress Listener
    _initBackgroundService();
  }

  void _initBackgroundService() {
    final service = FlutterBackgroundService();
    service.on('update').listen((event) {
      if (event != null && mounted) {
        final List<dynamic>? queue = event['queue'];
        if (queue != null) {
          state.uploadTasks = queue.map((t) => CourseUploadTask.fromMap(Map<String, dynamic>.from(t))).toList();
          _calculateOverallProgress();
          state.updateState();
        }
      }
    });

    service.on('all_completed').listen((event) {
      if (mounted) {
        state.isUploading = false;
        state.updateState();
      }
    });
  }

  void _handleFieldChange(VoidCallback resetError) {
    resetError();
    draftManager.saveCourseDraft();
  }

  void _calculateFinalPrice() {
    final double mrp = double.tryParse(state.mrpController.text) ?? 0;
    final double discountAmt = double.tryParse(state.discountAmountController.text) ?? 0;

    if (mrp > 0) {
      double finalPrice = mrp - discountAmt;
      if (finalPrice < 0) finalPrice = 0;
      state.finalPriceController.text = finalPrice.round().toString();
    } else {
      state.finalPriceController.text = '0';
    }
  }

  void _calculateOverallProgress() {
    if (state.uploadTasks.isEmpty) return;
    double total = 0;
    for (var task in state.uploadTasks) {
      total += task.progress;
    }
    state.totalProgress = total / state.uploadTasks.length;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    super.dispose();
  }

  // UI Handlers passed to components
  void _handleContentTap(Map<String, dynamic> item, int index) async {
    if (state.isSelectionMode) {
      step2Logic.toggleSelection(index);
      return;
    }

    if (item['type'] == 'folder') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FolderDetailScreen(
            folderName: item['name'] ?? 'Folder',
            contentList: List<Map<String, dynamic>>.from(item['contents'] ?? []),
          ),
        ),
      );

      if (result != null && result is List<Map<String, dynamic>>) {
        state.courseContents[index]['contents'] = result;
        state.updateState();
        draftManager.saveCourseDraft();
      }
    } else if (item['type'] == 'video' || item['type'] == 'image' || item['type'] == 'pdf') {
       _openViewer(item, index);
    }
  }

  void _openViewer(Map<String, dynamic> item, int index) {
    Widget viewer;
    final bool isLocal = item['isLocal'] ?? false;
    final bool isNetwork = !isLocal;

    if (item['type'] == 'video') {
      // Build playlist from all videos in courseContents
      final List<Map<String, dynamic>> videoPlaylist = state.courseContents
          .where((c) => c['type'] == 'video')
          .toList();
      final int videoIndex = videoPlaylist.indexWhere(
          (v) => v['path'] == item['path'] || v['name'] == item['name']);
      viewer = VideoPlayerScreen(
        playlist: videoPlaylist,
        initialIndex: videoIndex >= 0 ? videoIndex : 0,
      );
    } else if (item['type'] == 'image') {
      viewer = ImageViewerScreen(
        filePath: item['path'] ?? '',
        isNetwork: isNetwork,
        title: item['name'],
      );
    } else {
      viewer = PDFViewerScreen(
        filePath: item['path'] ?? '',
        isNetwork: isNetwork,
        title: item['name'],
      );
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => viewer));
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
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                   _buildOptionItem(
                    Icons.create_new_folder,
                    'Folder',
                    Colors.orange,
                    () => contentManager.showCreateFolderDialog(context),
                  ),
                  _buildOptionItem(
                    Icons.video_library,
                    'Video',
                    Colors.red,
                    () => contentManager.pickContentFile(context, 'video', ['mp4', 'mkv', 'avi']),
                  ),
                  _buildOptionItem(
                    Icons.picture_as_pdf,
                    'PDF',
                    Colors.redAccent,
                    () => contentManager.pickContentFile(context, 'pdf', ['pdf']),
                  ),
                  _buildOptionItem(
                    Icons.image,
                    'Image',
                    Colors.purple,
                    () => contentManager.pickContentFile(context, 'image', ['jpg', 'jpeg', 'png', 'webp']),
                  ),
                  _buildOptionItem(
                    Icons.content_paste,
                    'Paste',
                    Colors.grey,
                    () => contentManager.pasteFromClipboard(context),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CourseAppBar(
        state: state,
        currentStep: state.currentStep,
        onCancelSelection: () {
          state.isSelectionMode = false;
          state.selectedIndices.clear();
          state.updateState();
        },
        onSelectAll: () {
          if (state.selectedIndices.length == state.courseContents.length) {
            state.selectedIndices.clear();
          } else {
            state.selectedIndices.clear();
            for (int i = 0; i < state.courseContents.length; i++) {
              state.selectedIndices.add(i);
            }
          }
          state.updateState();
        },
        onBulkCopy: () => contentManager.handleBulkCopyCut(context, false),
        onBulkDelete: () => contentManager.handleBulkDelete(context),
        onAddContent: _showAddContentMenu,
        onCancelDrag: () {
          state.isDragModeActive = false;
          state.updateState();
        },
      ),
      body: Form(
        key: state.formKey,
        child: Stack(
          children: [
            PageView(
              controller: state.pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) {
                state.currentStep = idx;
                state.updateState();
              },
              children: [
                KeepAliveWrapper(
                  child: Step0BasicWidget(
                    state: state,
                    logic: step0Logic,
                    navButtons: _buildNavButtons(),
                    showWarning: _showWarning,
                  ),
                ),
                KeepAliveWrapper(
                  child: Step1SetupWidget(
                    state: state,
                    logic: step1Logic,
                    navButtons: _buildNavButtons(),
                    showWarning: _showWarning,
                  ),
                ),
                KeepAliveWrapper(
                  child: Step2ContentWidget(
                    state: state,
                    logic: step2Logic,
                    contentManager: contentManager,
                    navButtons: _buildNavButtons(),
                    onContentTap: _handleContentTap,
                  ),
                ),
                KeepAliveWrapper(
                  child: Step3AdvanceWidget(
                    state: state,
                    draftManager: draftManager,
                    navButtons: _buildNavButtons(),
                    onEditStep: (step) => navigation.jumpToStep(step),
                  ),
                ),
              ],
            ),
            if (state.isUploading)
              CourseUploadingOverlay(
                totalProgress: state.totalProgress,
                uploadTasks: state.uploadTasks,
              ),
            if (state.isLoading && !state.isUploading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
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

  Widget _buildNavButtons() {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (state.currentStep > 0)
            Expanded(
              child: ElevatedButton(
                onPressed: navigation.prevStep,
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
          if (state.currentStep > 0) const SizedBox(width: 24),
          Expanded(
            child: ElevatedButton(
              onPressed: state.currentStep == 3
                  ? (state.isLoading ? null : () => submitHandler.submitCourse(context, _showWarning))
                  : () => navigation.nextStep(_showWarning),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.0),
                ),
              ),
              child: state.isLoading
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
                        state.currentStep == 3 ? 'Create Course' : 'Next Step',
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
}
