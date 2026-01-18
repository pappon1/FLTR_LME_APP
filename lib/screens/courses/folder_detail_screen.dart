import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:file_picker/file_picker.dart';

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
      setState(() => _isDragModeActive = true);
    });
  }

  void _cancelHoldTimer() => _holdTimer?.cancel();
  
  @override
  void didUpdateWidget(FolderDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.contentList != oldWidget.contentList) {
       // If parent updates the list, we restart from the new list and re-apply persistence
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
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text('✅ Restored $loadedCount items from draft'), 
                 duration: const Duration(seconds: 2),
                 backgroundColor: Colors.blueGrey.shade800,
                 behavior: SnackBarBehavior.floating,
               ),
             );
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
         _contents.add(newItem);
      }
    });
    
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

  void _showAddContentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
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
                setState(() { _contents.add({'type': 'folder', 'name': folderNameController.text.trim(), 'contents': <Map<String, dynamic>>[], 'isLocal': true}); });
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
           _contents.addAll(newItems);
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
      // COMPLETELY REMOVED as requested.
      // No duration check. No thumbnail generation.
      // Just save the list.
      unawaited(_savePersistentContent());
  }

  Future<String?> _generateThumbnail(String path) async {
    return null; // System Removed
  }

  Future<String> _getVideoDuration(String path) async {
    return ""; // System Removed
  }

  String _formatDurationString(Duration dur) {
    return "";
  }

  Future<void> _fixMissingData() async {
    return; // System Removed
  }

  void _handleContentTap(Map<String, dynamic> item, int index) {
      if (_isSelectionMode) { _toggleSelection(index); return; }
      // HapticFeedback.lightImpact(); // Removed as requested - no feedback on content tap
      final String? path = item['path'];
      if (item['type'] == 'folder') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => FolderDetailScreen(folderName: item['name'], contentList: (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? []))).then((_) => _refresh());
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
      appBar: AppBar(
        leading: _isDragModeActive
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _isDragModeActive = false))
          : _isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedIndices.clear(); }))
            : null,
        title: Text(_isDragModeActive ? 'Drag to Reorder' : _isSelectionMode ? '${_selectedIndices.length} Selected' : widget.folderName, style: TextStyle(color: (_isSelectionMode || _isDragModeActive) ? Colors.white : null)),
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: _contents.length == _selectedIndices.length ? () => setState(() => _selectedIndices.clear()) : _selectAll,
              child: Text(_contents.length == _selectedIndices.length ? 'Unselect All' : 'Select All', style: const TextStyle(color: Colors.white)),
            ),
            IconButton(icon: const Icon(Icons.copy), onPressed: () => _handleBulkCopyCut(false)),
            IconButton(icon: const Icon(Icons.delete), onPressed: _handleBulkDelete),
          ]
        ],
      ),
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
                    padding: EdgeInsets.fromLTRB(16, (_isSelectionMode || _isDragModeActive) ? 20 : 12, 16, 24),
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
                         IconData icon; Color color;
                         switch(item['type']) {
                           case 'folder': icon = Icons.folder; color = Colors.orange; break;
                           case 'video': icon = Icons.video_library; color = Colors.red; break;
                           case 'pdf': icon = Icons.picture_as_pdf; color = Colors.redAccent; break;
                           case 'image': icon = Icons.image; color = Colors.purple; break;
                           case 'zip': icon = Icons.folder_zip; color = Colors.blueGrey; break;
                           default: icon = Icons.insert_drive_file; color = Colors.blue;
                         }
                         
                         return Material(
                           key: ValueKey('item_${item['name']}_${item['path']}_$index'),
                           color: Colors.transparent,
                           child: Stack(
                             children: [
                                Padding(
                                 padding: const EdgeInsets.only(bottom: 12),
                                 child: ListTile(
                                    tileColor: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Theme.of(context).cardColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200, width: isSelected ? 2 : 1)),
                                    leading: Hero(
                                      tag: item['path'] ?? item['name'] + index.toString(),
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: (item['type'] == 'video' && item['thumbnail'] != null)
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.file(File(item['thumbnail']), fit: BoxFit.cover),
                                            )
                                          : Icon(icon, color: color, size: 20),
                                      ),
                                    ),
                                    title: Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppTheme.primaryColor : null), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: item['type'] == 'video' ? Text(item['duration'] ?? '...', style: const TextStyle(fontSize: 10)) : null,
                                    trailing: _isSelectionMode 
                                      ? (isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : const Icon(Icons.circle_outlined)) 
                                      : _isDragModeActive ? const Icon(Icons.drag_handle, color: Colors.grey) : null,
                                 ),
                               ),
                               
                               if (!_isSelectionMode && !_isDragModeActive)
                               Positioned(
                                 right: 0, top: 0, bottom: 12,
                                 child: PopupMenuButton<String>(
                                   icon: const Icon(Icons.more_vert),
                                   onSelected: (value) {
                                     if (value == 'rename') _renameContent(index);
                                     if (value == 'remove') _confirmRemoveContent(index);
                                   },
                                   itemBuilder: (context) => [
                                     const PopupMenuItem(value: 'rename', child: Text('Rename')),
                                     const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: Colors.red))),
                                   ],
                                 ),
                               ),

                               // Gesture Overlay
                               Positioned.fill(
                                 bottom: 12,
                                 child: _isDragModeActive
                                   ? ReorderableDragStartListener(
                                       index: index,
                                       child: Container(color: Colors.transparent),
                                     )
                                   : GestureDetector(
                                       behavior: HitTestBehavior.translucent,
                                       onTapDown: (_) => _startHoldTimer(),
                                       onTapUp: (_) => _cancelHoldTimer(),
                                       onTapCancel: () => _cancelHoldTimer(),
                                       onLongPress: () => _enterSelectionMode(index),
                                       onTap: () => _handleContentTap(item, index),
                                       child: Container(color: Colors.transparent),
                                     ),
                               ),
                             ],
                           ),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
