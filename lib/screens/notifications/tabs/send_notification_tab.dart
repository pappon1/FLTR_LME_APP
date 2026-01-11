import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart'; // Added Vibration
import '../../../services/firestore_service.dart';
import '../../../services/bunny_cdn_service.dart';
import '../../../utils/app_theme.dart';
import '../sent_history_screen.dart';

class SendNotificationTab extends StatefulWidget {
  const SendNotificationTab({super.key});

  @override
  State<SendNotificationTab> createState() => _SendNotificationTabState();
}

class _SendNotificationTabState extends State<SendNotificationTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _actionValueController = TextEditingController();
  
  final BunnyCDNService _bunnyCDNService = BunnyCDNService();
  
  String _selectedAudience = 'Select Users';
  List<String> _selectedCourseIds = [];
  
  File? _selectedImage;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isSending = false;

  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  String _selectedAction = 'Open App';

  // For 0.8 Second Hold Logic
  Timer? _holdTimer;

  bool get _hasContent {
    return _titleController.text.trim().isNotEmpty ||
           _messageController.text.trim().isNotEmpty ||
           _selectedImage != null ||
           _actionValueController.text.trim().isNotEmpty ||
           _isScheduled;
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _actionValueController.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _titleController.text = prefs.getString('draft_title') ?? '';
      _messageController.text = prefs.getString('draft_description') ?? '';
      _selectedAction = prefs.getString('draft_action') ?? 'Open App';
      _actionValueController.text = prefs.getString('draft_action_value') ?? '';
      _selectedAudience = prefs.getString('draft_audience') ?? 'Select Users';
      _selectedCourseIds = prefs.getStringList('draft_course_ids') ?? [];
      
      final imagePath = prefs.getString('draft_image_path');
      if (imagePath != null && File(imagePath).existsSync()) {
        _selectedImage = File(imagePath);
      }
      
      _isScheduled = prefs.getBool('draft_is_scheduled') ?? false;
      final dateStr = prefs.getString('draft_scheduled_date');
      final timeStr = prefs.getString('draft_scheduled_time');
      
      if (_isScheduled && dateStr != null && timeStr != null) {
        _scheduledDate = DateTime.parse(dateStr);
        final parts = timeStr.split(':');
        _scheduledTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_title', _titleController.text);
    await prefs.setString('draft_description', _messageController.text);
    await prefs.setString('draft_action', _selectedAction);
    await prefs.setString('draft_action_value', _actionValueController.text);
    await prefs.setString('draft_audience', _selectedAudience);
    await prefs.setStringList('draft_course_ids', _selectedCourseIds);
    if (_selectedImage != null) {
      await prefs.setString('draft_image_path', _selectedImage!.path);
    } else {
      await prefs.remove('draft_image_path');
    }
    await prefs.setBool('draft_is_scheduled', _isScheduled);
    if (_scheduledDate != null) await prefs.setString('draft_scheduled_date', _scheduledDate!.toIso8601String());
    if (_scheduledTime != null) await prefs.setString('draft_scheduled_time', '${_scheduledTime!.hour}:${_scheduledTime!.minute}');
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_title');
    await prefs.remove('draft_description');
    await prefs.remove('draft_action');
    await prefs.remove('draft_action_value');
    await prefs.remove('draft_audience');
    await prefs.remove('draft_course_ids');
    await prefs.remove('draft_image_path');
    await prefs.remove('draft_is_scheduled');
    await prefs.remove('draft_scheduled_date');
    await prefs.remove('draft_scheduled_time');
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final file = File(image.path);
      final decodedImage = await decodeImageFromList(await file.readAsBytes());
      
      if (decodedImage.width != 1280 || decodedImage.height != 720) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid Size. Required: 1280x720 (16:9).'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedImage = file;
      });
      _saveDraft();
    }
  }

  void _confirmRemoveImage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Image?'),
        content: const Text('Are you sure you want to remove the selected image?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(
            onPressed: () {
               setState(() {
                 _selectedImage = null;
               });
               _saveDraft();
               Navigator.pop(context);
            },
            child: const Text('Yes, Remove', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startHoldTimer() {
    if (_selectedImage == null) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 800), () async { // 0.8 Seconds
      if (mounted) {
        if (await Vibration.hasVibrator() ?? false) {
           Vibration.vibrate(duration: 100, amplitude: 128);
        }
        _confirmRemoveImage();
      }
    });
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
  }

  Future<void> _selectDate() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryColor, brightness: Theme.of(context).brightness),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
        _scheduledTime = null; 
        _isScheduled = true;
      });
      _selectTime();
    } else {
       if (_scheduledDate == null) {
          setState(() {
            _isScheduled = false;
          });
       }
    }
    _saveDraft();
  }

  Future<void> _selectTime() async {
    if (_scheduledDate == null) {
       setState(() { _isScheduled = false; });
       return;
    }

    FocusScope.of(context).unfocus();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
         return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryColor, brightness: Theme.of(context).brightness),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final DateTime combined = DateTime(_scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day, picked.hour, picked.minute);

      if (combined.isBefore(DateTime.now())) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot schedule in the past! Please select a future time.'), backgroundColor: Colors.red));
           setState(() {
             _scheduledTime = null;
           });
         }
         return;
      }
      setState(() => _scheduledTime = picked);
    } else {
      if (_scheduledTime == null) {
         setState(() {
           _isScheduled = false;
           _scheduledDate = null;
         });
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule canceled (Time not selected).')));
      }
    }
    _saveDraft();
  }

  Future<void> _processNotification() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_isScheduled && (_scheduledDate == null || _scheduledTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both Date and Time for scheduling or turn off Schedule mode.'), backgroundColor: Colors.red));
      return;
    }
    // Validation for Action Value
    if ((_selectedAction == 'Specific Course' || _selectedAction == 'Custom URL') && _actionValueController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Course or enter a URL.'), backgroundColor: Colors.red));
        return;
    }
    
    // Internet Check
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw SocketException('No Internet');
      }
    } on SocketException catch (_) {
      SnackBarAction? action = SnackBarAction(label: 'Retry', onPressed: _processNotification);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('No Internet Connection! Please check your network.'), backgroundColor: Colors.red, action: action));
      return;
    }
    
    // Mandatory Audience Validation
    if ((_selectedAudience == 'Select Users' || _selectedAudience.isEmpty) && _selectedCourseIds.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
         content: Text('⚠️ Please select Users (Audience) to proceed!'), 
         backgroundColor: Colors.red,
         behavior: SnackBarBehavior.floating,
       ));
       return;
    }

    setState(() => _isSending = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        setState(() => _isUploading = true);
        imageUrl = await _bunnyCDNService.uploadImage(
          filePath: _selectedImage!.path,
          folder: 'notifications',
          onProgress: (sent, total) => setState(() => _uploadProgress = sent / total),
        );
        setState(() => _isUploading = false);
      }

      final DateTime? scheduledDateTime = _isScheduled && _scheduledDate != null && _scheduledTime != null
          ? DateTime(_scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day, _scheduledTime!.hour, _scheduledTime!.minute)
          : null;

      String actionType = 'home'; // Default
      if (_selectedAction == 'Open App Home') actionType = 'home';
      else if (_selectedAction == 'Open Courses Screen') actionType = 'courses';
      else if (_selectedAction == 'Specific Course') actionType = 'course';
      else if (_selectedAction == 'Custom URL') actionType = 'link';

      final notificationData = {
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'imageUrl': imageUrl,
        'targetAudience': _selectedCourseIds.isNotEmpty ? 'course_specific' : _selectedAudience,
        'targetCourseIds': _selectedCourseIds,
        'createdAt': FieldValue.serverTimestamp(),
        'status': _isScheduled ? 'scheduled' : 'sent',
        'scheduledAt': scheduledDateTime != null ? Timestamp.fromDate(scheduledDateTime) : null,
        'sentAt': !_isScheduled ? FieldValue.serverTimestamp() : null,
        'action': actionType,
        'actionValue': _actionValueController.text.trim(),
      };

      await FirebaseFirestore.instance.collection('notifications').add(notificationData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isScheduled ? 'Notification Scheduled! 📅' : 'Notification Sent! 🚀'),
            backgroundColor: Colors.green));
        _resetForm();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSending = false; _isUploading = false; });
    }
  }

  void _resetForm() {
    _titleController.clear();
    _messageController.clear();
    _actionValueController.clear();
    setState(() {
      _selectedImage = null;
      _uploadProgress = 0.0;
      _isScheduled = false;
      _scheduledDate = null;
      _scheduledTime = null;
      _selectedAction = 'Open App';
    });
    _clearDraft(); // Clear persistent draft
  }

  void _showAudienceSelector() {
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Internal state for the sheet
    String? tempSegment;
    // Map current _selectedAudience to segment
    if (_selectedAudience == 'All App Downloads') tempSegment = 'all';
    else if (_selectedAudience == 'All New App Downloads') tempSegment = 'new';
    else if (_selectedAudience == 'Not purchased any course') tempSegment = 'non_purchasers';
    else if (_selectedCourseIds.isNotEmpty) {
      tempSegment = null; // Custom/Courses
    } else {
      tempSegment = null; // Default 'Select Users' (None selected)
    }
    
    List<String> tempCourseIds = List.from(_selectedCourseIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                   // Header
                   Container(
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
                     child: const Center(child: Text('Select Users', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                   ),
                   
                   Expanded(
                     child: ListView(
                       padding: EdgeInsets.zero,
                       children: [
                         // Section 1: APP DOWNLOADS
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           color: isDark ? Colors.grey[900] : Colors.grey[200],
                           child: Text('APP DOWNLOADS', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
                         ),
                         RadioListTile<String>(
                           title: const Text('All App Downloads'),
                           value: 'all',
                           groupValue: tempSegment,
                           activeColor: Colors.red,
                           onChanged: (val) {
                             setSheetState(() {
                               tempSegment = val;
                               tempCourseIds.clear();
                             });
                           },
                         ),
                         RadioListTile<String>(
                           title: const Text('All New App Downloads'),
                           value: 'new',
                           groupValue: tempSegment,
                           activeColor: Colors.red,
                           onChanged: (val) {
                             setSheetState(() {
                               tempSegment = val;
                               tempCourseIds.clear();
                             });
                           },
                         ),
                         RadioListTile<String>(
                           title: const Text('Not purchased any course'),
                           value: 'non_purchasers',
                           groupValue: tempSegment,
                           activeColor: Colors.red,
                           onChanged: (val) {
                             setSheetState(() {
                               tempSegment = val;
                               tempCourseIds.clear();
                             });
                           },
                         ),
                         
                         // Section 2: COURSES
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           color: isDark ? Colors.grey[900] : Colors.grey[200],
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Text('COURSES (${tempCourseIds.length} Selected)', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
                               const Text('View All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                             ],
                           ),
                         ),
                         
                         StreamBuilder<QuerySnapshot>(
                           stream: FirebaseFirestore.instance.collection('courses').snapshots(),
                           builder: (context, snapshot) {
                             if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                             
                             final courses = snapshot.data!.docs;
                             if (courses.isEmpty) {
                               return const Padding(
                                 padding: EdgeInsets.all(16.0),
                                 child: Center(child: Text('No courses found.')),
                               );
                             }
                             
                             return Column(
                               children: courses.map((doc) {
                                 final data = doc.data() as Map<String, dynamic>;
                                 final id = doc.id;
                                 final title = data['title'] ?? 'Untitled Course';
                                 final isSelected = tempCourseIds.contains(id);
                                 
                                 return CheckboxListTile(
                                   title: Text(title),
                                   value: isSelected,
                                   activeColor: Colors.red,
                                   onChanged: (val) {
                                     setSheetState(() {
                                       if (val == true) {
                                         tempCourseIds.add(id);
                                         tempSegment = null; // Clear segment if specific course selected
                                       } else {
                                         tempCourseIds.remove(id);
                                       }
                                     });
                                   },
                                 );
                               }).toList(),
                             );
                           },
                         ),
                       ],
                     ),
                   ),
                   
                   // Buttons (Cancel / Done)
                   SafeArea(
                     top: false,
                     child: Padding(
                       padding: const EdgeInsets.all(16),
                       child: Row(
                         children: [
                           Expanded(
                             child: SizedBox(
                               height: 50,
                               child: OutlinedButton(
                                 style: OutlinedButton.styleFrom(
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                   side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
                                 ),
                                 onPressed: () => Navigator.pop(context),
                                 child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                               ),
                             ),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: SizedBox(
                               height: 50,
                               child: ElevatedButton(
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.red, 
                                   foregroundColor: Colors.white, 
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                 ),
                                 onPressed: () {
                                   if (tempSegment == null && tempCourseIds.isEmpty) {
                                      // Allow Done but it's empty (Validation happens on Send)
                                      setState(() {
                                        _selectedCourseIds = [];
                                        _selectedAudience = 'Select Users';
                                      });
                                   } else {
                                     setState(() {
                                       _selectedCourseIds = tempCourseIds;
                                       if (tempSegment != null) {
                                         if (tempSegment == 'all') _selectedAudience = 'All App Downloads';
                                         if (tempSegment == 'new') _selectedAudience = 'All New App Downloads';
                                         if (tempSegment == 'non_purchasers') _selectedAudience = 'Not purchased any course';
                                       } else {
                                         if (tempCourseIds.length == 1) _selectedAudience = '1 Course Selected';
                                         else _selectedAudience = '${tempCourseIds.length} Courses Selected';
                                       }
                                     });
                                   }
                                   _saveDraft();
                                   Navigator.pop(context);
                                 },
                                 child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                               ),
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Old helper for reference (will be removed by Replacement)
  Widget _buildAudienceOption_REMOVED(BuildContext context, String title, IconData icon, String subtitle, bool isSelected) {
    return Container(); 
  }

  void _showActionSelector() {
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Internal state
    String tempAction = _selectedAction;
    String tempValue = _actionValueController.text;
    
    // Normalize old defaults
    if (tempAction == 'Open App') tempAction = 'Open App Home';
    if (tempAction == 'Open Link') tempAction = 'Custom URL';
    // Mapping from old incomplete states if any
    if (tempAction == 'Open Course') tempAction = 'Specific Course';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                   // Header
                   Container(
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
                     child: const Center(child: Text('On Click Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                   ),
                   
                   Expanded(
                     child: ListView(
                       padding: const EdgeInsets.all(16),
                       children: [
                         // 1. Open App Home
                         RadioListTile<String>(
                           title: const Text('Open App Home'),
                           subtitle: const Text('Opens the main home screen'),
                           value: 'Open App Home',
                           groupValue: tempAction,
                           activeColor: Colors.orange,
                           contentPadding: EdgeInsets.zero,
                           onChanged: (val) => setSheetState(() { tempAction = val!; tempValue = ''; }),
                         ),
                         
                         // 2. Open Courses Screen
                         RadioListTile<String>(
                           title: const Text('Open Courses Screen'),
                           subtitle: const Text('Opens the course catalog'),
                           value: 'Open Courses Screen',
                           groupValue: tempAction,
                           activeColor: Colors.orange,
                           contentPadding: EdgeInsets.zero,
                           onChanged: (val) => setSheetState(() { tempAction = val!; tempValue = ''; }),
                         ),
                         
                         // 3. Specific Course
                         RadioListTile<String>(
                           title: const Text('Specific Course'),
                           subtitle: const Text('Redirects to a specific course detail'),
                           value: 'Specific Course',
                           groupValue: tempAction,
                           activeColor: Colors.orange,
                           contentPadding: EdgeInsets.zero,
                           onChanged: (val) => setSheetState(() => tempAction = val!),
                         ),
                         
                         if (tempAction == 'Specific Course') ...[
                             Container(
                               height: 200,
                               margin: const EdgeInsets.only(left: 16, bottom: 16),
                               decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
                               child: StreamBuilder<QuerySnapshot>(
                                 stream: FirebaseFirestore.instance.collection('courses').snapshots(),
                                 builder: (context, snapshot) {
                                   if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                   final courses = snapshot.data!.docs;
                                   if (courses.isEmpty) return const Center(child: Text('No courses found'));
                                   
                                   return ListView.builder(
                                     itemCount: courses.length,
                                     itemBuilder: (context, index) {
                                       final data = courses[index].data() as Map<String, dynamic>;
                                       final id = courses[index].id;
                                       final isSelected = tempValue == id;
                                       return ListTile(
                                         title: Text(data['title'] ?? 'Untitled'),
                                         selected: isSelected,
                                         selectedColor: Colors.orange,
                                         trailing: isSelected ? const Icon(Icons.check, color: Colors.orange) : null,
                                         onTap: () {
                                            setSheetState(() => tempValue = id);
                                         },
                                       );
                                     },
                                   );
                                 },
                               ),
                             )
                         ],

                         // 4. Custom URL
                         RadioListTile<String>(
                           title: const Text('Custom URL'),
                           subtitle: const Text('Opens a Weblink or YouTube Video'),
                           value: 'Custom URL',
                           groupValue: tempAction,
                           activeColor: Colors.orange,
                           contentPadding: EdgeInsets.zero,
                           onChanged: (val) => setSheetState(() => tempAction = val!),
                         ),
                         
                         if (tempAction == 'Custom URL') ...[
                           Padding(
                             padding: const EdgeInsets.only(left: 16, bottom: 16),
                             child: TextField(
                               controller: TextEditingController(text: tempValue)..selection = TextSelection.collapsed(offset: tempValue.length),
                               onChanged: (v) => tempValue = v,
                               decoration: InputDecoration(
                                 hintText: 'https://...',
                                 labelText: 'Enter URL',
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                               ),
                             ),
                           )
                         ]
                       ],
                     ),
                   ),
                   
                   // Buttons (Cancel / Done)
                   SafeArea(
                     top: false,
                     child: Padding(
                       padding: const EdgeInsets.all(16),
                       child: Row(
                         children: [
                           Expanded(
                             child: SizedBox(
                               height: 50,
                               child: OutlinedButton(
                                 style: OutlinedButton.styleFrom(
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                   side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
                                 ),
                                 onPressed: () => Navigator.pop(context),
                                 child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                               ),
                             ),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: SizedBox(
                               height: 50,
                               child: ElevatedButton(
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.orange, 
                                   foregroundColor: Colors.white, 
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                 ),
                                 onPressed: () {
                                   setState(() {
                                     _selectedAction = tempAction;
                                     _actionValueController.text = tempValue;
                                   });
                                   _saveDraft();
                                   Navigator.pop(context);
                                 },
                                 child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                               ),
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SingleChildScrollView(
        child: Column(
          children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ListTile(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SentHistoryScreen())),
              leading: CircleAvatar(backgroundColor: AppTheme.primaryColor.withOpacity(0.1), child: FaIcon(FontAwesomeIcons.clockRotateLeft, color: AppTheme.primaryColor, size: 18)),
              title: const Text('View Sent History', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Check previously sent notifications'),
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center, 
                          children: [
                            Icon(Icons.remove_circle, size: 6, color: Colors.grey[500]), 
                            const SizedBox(width: 8), 
                            Text('Notification Shade', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                            const Spacer(),
                            // Preview Button
                            InkWell(
                              onTap: _showPreview,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility, size: 14, color: AppTheme.primaryColor),
                                    const SizedBox(width: 4),
                                    Text('Real Preview', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ]
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Padding(
                                 padding: const EdgeInsets.all(14),
                                 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                     Row(children: [
                                         Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.handyman, size: 10, color: Colors.white)),
                                         const SizedBox(width: 8),
                                         Text('Engineer App', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.black87, fontWeight: FontWeight.w600)),
                                         const SizedBox(width: 4),
                                         Text('• Now', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.black54)),
                                         const Spacer(),
                                         Icon(Icons.expand_more, size: 18, color: isDark ? Colors.grey[500] : Colors.black45),
                                     ]),
                                     const SizedBox(height: 10),
                                     Text(_titleController.text.isNotEmpty ? _titleController.text : 'Notification Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                                     const SizedBox(height: 4),
                                     Text(_messageController.text.isNotEmpty ? _messageController.text : 'Message content...', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.black87)),
                                   ]),
                               ),
                               if (_selectedImage != null) 
                                 AspectRatio(
                                   aspectRatio: 16/9,
                                   child: ClipRRect(
                                     borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                     child: Image.file(_selectedImage!, fit: BoxFit.contain), 
                                   ),
                                 ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  
                  Row(
                    children: [
                      Expanded(child: _buildSelectionCard(context: context, icon: FontAwesomeIcons.users, iconColor: Colors.blue, label: 'Users', value: _selectedAudience, onTap: _showAudienceSelector)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSelectionCard(context: context, icon: FontAwesomeIcons.bolt, iconColor: Colors.orange, label: 'Action', value: _selectedAction, onTap: _showActionSelector)),
                    ],
                  ),

                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    maxLength: 50, // Limit 50
                    decoration: InputDecoration(
                       labelText: 'Title',
                       labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                       enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                       focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                       filled: true,
                       fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                       prefixIcon: Icon(Icons.title, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                       suffixIcon: _buildTextTools(context, _titleController), // Text Tools
                    ),
                    onChanged: (v) { setState(() {}); _saveDraft(); },
                    onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  
                  TextFormField(
                    controller: _messageController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    maxLength: 100, // Limit 100
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                      prefixIcon: Icon(Icons.short_text, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                      suffixIcon: _buildTextTools(context, _messageController), // Text Tools
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    onChanged: (v) { setState(() {}); _saveDraft(); },
                    onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),

                  const SizedBox(height: 16),
                  
                  GestureDetector(
                    onTap: _isSending ? null : _pickImage,
                    onLongPressDown: (_) {
                       if (_selectedImage != null && !_isSending) _startHoldTimer();
                    },
                    onLongPressUp: _cancelHoldTimer,
                    onLongPressCancel: _cancelHoldTimer,
                    child: AspectRatio(
                      aspectRatio: 16/9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!, style: BorderStyle.solid),
                        ),
                        child: _selectedImage != null
                            ? Stack(fit: StackFit.expand, children: [
                                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_selectedImage!, fit: BoxFit.contain)), 
                                Positioned(top: 8, right: 8, child: CircleAvatar(backgroundColor: Colors.white, radius: 14, child: Icon(Icons.edit, size: 16, color: AppTheme.primaryColor))),
                              ])
                            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, size:48, color: isDark ? Colors.grey[400] : Colors.grey[500]), const SizedBox(height: 8), Text('Attach 1280x720 Image\nHold 0.8s to Remove', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500]))]),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50], 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isScheduled ? AppTheme.primaryColor.withOpacity(0.5) : Colors.transparent),
                    ),
                    child: SwitchListTile(
                      activeColor: AppTheme.primaryColor,
                      title: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_isScheduled 
                          ? (_scheduledDate != null 
                             ? DateFormat('dd MMM, hh:mm a').format(DateTime(_scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day, _scheduledTime?.hour ?? 0, _scheduledTime?.minute ?? 0)) 
                             : 'Select Date & Time') 
                          : 'Now'),
                      value: _isScheduled,
                      onChanged: (val) {
                        FocusScope.of(context).unfocus();
                        setState(() { _isScheduled = val; if (!val) { _scheduledDate = null; _scheduledTime = null; } else { _selectDate(); } });
                        _saveDraft();
                      },
                      secondary: Icon(Icons.calendar_today, color: _isScheduled ? AppTheme.primaryColor : Colors.grey),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50, 
                          child: ElevatedButton(
                            onPressed: _isSending ? null : () => _processNotification(), 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor, 
                              foregroundColor: Colors.white, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ), 
                            child: _isSending 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : Text((_isScheduled && _scheduledDate != null && _scheduledTime != null) ? 'Schedule Notification' : 'Send Now', style: const TextStyle(fontWeight: FontWeight.bold))
                          ),
                        ),
                      ),
                      
                      // Conditional Clear Button
                      if (_hasContent) ...[
                        const SizedBox(width: 12),
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: _showClearConfirmation,
                            tooltip: 'Clear Draft',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showClearConfirmation() {
    int secondsRemaining = 5;
    Timer? timer;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // Start timer only once
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (secondsRemaining > 1) {
                setDialogState(() {
                  secondsRemaining--;
                });
              } else {
                t.cancel();
                Navigator.pop(dialogContext); // Close dialog
                _resetForm(); // Perform Clear
                ScaffoldMessenger.of(this.context).showSnackBar( // Use 'this.context' for the parent scaffold
                  const SnackBar(content: Text('Draft Cleared!'), backgroundColor: Colors.red),
                );
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                   const Icon(Icons.warning_amber_rounded, color: Colors.red),
                   const SizedBox(width: 8),
                   const Text('Clear Draft?'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('All content will be erased permanently.'),
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: 1 - (secondsRemaining / 5), // Fills up
                          backgroundColor: Colors.grey[200],
                          color: Colors.red,
                          strokeWidth: 6,
                        ),
                      ),
                      Text(
                        '$secondsRemaining',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Auto-clearing in progress...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      timer?.cancel();
                      Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      elevation: 0,
                    ),
                    child: const Text('Cancel Keep Draft'),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
       // Ensure timer is cancelled if dialog is dismissed by other means
       timer?.cancel();
    });
  }

  Widget _buildTextTools(BuildContext context, TextEditingController controller) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.text_format, color: Theme.of(context).primaryColor),
      tooltip: 'Text Formatting',
      onSelected: (value) {
        String text = controller.text;
        String newText = text;
        
        switch (value) {
          case 'upper':
            newText = text.toUpperCase();
            break;
          case 'lower':
            newText = text.toLowerCase();
            break;
          case 'title':
            newText = text.split(' ').map((str) => str.capitalize()).join(' ');
            break;
          case 'sentence':
             if (text.isNotEmpty) {
               newText = text[0].toUpperCase() + text.substring(1).toLowerCase(); // Basic sentence case
             }
             break;
        }
        
        if (newText != text) {
          controller.text = newText;
          controller.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
          setState(() {});
          _saveDraft();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'title', child: Text('Capitalize Words (Title Case)')),
        const PopupMenuItem(value: 'sentence', child: Text('Sentence case')),
        const PopupMenuItem(value: 'upper', child: Text('UPPERCASE')),
        const PopupMenuItem(value: 'lower', child: Text('lowercase')),
      ],
    );
  }

  Widget _buildSelectionCard({required BuildContext context, required IconData icon, required Color iconColor, required String label, required String value, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [FaIcon(icon, size: 14, color: iconColor), const SizedBox(width: 8), Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  void _showPreview() {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Material(
             color: Colors.transparent,
             child: Container(
               width: MediaQuery.of(context).size.width * 0.95,
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: const Color(0xFF202124), // Approx Android Dark Notif Color
                 borderRadius: BorderRadius.circular(16),
                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
               ),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    // Header
                    Row(
                      children: [
                         Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.handyman, size: 10, color: Colors.white)), // Small Icon
                         const SizedBox(width: 8),
                         const Text('Engineer App', style: TextStyle(color: Color(0xFFE8EAED), fontSize: 12)),
                         const Text(' • now', style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 12)),
                         const Spacer(),
                         const Icon(Icons.expand_more, color: Color(0xFF9AA0A6), size: 18),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Content
                    Row(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_titleController.text.isNotEmpty ? _titleController.text : 'Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFE8EAED))),
                                const SizedBox(height: 4),
                                Text(_messageController.text.isNotEmpty ? _messageController.text : 'Description', style: const TextStyle(fontSize: 14, color: Color(0xFFE8EAED))),
                              ],
                            ),
                          ),
                          if (_selectedImage != null)
                             Padding(
                               padding: const EdgeInsets.only(left: 12),
                               child: ClipRRect(
                                 borderRadius: BorderRadius.circular(4),
                                 child: Image.file(_selectedImage!, width: 48, height: 48, fit: BoxFit.cover),
                               ),
                             ),
                       ],
                    ),
                    // Big Picture (if any)
                    if (_selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_selectedImage!, width: double.infinity, fit: BoxFit.fitWidth),
                        ),
                      ),
                    
                 ],
               ),
             ),
          ),
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
