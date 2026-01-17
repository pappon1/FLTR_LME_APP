import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/app_theme.dart';
import '../../../services/bunny_cdn_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditNotificationScreen extends StatefulWidget {
  final String notificationId;
  final Map<String, dynamic> initialData;

  const EditNotificationScreen({
    super.key,
    required this.notificationId,
    required this.initialData,
  });

  @override
  State<EditNotificationScreen> createState() => _EditNotificationScreenState();
}

class _EditNotificationScreenState extends State<EditNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _messageController;
  late TextEditingController _actionValueController;

  final BunnyCDNService _bunnyCDNService = BunnyCDNService();

  String _selectedAudience = 'Select Users';
  List<String> _selectedCourseIds = [];
  
  File? _newImageFile;
  String? _existingImageUrl; // For showing existing image
  bool _removeExistingImage = false;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isSaving = false;

  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  String _selectedAction = 'Open App Home';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final data = widget.initialData;
    _titleController = TextEditingController(text: data['title'] ?? '');
    _messageController = TextEditingController(text: data['message'] ?? '');
    _actionValueController = TextEditingController(text: data['actionValue'] ?? '');
    _existingImageUrl = data['imageUrl'];
    
    // Action Logic
    final action = data['action'];
    if (action == 'home') {
      _selectedAction = 'Open App Home';
    } else if (action == 'courses') {
      _selectedAction = 'Open Courses Screen';
    } else if (action == 'course') {
      _selectedAction = 'Specific Course';
    } else if (action == 'link') {
      _selectedAction = 'Custom URL';
    } else {
      _selectedAction = 'Open App Home';
    }

    // Audience Logic
    final audience = data['targetAudience'];
    final courseIds = data['targetCourseIds'];
    if (audience == 'course_specific') {
       _selectedCourseIds = List<String>.from(courseIds ?? []);
       _selectedAudience = '${_selectedCourseIds.length} Courses Selected';
    } else {
       _selectedAudience = audience ?? 'Select Users';
       _selectedCourseIds = [];
    }

    // Schedule Logic
    if (data['scheduledAt'] != null) {
      final dt = (data['scheduledAt'] as Timestamp).toDate();
      _scheduledDate = dt;
      _scheduledTime = TimeOfDay.fromDateTime(dt);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _actionValueController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final file = File(image.path);
      setState(() {
        _newImageFile = file;
        _removeExistingImage = true; 
      });
    }
  }

  void _showAudienceSelector() {
    String? tempSegment;
    final List<String> tempCourseIds = List.from(_selectedCourseIds);

    if (_selectedAudience == 'All App Downloads') {
      tempSegment = 'all';
    } else if (_selectedAudience == 'All New App Downloads') {
      tempSegment = 'new';
    } else if (_selectedAudience == 'Not purchased any course') {
      tempSegment = 'non_purchasers';
    } else if (_selectedCourseIds.isNotEmpty) {
      tempSegment = null;
    } 
    
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
                   Container(
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
                     child: const Center(child: Text('Select Users', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                   ),
                   Expanded(
                     child: ListView(
                       padding: EdgeInsets.zero,
                       children: [
                         RadioGroup<String>(
                           groupValue: tempSegment,
                           onChanged: (val) => setSheetState(() { tempSegment = val; tempCourseIds.clear(); }),
                           child: const Column(
                             children: [
                               RadioListTile<String>(
                                 title: Text('All App Downloads'), value: 'all',
                                 activeColor: Colors.red,
                               ),
                               RadioListTile<String>(
                                 title: Text('All New App Downloads'), value: 'new',
                                 activeColor: Colors.red,
                               ),
                               RadioListTile<String>(
                                 title: Text('Not purchased any course'), value: 'non_purchasers',
                                 activeColor: Colors.red,
                               ),
                             ],
                           ),
                         ),
                         
                         Container(padding: const EdgeInsets.all(16), child: const Text('COURSES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                         StreamBuilder<QuerySnapshot>(
                           stream: FirebaseFirestore.instance.collection('courses').snapshots(),
                           builder: (context, snapshot) {
                             if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                             return Column(
                               children: snapshot.data!.docs.map((doc) {
                                  final id = doc.id;
                                  final isSelected = tempCourseIds.contains(id);
                                  return CheckboxListTile(
                                    title: Text((doc.data() as Map)['title'] ?? 'Untitled'),
                                    value: isSelected,
                                    activeColor: Colors.red,
                                    onChanged: (val) {
                                      setSheetState(() {
                                        if (val == true) { tempCourseIds.add(id); tempSegment = null; }
                                        else { tempCourseIds.remove(id); }
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
                   SafeArea(
                     child: Padding(
                       padding: const EdgeInsets.all(16),
                       child: SizedBox(
                         width: double.infinity,
                         height: 50,
                         child: ElevatedButton(
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                           onPressed: () {
                             setState(() {
                                _selectedCourseIds = tempCourseIds;
                                if (tempSegment != null) {
                                   if (tempSegment == 'all') _selectedAudience = 'All App Downloads';
                                   if (tempSegment == 'new') _selectedAudience = 'All New App Downloads';
                                   if (tempSegment == 'non_purchasers') _selectedAudience = 'Not purchased any course';
                                } else {
                                   _selectedAudience = '${_selectedCourseIds.length} Courses Selected';
                                }
                             });
                             Navigator.pop(context);
                           },
                           child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
                         ),
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

  void _showActionSelector() {
    String tempAction = _selectedAction;
    String tempValue = _actionValueController.text;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                   Container(padding: const EdgeInsets.all(20), child: const Center(child: Text('On Click Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))),
                   Expanded(
                     child: ListView(
                       padding: const EdgeInsets.all(16),
                       children: [
                         RadioGroup<String>(
                           groupValue: tempAction,
                           onChanged: (v) => setSheetState(() => tempAction = v.toString()),
                           child: Column(
                             children: [
                               const RadioListTile(title: Text('Open App Home'), value: 'Open App Home'),
                               const RadioListTile(title: Text('Open Courses Screen'), value: 'Open Courses Screen'),
                               const RadioListTile(title: Text('Specific Course'), value: 'Specific Course'),
                               if (tempAction == 'Specific Course') 
                                  SizedBox(height: 200, child: StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance.collection('courses').snapshots(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                      return ListView(children: snapshot.data!.docs.map((d) => ListTile(
                                          title: Text((d.data() as Map)['title']),
                                          selected: tempValue == d.id,
                                          selectedColor: Colors.orange,
                                          onTap: () => setSheetState(() => tempValue = d.id)
                                      )).toList());
                                    }
                                  )),
                               const RadioListTile(title: Text('Custom URL'), value: 'Custom URL'),
                               if (tempAction == 'Custom URL')
                                  Padding(padding: const EdgeInsets.all(8.0), child: TextField(controller: TextEditingController(text: tempValue), onChanged: (v) => tempValue = v, decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder())))
                             ],
                           ),
                         )
                       ],
                     ),
                   ),
                   Padding(padding: const EdgeInsets.all(16), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)), onPressed: () {
                     setState(() { _selectedAction = tempAction; _actionValueController.text = tempValue; });
                     Navigator.pop(context);
                   }, child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)))),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_scheduledDate == null || _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Date and Time for scheduling.')));
      return;
    }

    final dt = DateTime(_scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day, _scheduledTime!.hour, _scheduledTime!.minute);
    if (dt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot schedule in the past!')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? finalImageUrl = _existingImageUrl;
      
      // Handle Image Change
      if (_newImageFile != null) {
         setState(() => _isUploading = true);
         finalImageUrl = await _bunnyCDNService.uploadImage(
            filePath: _newImageFile!.path,
            folder: 'notifications',
            onProgress: (sent, total) => setState(() => _uploadProgress = sent / total),
         );
         setState(() => _isUploading = false);
      } else if (_removeExistingImage) {
        finalImageUrl = null;
      }

      // Action Mapping
      String actionType = 'home';
      if (_selectedAction == 'Open App Home') {
        actionType = 'home';
      } else if (_selectedAction == 'Open Courses Screen') {
        actionType = 'courses';
      } else if (_selectedAction == 'Specific Course') {
        actionType = 'course';
      } else if (_selectedAction == 'Custom URL') {
        actionType = 'link';
      }

      await FirebaseFirestore.instance.collection('notifications').doc(widget.notificationId).update({
         'title': _titleController.text.trim(),
         'message': _messageController.text.trim(),
         'imageUrl': finalImageUrl,
         'scheduledAt': Timestamp.fromDate(dt),
         'action': actionType,
         'actionValue': _actionValueController.text.trim(),
         'targetAudience': _selectedCourseIds.isNotEmpty ? 'course_specific' : _selectedAudience,
         'targetCourseIds': _selectedCourseIds,
      });

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes Saved Successfully!'), backgroundColor: Colors.green));
         Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; _isUploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Scheduled Notification'),
          centerTitle: true,
        ),
      body: Column(
        children: [
          Expanded(
            child: _isSaving && _isUploading 
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(value: _uploadProgress), const SizedBox(height: 10), Text('Uploading Image... ${( _uploadProgress * 100).toStringAsFixed(0)}%')])) 
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       // UI Preview Section (Card)
                       // Added constraints to avoid overflow
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
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.remove_circle, size: 6, color: Colors.grey[500]), const SizedBox(width: 8), Text('Preview', style: TextStyle(fontSize: 10, color: Colors.grey[500]))]),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
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
                                            ]),
                                            const SizedBox(height: 10),
                                            Text(_titleController.text.isNotEmpty ? _titleController.text : 'Notification Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                                            const SizedBox(height: 4),
                                            Text(_messageController.text.isNotEmpty ? _messageController.text : 'Message content...', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.black87)),
                                          ]),
                                      ),
                                      if (_newImageFile != null) 
                                        AspectRatio(aspectRatio: 16/9, child: ClipRRect(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)), child: Image.file(_newImageFile!, fit: BoxFit.cover)))
                                      else if (_existingImageUrl != null && !_removeExistingImage)
                                        AspectRatio(
                                          aspectRatio: 16/9, 
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)), 
                                            child: CachedNetworkImage(
                                              imageUrl: BunnyCDNService().getAuthenticatedUrl(_existingImageUrl!),
                                              fit: BoxFit.cover,
                                              httpHeaders: const {'AccessKey': BunnyCDNService.apiKey},
                                              placeholder: (c, u) => Container(color: Colors.grey[200]),
                                              errorWidget: (c, u, e) => const Icon(Icons.broken_image, color: Colors.grey),
                                            )
                                          )
                                        ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
        
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
        
                        // Form Fields
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.title),
                          ),
                          onChanged: (v) => setState(() {}),
                          onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            labelText: 'Message',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.short_text),
                          ),
                          maxLines: 3,
                          onChanged: (v) => setState(() {}),
                           onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
                           validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
        
                        // Image Picker
                        GestureDetector(
                          onTap: _pickImage,
                          child: AspectRatio(
                            aspectRatio: 16/9,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(12),
                                color: isDark ? Colors.grey[900] : Colors.grey[100],
                              ),
                              child: _newImageFile != null 
                                  ? Stack(fit: StackFit.expand, children: [
                                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_newImageFile!, fit: BoxFit.cover)),
                                      const Positioned(right: 8, top: 8, child: CircleAvatar(backgroundColor: Colors.white, radius: 16, child: Icon(Icons.edit, size: 16, color: AppTheme.primaryColor)))
                                    ])
                                  : (_existingImageUrl != null && !_removeExistingImage
                                      ? Stack(fit: StackFit.expand, children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: CachedNetworkImage(
                                              imageUrl: BunnyCDNService().getAuthenticatedUrl(_existingImageUrl!),
                                              fit: BoxFit.cover,
                                              httpHeaders: const {'AccessKey': BunnyCDNService.apiKey},
                                              placeholder: (c, u) => Container(color: Colors.grey[200]),
                                              errorWidget: (c, u, e) => const Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          ),
                                          const Positioned(right: 8, top: 8, child: CircleAvatar(backgroundColor: Colors.white, radius: 16, child: Icon(Icons.edit, size: 16, color: AppTheme.primaryColor)))
                                        ])
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center, 
                                          children: [
                                            Icon(Icons.add_photo_alternate_rounded, size: 48, color: isDark ? Colors.grey[400] : Colors.grey[500]), 
                                            const SizedBox(height: 8), 
                                            Text('Add Image (16:9)', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500]))
                                          ]
                                        )),
                            ),
                          ),
                        ),
                        if (_newImageFile != null || (_existingImageUrl != null && !_removeExistingImage))
                           TextButton.icon(
                             onPressed: () { setState(() { _newImageFile = null; _removeExistingImage = true; }); },
                             icon: const Icon(Icons.delete, color: Colors.red),
                             label: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                           ),
        
                        const SizedBox(height: 24),
                        
                         Row(
                          children: [
                            Expanded(child: _buildSelectionCard(context, FontAwesomeIcons.users, Colors.blue, 'Audience', _selectedAudience, _showAudienceSelector)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSelectionCard(context, FontAwesomeIcons.bolt, Colors.orange, 'Action', _selectedAction, _showActionSelector)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Date Time Picker
                        const Text('Schedule Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();
                                  final d = await showDatePicker(
                                    context: context, 
                                    initialDate: _scheduledDate ?? DateTime.now(), 
                                    firstDate: DateTime.now(), 
                                    lastDate: DateTime.now().add(const Duration(days: 365))
                                  );
                                  if (d != null) setState(() => _scheduledDate = d);
                                },
                                icon: const Icon(Icons.calendar_today),
                                label: Text(_scheduledDate == null ? 'Select Date' : DateFormat('dd MMM').format(_scheduledDate!)),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();
                                  final t = await showTimePicker(context: context, initialTime: _scheduledTime ?? TimeOfDay.now());
                                  if (t != null) setState(() => _scheduledTime = t);
                                },
                                icon: const Icon(Icons.access_time),
                                label: Text(_scheduledTime == null ? 'Select Time' : _scheduledTime!.format(context)),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40), 
                    ],
                  ),
                ),
              ),
          ),
          
          // Sticky Bottom Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSelectionCard(BuildContext context, IconData icon, Color color, String title, String value, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [FaIcon(icon, size: 14, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold))]),
            const SizedBox(height: 8),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
