import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/dashboard_provider.dart';
import '../utils/simple_file_explorer.dart';
import '../../services/bunny_cdn_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  bool _isPublished = true;
  bool _isInitialLoading = true;
  int _newBatchDurationDays = 90;
  String _difficulty = 'Beginner'; // Acts as Course Type
  
  final List<String> _difficultyLevels = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> _categories = ['Hardware', 'Software'];

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
         });
         
         // Silent restoration, no SnackBar
      }
    } catch (e) {
       // debugPrint("Error loading draft: $e");
    }
  }

  Future<void> _saveCourseDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> draft = {
         'title': _titleController.text,
         'desc': _descController.text,
         'mrp': _mrpController.text,
         'discount': _discountAmountController.text,
         'category': _selectedCategory,
         'difficulty': _difficulty,
         'contents': _courseContents,
      };
      
      await prefs.setString('course_creation_draft', jsonEncode(draft));
      // debugPrint("Course Draft Saved");
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
    }
  }
  


  bool _validateCurrentStep() {
    return true; // DEV MODE: Bypass Validation
  }

  void _nextStep() async {
    if (_validateCurrentStep()) {
      if (_currentStep < 2) {
        FocusScope.of(context).unfocus();
        await Future.delayed(const Duration(milliseconds: 50));
        await _pageController.nextPage(duration: 250.ms, curve: Curves.easeInOut);
      }
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
    if (!_validateCurrentStep()) return; 

    setState(() => _isLoading = true);

    try {
      final String thumbnailUrl = await _bunnyService.uploadImage(
        filePath: _thumbnailImage!.path,
        folder: 'thumbnails',
      );

      final String finalDesc = _descController.text.trim();
      /*
      // Syllabus logic deprecated
      */

      final newCourse = CourseModel(
        id: '', 
        title: _titleController.text.trim(),
        category: _selectedCategory!, 
        price: int.parse(_finalPriceController.text), // Selling Price
        discountPrice: int.parse(_mrpController.text), // MRP (High Price)
        description: finalDesc,
        thumbnailUrl: thumbnailUrl,
        duration: _durationController.text.trim(),
        difficulty: _difficulty,
        enrolledStudents: 0,
        rating: 0.0,
        totalVideos: 0,
        isPublished: _isPublished,
        createdAt: DateTime.now(),
        newBatchDays: _newBatchDurationDays,
      );

      if (mounted) {
        await Provider.of<DashboardProvider>(context, listen: false).addCourse(newCourse);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course Created Successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _saveCourseDraft();
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
        appBar: _buildAppBar(),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (idx) {
                    setState(() => _currentStep = idx);
                  },
                  children: [
                    KeepAliveWrapper(child: _buildStep1Basic()),
                    KeepAliveWrapper(child: _buildStep2Content()),
                    KeepAliveWrapper(child: _buildStep3Advance()),
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
                        border: Border.all(color: _thumbnailImage == null ? Colors.grey.shade300 : AppTheme.primaryColor.withValues(alpha: 0.5), width: _thumbnailImage == null ? 1 : 2),
                        image: _thumbnailImage != null
                            ? DecorationImage(image: FileImage(_thumbnailImage!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _thumbnailImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded, size: 48, color: AppTheme.primaryColor.withValues(alpha: 0.8)),
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
                               BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))
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
            decoration: const InputDecoration(hintText: 'Enter new name', border: OutlineInputBorder()),
            autofocus: true,
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
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
              children: [
                 _buildTextField(controller: _durationController, label: 'Total Duration (e.g. 12 Hours)', icon: Icons.timer),
                 const SizedBox(height: 20),
                 SwitchListTile(
                   title: const Text('Publish Course', maxLines: 1, overflow: TextOverflow.ellipsis),
                   subtitle: const Text('Visible to students immediately', maxLines: 1, overflow: TextOverflow.ellipsis),
                   value: _isPublished,
                   onChanged: (v) => setState(() => _isPublished = v),
                   activeThumbColor: AppTheme.primaryColor,
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
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 70,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}


