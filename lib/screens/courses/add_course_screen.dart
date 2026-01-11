import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/bunny_cdn_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_theme.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

// Global Clipboard for Cross-Folder Operations
List<Map<String, dynamic>>? _globalClipboardItems;
String _globalClipboardAction = '';

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
  int _newBatchDurationDays = 90;
  String _difficulty = 'Beginner'; // Acts as Course Type
  
  final List<String> _difficultyLevels = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> _categories = ['Hardware', 'Software'];

  @override
  void initState() {
    super.initState();
    _mrpController.addListener(_calculateFinalPrice);
    _discountAmountController.addListener(_calculateFinalPrice);
  }

  void _calculateFinalPrice() {
    double mrp = double.tryParse(_mrpController.text) ?? 0;
    double discountAmt = double.tryParse(_discountAmountController.text) ?? 0;
    
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

    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      var decodedImage = await decodeImageFromList(file.readAsBytesSync());
      
      // Validation: Check for 16:9 Ratio (approx 1.77) with tolerance
      double ratio = decodedImage.width / decodedImage.height;
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
    /* 
    if (_currentStep == 0) {
      if (_titleController.text.isEmpty || 
          _mrpController.text.isEmpty || 
          _descController.text.isEmpty ||
          _selectedCategory == null || 
          _thumbnailImage == null) {
        
        String msg = 'Please fill all fields';
        if (_thumbnailImage == null) msg = 'Please upload a 16:9 Image';
        else if (_descController.text.isEmpty) msg = 'Description is required';
        
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(msg), backgroundColor: Colors.red)
        );
        return false;
      }
    }
    return true;
    */
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 2) {
        _pageController.nextPage(duration: 300.ms, curve: Curves.easeInOut);
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: 300.ms, curve: Curves.easeInOut);
    }
  }

  Future<void> _submitCourse() async {
    if (!_validateCurrentStep()) return; 

    setState(() => _isLoading = true);

    try {
      String thumbnailUrl = await _bunnyService.uploadImage(
        filePath: _thumbnailImage!.path,
        folder: 'thumbnails',
      );

      String finalDesc = _descController.text.trim();
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
    return Scaffold(
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Step Indicator (Visible only in Normal Mode)
            AnimatedSize(
              duration: 300.ms,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                child: (!_isDragModeActive && !_isSelectionMode)
                   ? Container(
                       padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                       decoration: BoxDecoration(
                         color: Theme.of(context).cardColor,
                       ),
                       child: _buildStepIndicator(),
                     )
                   : const SizedBox.shrink(),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) {
                   setState(() => _currentStep = idx);
                },
                children: [
                  _buildStep1Basic(),
                  _buildStep2Content(),
                  _buildStep3Advance(),
                ],
              ),
            ),
          ],
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
         title: const Text('Drag and Drop Mode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
            onPressed: () => setState(() => _isSelectionMode = false),
          ),
          title: Text('${_selectedIndices.length} Selected', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          actions: [
            TextButton(
                onPressed: _courseContents.length == _selectedIndices.length ? () => setState(() => _selectedIndices.clear()) : _selectAll,
                child: Text(_courseContents.length == _selectedIndices.length ? 'Unselect All' : 'Select All', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
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

  Widget _buildStepIndicator() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepCircle(0, 'Basic Info'),
          _buildStepLine(0),
          _buildStepCircle(1, 'Contents'),
          _buildStepLine(1),
          _buildStepCircle(2, 'Advance'),
        ],
      );
  }




  
  Widget _buildStepCircle(int step, String label) {
    bool isActive = _currentStep >= step;
    bool isCurrent = _currentStep == step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: 300.ms,
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.grey.withOpacity(0.2),
            shape: BoxShape.circle,
            boxShadow: isActive ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Center(
            child: isCurrent 
              ? const Icon(Icons.edit, size: 16, color: Colors.white)
              : isActive ? const Icon(Icons.check, size: 16, color: Colors.white) : Text('${step + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(
          fontSize: 11, 
          color: isActive ? AppTheme.primaryColor : Colors.grey.shade500,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
        )),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: _currentStep > step ? AppTheme.primaryColor.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildNavButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 24),
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
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_currentStep == 2 ? 'Create Course' : 'Next Step', style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEPS REWRITTEN ---

  Widget _buildStep1Basic() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
            // No icon as requested
            maxLines: 5,
            alignTop: true, 
          ),

          // 4. Pricing (Row of 3)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Expanded(child: _buildTextField(controller: _mrpController, label: 'MRP', icon: Icons.currency_rupee, keyboardType: TextInputType.number)),
               const SizedBox(width: 8),
               Expanded(child: _buildTextField(controller: _discountAmountController, label: 'Discount ₹', icon: Icons.remove_circle_outline, keyboardType: TextInputType.number)),
               const SizedBox(width: 8),
               Expanded(child: _buildTextField(controller: _finalPriceController, label: 'Final', icon: Icons.currency_rupee, keyboardType: TextInputType.number, readOnly: true)),
            ],
          ),

          // 5. Category & Type
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(labelText: 'Category', floatingLabelBehavior: FloatingLabelBehavior.always, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).cardColor),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _difficulty,
                  decoration: InputDecoration(labelText: 'Course Type', floatingLabelBehavior: FloatingLabelBehavior.always, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).cardColor),
                  items: _difficultyLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (v) => setState(() => _difficulty = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<int>(
             value: _newBatchDurationDays,
             decoration: InputDecoration(labelText: 'New Badge Duration', floatingLabelBehavior: FloatingLabelBehavior.always, prefixIcon: const Icon(Icons.timer_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).cardColor),
             items: const [DropdownMenuItem(value: 30, child: Text('1 Month')), DropdownMenuItem(value: 60, child: Text('2 Months')), DropdownMenuItem(value: 90, child: Text('3 Months'))],
             onChanged: (v) => setState(() => _newBatchDurationDays = v!),
          ),

          // BUTTONS
          _buildNavButtons(),
        ],
      ),
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
            if (_selectedIndices.isEmpty) _isSelectionMode = false;
         } else {
            _selectedIndices.add(index);
         }
      });
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.clear();
      for(int i=0; i<_courseContents.length; i++) _selectedIndices.add(i);
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
                       if (i < _courseContents.length) _courseContents.removeAt(i);
                    }
                    _isSelectionMode = false;
                    _selectedIndices.clear();
                 });
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
      List<Map<String, dynamic>> itemsToCopy = [];
      for (int i in indices) {
         if (i < _courseContents.length) itemsToCopy.add(_courseContents[i]);
      }
      
      setState(() {
         // Deep Copy to Global Clipboard
         _globalClipboardItems = itemsToCopy.map((e) => Map<String, dynamic>.from(jsonDecode(jsonEncode(e)))).toList();
         _globalClipboardAction = isCut ? 'cut' : 'copy';
         
         if (isCut) {
            final List<int> revIndices = indices.reversed.toList();
            for (int i in revIndices) {
               _courseContents.removeAt(i);
            }
            _isSelectionMode = false;
            _selectedIndices.clear();
         } else {
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

  void _handleContentTap(Map<String, dynamic> item, int index) {
      if (_isSelectionMode) {
         _toggleSelection(index);
      } else if (item['type'] == 'folder') {
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (_) => FolderDetailScreen(
              folderName: item['name'],
              contentList: (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [],
            )
          )
        ).then((_) => setState((){}));
      }
  }

  Widget _buildStep2Content() {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
              sliver: _courseContents.isEmpty 
                  ? SliverToBoxAdapter(
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
                      itemCount: _courseContents.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final item = _courseContents[index];
                        final isSelected = _selectedIndices.contains(index);
                        
                        IconData icon;
                        Color color;
                        switch(item['type']) {
                          case 'folder': icon = Icons.folder; color = Colors.orange; break;
                          case 'video': icon = Icons.video_library; color = Colors.red; break;
                          case 'pdf': icon = Icons.picture_as_pdf; color = Colors.redAccent; break;
                          case 'image': icon = Icons.image; color = Colors.purple; break;
                          case 'zip': icon = Icons.folder_zip; color = Colors.blueGrey; break;
                          default: icon = Icons.insert_drive_file; color = Colors.blue;
                        }

                        return Material(
                          key: ObjectKey(item),
                          color: Colors.transparent,
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  tileColor: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Theme.of(context).cardColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12), 
                                    side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200, width: isSelected ? 2 : 1)
                                  ),
                                  leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
                                  title: Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppTheme.primaryColor : null)),
                                  trailing: _isSelectionMode
                                    ? (isSelected 
                                        ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
                                        : Icon(Icons.circle_outlined, color: Colors.grey))
                                    : const SizedBox(width: 48), 
                                ),
                              ),

                              if (!_isSelectionMode)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 12,
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (value) {
                                    if (value == 'rename') _renameContent(index);
                                    if (value == 'remove') _confirmRemoveContent(index);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 12), Text('Rename')])),
                                    const PopupMenuItem(value: 'remove', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 12), Text('Remove', style: TextStyle(color: Colors.red))])),
                                  ],
                                ),
                              ),
                            
                              Positioned.fill(
                              bottom: 12,
                              child: _isDragModeActive 
                                ? Row(
                                    children: [
                                       const SizedBox(width: 60), // Left Scroll Zone
                                       Expanded(
                                         child: ReorderableDragStartListener(
                                           index: index,
                                           child: Container(color: Colors.transparent),
                                         ),
                                       ),
                                       const SizedBox(width: 60), // Right Scroll Zone
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTapDown: (_) => _startHoldTimer(),
                                          onTapUp: (_) => _cancelHoldTimer(),
                                          onTapCancel: () => _cancelHoldTimer(),
                                          onTap: () => _handleContentTap(item, index),
                                          child: Container(color: Colors.transparent),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onLongPress: () => _enterSelectionMode(index),
                                          onTap: () => _handleContentTap(item, index),
                                          child: Container(color: Colors.transparent),
                                        ),
                                      ),
                                      const SizedBox(width: 48),
                                    ],
                                  ),
                            ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                   const SizedBox(height: 24),
                   _buildNavButtons(),
                ]),
              ),
            ),
          ],
        ),


        if (!_isSelectionMode && !_isDragModeActive)
            Positioned(
              top: 12,
              right: 24,
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
      ],
    );
  }

  void _renameContent(int index) {
      TextEditingController renameController = TextEditingController(text: _courseContents[index]['name']);
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
              setState(() {
                _courseContents.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Legacy fallback for simple copy
  void _handleClipboardAction(String action) {
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Long press items to select multiple, then use top menu.')));
  }

  void _pasteContent() {
    if (_globalClipboardItems == null || _globalClipboardItems!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
      return;
    }

    setState(() {
      for (var item in _globalClipboardItems!) {
         var newItem = Map<String, dynamic>.from(jsonDecode(jsonEncode(item)));
         newItem['name'] = '${newItem['name']} (Copy)';
         _courseContents.add(newItem);
      }
    });
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_globalClipboardItems!.length} items pasted')));
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
                  _buildOptionItem(Icons.video_library, 'Video', Colors.red, () => _pickContentFile('video', FileType.custom, ['mp4', 'mkv'])),
                  _buildOptionItem(Icons.picture_as_pdf, 'PDF', Colors.redAccent, () => _pickContentFile('pdf', FileType.custom, ['pdf'])),
                  _buildOptionItem(Icons.image, 'Image', Colors.purple, () => _pickContentFile('image', FileType.custom, ['jpg', 'jpeg', 'png', 'webp'])),
                  _buildOptionItem(Icons.folder_zip, 'Zip', Colors.blueGrey, () => _pickContentFile('zip', FileType.custom, ['zip', 'rar'])),
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
                  _courseContents.add({
                    'type': 'folder', 
                    'name': folderNameController.text.trim(),
                    'contents': <Map<String, dynamic>>[], // Initialize contents list
                  });
                });
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

  // File Picker Logic
  Future<void> _pickContentFile(String type, FileType fileType, [List<String>? allowedExtensions]) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: true, 
      );

      if (result != null) {
        List<String> invalidFiles = [];
        setState(() {
          for (var file in result.files) {
             if (file.path == null) continue;

             String ext = file.extension?.toLowerCase() ?? '';
             if (allowedExtensions != null && !allowedExtensions.contains(ext)) {
                 invalidFiles.add(file.name);
                 continue;
             }

             _courseContents.add({
                'type': type,
                'name': file.name,
                'path': file.path,
             });
          }
        });

        if (mounted && invalidFiles.isNotEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('Skipped ${invalidFiles.length} invalid files.'), 
             backgroundColor: Colors.orange
           ));
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }



  Widget _buildStep3Advance() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
           _buildTextField(controller: _durationController, label: 'Total Duration (e.g. 12 Hours)', icon: Icons.timer),
           const SizedBox(height: 20),
           SwitchListTile(
             title: const Text('Publish Course'),
             subtitle: const Text('Make this course visible to students immediately'),
             value: _isPublished,
             onChanged: (v) => setState(() => _isPublished = v),
             activeColor: AppTheme.primaryColor,
           ),
           
           _buildNavButtons(),
        ],
      ),
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
          color: readOnly ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) : Theme.of(context).textTheme.bodyMedium?.color,
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
              ? (Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100)
              : Theme.of(context).cardColor,
          counterText: maxLength != null ? null : '',
        ),
      ),
    );
  }
}

class _StepIndicatorDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget Function(double shrinkage) childBuilder;

  _StepIndicatorDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.childBuilder,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Calculate shrinkage factor (0.0 to 1.0)
    double shrinkage = (shrinkOffset / (maxHeight - minHeight)).clamp(0.0, 1.0);
    
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      // Use Align to ensure content stays centered/bottom as it shrinks
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        // Ensure height never goes below minHeight to prevent overflow
        height: (maxHeight - shrinkOffset).clamp(minHeight, maxHeight),
        child: childBuilder(shrinkage),
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant _StepIndicatorDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxExtent || 
           minHeight != oldDelegate.minExtent;
  }
}




class FolderDetailScreen extends StatefulWidget {
  final String folderName;
  final List<Map<String, dynamic>> contentList;

  const FolderDetailScreen({super.key, required this.folderName, required this.contentList});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  late List<Map<String, dynamic>> _contents;
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _contents = widget.contentList;
  }

  void _refresh() => setState(() {});

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
            if (_selectedIndices.isEmpty) _isSelectionMode = false;
         } else {
            _selectedIndices.add(index);
         }
      });
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.clear();
      for(int i=0; i<_contents.length; i++) _selectedIndices.add(i);
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
                       if (i < _contents.length) _contents.removeAt(i);
                    }
                    _isSelectionMode = false;
                    _selectedIndices.clear();
                 });
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
      List<Map<String, dynamic>> itemsToCopy = [];
      for (int i in indices) {
         if (i < _contents.length) itemsToCopy.add(_contents[i]);
      }
      
      setState(() {
         // Deep Copy to Global Clipboard
         _globalClipboardItems = itemsToCopy.map((e) => Map<String, dynamic>.from(jsonDecode(jsonEncode(e)))).toList();
         _globalClipboardAction = isCut ? 'cut' : 'copy';
         
         if (isCut) {
            final List<int> revIndices = indices.reversed.toList();
            for (int i in revIndices) {
               _contents.removeAt(i);
            }
            _isSelectionMode = false;
            _selectedIndices.clear();
         } else {
            _isSelectionMode = false;
            _selectedIndices.clear();
         }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${itemsToCopy.length} items ${isCut ? 'Cut' : 'Copied'}')));
  }
 
  void _renameContent(int index) {
      TextEditingController renameController = TextEditingController(text: _contents[index]['name']);
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
                    _contents[index]['name'] = renameController.text.trim();
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

  void _confirmRemoveContent(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Content'),
        content: Text('Are you sure you want to remove "${_contents[index]['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _contents.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Legacy fallback for simple copy
  void _handleClipboardAction(String action) {
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Long press items to select multiple, then use top menu.')));
  }

  void _pasteContent() {
    if (_globalClipboardItems == null || _globalClipboardItems!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
      return;
    }

    setState(() {
      for (var item in _globalClipboardItems!) {
         var newItem = Map<String, dynamic>.from(jsonDecode(jsonEncode(item)));
         newItem['name'] = '${newItem['name']} (Copy)';
         _contents.add(newItem);
      }
    });
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_globalClipboardItems!.length} items pasted')));
  }

  IconData _getIconForType(String type) {
    switch(type) {
      case 'folder': return Icons.folder;
      case 'video': return Icons.video_library;
      case 'pdf': return Icons.picture_as_pdf;
      case 'image': return Icons.image;
      case 'zip': return Icons.folder_zip;
      default: return Icons.insert_drive_file;
    }
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
                  _contents.add({
                    'type': 'folder', 
                    'name': folderNameController.text.trim(),
                    'contents': <Map<String, dynamic>>[],
                  });
                });
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

  Future<void> _pickContentFile(String type, FileType fileType, [List<String>? allowedExtensions]) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: true, 
      );

      if (result != null) {
        List<String> invalidFiles = [];
        setState(() {
          for (var file in result.files) {
             if (file.path == null) continue;

             String ext = file.extension?.toLowerCase() ?? '';
             if (allowedExtensions != null && !allowedExtensions.contains(ext)) {
                 invalidFiles.add(file.name);
                 continue;
             }

             _contents.add({
                'type': type,
                'name': file.name,
                'path': file.path,
             });
          }
        });

        if (mounted && invalidFiles.isNotEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('Skipped ${invalidFiles.length} invalid files.'), 
             backgroundColor: Colors.orange
           ));
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add to Folder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildOptionItem(Icons.create_new_folder, 'Folder', Colors.orange, () => _showCreateFolderDialog()),
                  _buildOptionItem(Icons.video_library, 'Video', Colors.red, () => _pickContentFile('video', FileType.custom, ['mp4', 'mkv'])),
                  _buildOptionItem(Icons.picture_as_pdf, 'PDF', Colors.redAccent, () => _pickContentFile('pdf', FileType.custom, ['pdf'])),
                  _buildOptionItem(Icons.image, 'Image', Colors.purple, () => _pickContentFile('image', FileType.custom, ['jpg', 'jpeg', 'png', 'webp'])),
                  _buildOptionItem(Icons.folder_zip, 'Zip', Colors.blueGrey, () => _pickContentFile('zip', FileType.custom, ['zip', 'rar'])),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode 
         ? AppBar(
             backgroundColor: AppTheme.primaryColor,
             iconTheme: const IconThemeData(color: Colors.white),
             leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedIndices.clear(); })),
             title: Text('${_selectedIndices.length} Selected', style: const TextStyle(color: Colors.white, fontSize: 18)),
             actions: [
                TextButton(
                    onPressed: _contents.length == _selectedIndices.length ? () => setState(() => _selectedIndices.clear()) : _selectAll,
                    child: Text(
                      _contents.length == _selectedIndices.length ? 'Unselect All' : 'Select All',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                    )
                ),
                TextButton(
                    onPressed: () => _handleBulkCopyCut(false),
                    child: const Text('Copy', style: TextStyle(color: Colors.white))
                ),
                IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete, color: Colors.red), onPressed: _handleBulkDelete),
             ],
           )
         : AppBar(
             title: Text(widget.folderName),
           ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
            child: _contents.isEmpty 
              ? Container(
                  height: 300,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Empty Folder', style: TextStyle(color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _contents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _contents[index];
                    final isSelected = _selectedIndices.contains(index);
                    IconData icon;
                    Color color;
                    
                    switch(item['type']) {
                      case 'folder': icon = Icons.folder; color = Colors.orange; break;
                      case 'video': icon = Icons.video_library; color = Colors.red; break;
                      case 'pdf': icon = Icons.picture_as_pdf; color = Colors.redAccent; break;
                      case 'image': icon = Icons.image; color = Colors.purple; break;
                      case 'zip': icon = Icons.folder_zip; color = Colors.blueGrey; break;
                      default: icon = Icons.insert_drive_file; color = Colors.blue;
                    }

                    return ListTile(
                      tileColor: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), 
                        side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200, width: isSelected ? 2 : 1)
                      ),
                      onLongPress: () => _enterSelectionMode(index),
                      onTap: () {
                          if (_isSelectionMode) {
                             _toggleSelection(index);
                          } else if (item['type'] == 'folder') {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (_) => FolderDetailScreen(
                                  folderName: item['name'],
                                  contentList: (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [],
                                )
                              )
                            ).then((_) => _refresh());
                          }
                      },
                      leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
                      title: Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppTheme.primaryColor : null)),
                      trailing: _isSelectionMode
                        ? (isSelected 
                            ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
                            : Icon(Icons.circle_outlined, color: Colors.grey))
                        : PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          if (value == 'rename') _renameContent(index);
                          if (value == 'remove') _confirmRemoveContent(index);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'rename', 
                            child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 12), Text('Rename')])
                          ),
                          const PopupMenuItem(
                            value: 'remove', 
                            child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 12), Text('Remove', style: TextStyle(color: Colors.red))])
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
          
          if (!_isSelectionMode)
            Positioned(
              top: 10,
              right: 24,
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
        ],
      ),
    );
  }
}
