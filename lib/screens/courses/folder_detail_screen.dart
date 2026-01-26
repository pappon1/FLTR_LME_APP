import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../utils/app_theme.dart';
import '../../utils/clipboard_manager.dart';
import '../content_viewers/image_viewer_screen.dart';
import '../content_viewers/video_player_screen.dart';
import '../content_viewers/pdf_viewer_screen.dart';
import '../utils/simple_file_explorer.dart';
import 'components/course_content_list_item.dart';

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
  bool _isDragModeActive = false;
  Timer? _holdTimer;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _contents = List.from(widget.contentList);
    _initData();
  }

  Future<void> _initData() async {
    await _loadPersistentContent();
    setState(() => _isInitialLoading = false);
    // Background scan for missing durations and thumbnails
    Future.delayed(const Duration(seconds: 1), () => _fixMissingData());
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
  
  void _enterSelectionMode(int index) {
      _cancelHoldTimer(); // Cancel drag timer immediately
      HapticFeedback.heavyImpact();
      setState(() {
        _isSelectionMode = true;
        _selectedIndices.clear();
        _selectedIndices.add(index);
      });
  }
  @override
  void didUpdateWidget(FolderDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.contentList != oldWidget.contentList) {
       setState(() {
         _contents = List.from(widget.contentList);
       });
       _loadPersistentContent();
    }
  }
  
  // --- Persistence Logic ---
  Future<void> _loadPersistentContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Ensure we have the latest data from disk
      
      // Sanitizing key: Removing spaces and symbols just in case
      final sanitizedName = widget.folderName.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
      final key = 'draft_final_$sanitizedName'; 
      
      final String? jsonString = prefs.getString(key);
      // debugPrint("Attempting to load draft from key: $key");
      
      if (jsonString != null && jsonString.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(jsonString);
          if (decoded.isEmpty) {
             // debugPrint("Draft is empty for key: $key");
             return;
          }

          // We only want to restore items that ARE NOT already in the list (from server)
          // Identify items by path
          final Set<String> existingPaths = _contents
              .where((e) => e['path'] != null)
              .map((e) => e['path'].toString())
              .toSet();
          
          bool hasChanges = false;
          int loadedCount = 0;

          for (var item in decoded) {
             final mapItem = Map<String, dynamic>.from(item);
             final path = mapItem['path'];
             
             // Ensure it's marked as local so it stays in future saves
             mapItem['isLocal'] = true;

             if (path != null) {
                if (!existingPaths.contains(path)) {
                   _contents.add(mapItem);
                   existingPaths.add(path); 
                   hasChanges = true;
                   loadedCount++;
                }
             } else if (mapItem['type'] == 'folder') {
                // For local folders, check by name
                final bool exists = _contents.any((e) => e['type'] == 'folder' && e['name'] == mapItem['name']);
                if (!exists) {
                    _contents.add(mapItem);
                    hasChanges = true;
                    loadedCount++;
                }
             }
          }
          
          if (hasChanges && mounted) {
             setState(() {});
             // Silent restoration, no SnackBar
          }
      } else {
         // debugPrint("No draft found for key: $key");
      }
    } catch (e) {
      // debugPrint("Error loading saved content: $e");
    }
  }

  Future<void> _savePersistentContent({bool showFeedback = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sanitizedName = widget.folderName.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
      final key = 'draft_final_$sanitizedName';
      
      // We ONLY save items that are local additions (marked by us)
      // This prevents saving server-side items into local shared_prefs
      final localItems = _contents.where((e) {
        return e['isLocal'] == true;
      }).toList();
      
      if (localItems.isEmpty) {
         // If no local items, clear the key to avoid loading stale data
         await prefs.remove(key);
         if (showFeedback && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No local items to save.')));
         }
         return;
      }

      final String jsonString = jsonEncode(localItems);
      final bool success = await prefs.setString(key, jsonString);
      
      if (success && mounted && showFeedback) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('💾 Draft Saved (${localItems.length} items)'), 
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            )
         );
      }
      // debugPrint("Saved ${localItems.length} items to $key. Success: $success");
    } catch (e) {
       // debugPrint("Save error: $e");
       if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
       }
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Storage Optimization: Clear temporary files from picker cache
    // unawaited(FilePicker.platform.clearTemporaryFiles());
    super.dispose();
  }

  // Duplicate removed

  void _toggleSelection(int index) {
      if (!_isSelectionMode) return;
      HapticFeedback.heavyImpact();
      setState(() {
         if (_selectedIndices.contains(index)) {
            _selectedIndices.remove(index);
            // Removed auto-close logic to match AddCourseScreen
         } else {
            _selectedIndices.add(index);
         }
      });
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.clear();
      for(int i=0; i<_contents.length; i++) {
        _selectedIndices.add(i);
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
                       if (i < _contents.length) {
                          // Free up cache space
                          final item = _contents[i];
                          final path = item['path'];
                          if (path != null && path.contains('/cache/')) {
                            try {
                              final file = File(path);
                              if (file.existsSync()) file.deleteSync();
                            } catch (_) {}
                          }
                          _contents.removeAt(i);
                       }
                    }
                     _isSelectionMode = false;
                    _selectedIndices.clear();
                 });
                 _savePersistentContent();
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
         if (i < _contents.length) itemsToCopy.add(_contents[i]);
      }
      
      setState(() {
         if (isCut) {
            ContentClipboard.cut(itemsToCopy);
            final List<int> revIndices = indices.reversed.toList();
            for (int i in revIndices) {
               _contents.removeAt(i);
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
         _contents.insert(0, newItem);
      }
    });
    _savePersistentContent();
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ContentClipboard.items!.length} items pasted')));
  }

  void _renameContent(int index) {
      final TextEditingController renameController = TextEditingController(text: _contents[index]['name']);
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (renameController.text.trim().isNotEmpty) {
                  setState(() { _contents[index]['name'] = renameController.text.trim(); });
                  _savePersistentContent();
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final item = _contents[index];
              final path = item['path'];
              if (path != null && path.contains('/cache/')) {
                try {
                  final file = File(path);
                  if (file.existsSync()) file.deleteSync();
                } catch (_) {}
              }
              setState(() { _contents.removeAt(index); });
              _savePersistentContent();
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
    String? currentThumbnail = _contents[index]['thumbnail'];

    showDialog(
      context: context,
      barrierDismissible: false,
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
                         color: Colors.red.withValues(alpha: 0.1),
                         borderRadius: BorderRadius.circular(3.0),
                         border: Border.all(color: Colors.red.withValues(alpha: 0.5))
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
                           borderRadius: BorderRadius.circular(3.0),
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
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3.0),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid)
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
                      _contents[index]['thumbnail'] = currentThumbnail;
                    });
                    _savePersistentContent();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thumbnail Saved!')));
                  },
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            );
          }
        );
      }
    );
  }

  void _showAddContentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(3.0))),
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
        title: const Text('New Folder'),
        content: TextField(controller: folderNameController, autofocus: true, decoration: const InputDecoration(labelText: 'Folder Name', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (folderNameController.text.trim().isNotEmpty) {
                setState(() { _contents.insert(0, {'type': 'folder', 'name': folderNameController.text.trim(), 'contents': <Map<String, dynamic>>[], 'isLocal': true}); });
                _savePersistentContent();
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
      // Use Custom Explorer for ALL types to prevent Cache Bloat
      final result = await Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => SimpleFileExplorer(
          allowedExtensions: extensions ?? [],
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
             'duration': type == 'video' ? "..." : null, 
             'thumbnail': null,
             'isLocal': true
           });
         }
         
         setState(() {
           _contents.insertAll(0, newItems);
         });
         
         // Only process video if needed (currently disabled for cache safety)
         if (type == 'video') {
            _processVideosInParallel(newItems);
         } else {
            _savePersistentContent();
         }
      }
  }

  Future<void> _processVideosInParallel(List<Map<String, dynamic>> items) async {
      await _savePersistentContent();
      // Start background processing
      Future.delayed(const Duration(milliseconds: 500), () => _fixMissingData());
  }

  Future<String?> _generateThumbnail(String path) async {
    return null; // System Removed
  }

  Future<String> _getVideoDuration(String path) async {
    final player = Player();
    try {
      final completer = Completer<void>();
      late final StreamSubscription sub;
      
      sub = player.stream.duration.listen((d) {
        if (d.inSeconds > 0) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      await player.open(Media(path), play: false);
      
      // Wait for duration or timeout
      await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      
      final dur = player.state.duration;
      await sub.cancel();
      await player.dispose();
      
      return _formatDurationString(dur);
    } catch (e) {
      await player.dispose();
      return "00:00";
    }
  }

  String _formatDurationString(Duration dur) {
    if (dur.inSeconds == 0) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(dur.inMinutes.remainder(60));
    final seconds = twoDigits(dur.inSeconds.remainder(60));
    if (dur.inHours > 0) {
      return "${twoDigits(dur.inHours)}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  Future<void> _fixMissingData() async {
    bool hasChanges = false;
    for (int i = 0; i < _contents.length; i++) {
      if (_contents[i]['type'] == 'video' && 
         (_contents[i]['duration'] == "..." || _contents[i]['duration'] == null || _contents[i]['duration'] == "")) {
        
        final path = _contents[i]['path'];
        if (path != null && File(path).existsSync()) {
          final duration = await _getVideoDuration(path);
          if (mounted) {
            setState(() {
              _contents[i]['duration'] = duration;
            });
            hasChanges = true;
          }
        }
      }
    }
    if (hasChanges) {
      await _savePersistentContent();
    }
  }

  void _handleContentTap(Map<String, dynamic> item, int index) async {
      if (_isSelectionMode) { _toggleSelection(index); return; }
      final String? path = item['path'];
      if (item['type'] == 'folder') {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => FolderDetailScreen(
                folderName: item['name'], 
                contentList: (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? []
              )
            )
          );
          
          if (result != null && result is List<Map<String, dynamic>>) {
             setState(() {
                _contents[index]['contents'] = result;
             });
             unawaited(_savePersistentContent());
          }
      } else if (item['type'] == 'image' && path != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(
            filePath: path,
            title: item['name'],
          )));
      } else if (item['type'] == 'video' && path != null) {
          // CREATE PLAYLIST: Filter only video items
          final videoList = _contents.where((element) => element['type'] == 'video' && element['path'] != null).toList();
          final initialIndex = videoList.indexOf(item);
          
          Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(
            playlist: videoList, 
            initialIndex: initialIndex >= 0 ? initialIndex : 0,
          )));
      } else if (item['type'] == 'pdf' && path != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PDFViewerScreen(
            filePath: path,
            title: item['name'],
          )));
      }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
         if (didPop) return;
         await _savePersistentContent();
         // Pass data back just in case parent supports it
         if (context.mounted) Navigator.pop(context, _contents);
      },
      child: Scaffold(
      appBar: _buildAppBar(),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: (!_isSelectionMode && !_isDragModeActive)
             ? Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 24, bottom: 0),
                  child: InkWell(
                     onTap: _showAddContentMenu,
                     borderRadius: BorderRadius.circular(3.0),
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

          _isInitialLoading
             ? SliverToBoxAdapter(child: _buildShimmerList())
             : _contents.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('No content in this folder', style: TextStyle(color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, (_isSelectionMode || _isDragModeActive) ? 20 : 12, 24, 24),
                    sliver: SliverReorderableList(
                      itemCount: _contents.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) newIndex -= 1;
                          final item = _contents.removeAt(oldIndex);
                          _contents.insert(newIndex, item);
                        });
                        _savePersistentContent();
                      },
                      itemBuilder: (context, index) {
                         final item = _contents[index];
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
        ],
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
                borderRadius: BorderRadius.circular(3.0),
              ),
            ),
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
                  onPressed: _contents.length == _selectedIndices.length ? () => setState(() => _selectedIndices.clear()) : _selectAll,
                  child: Text(_contents.length == _selectedIndices.length ? 'Unselect' : 'All', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
              ),
            ),
            IconButton(icon: const Icon(Icons.copy), onPressed: () => _handleBulkCopyCut(false)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _handleBulkDelete),
          ],
          elevation: 2,
       );
    }
    return AppBar(
      title: Text(widget.folderName, style: const TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      elevation: 0,
    );
  }
}

