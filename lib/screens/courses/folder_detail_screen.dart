import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import '../../utils/app_theme.dart';
import '../../utils/clipboard_manager.dart';
import '../content_viewers/image_viewer_screen.dart';
import '../content_viewers/video_player_screen.dart';
import '../content_viewers/pdf_viewer_screen.dart';

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
    // Create a mutable copy of the list to ensure we don't modify the parent's reference directly (or fail if it's immutable)
    _contents = List.from(widget.contentList);
    _loadPersistentContent().then((_) {
      // Background scan for missing durations
      Future.delayed(const Duration(seconds: 1), () => _fixMissingDurations());
    });
  }
  
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
      final localItems = _contents.where((e) => e['isLocal'] == true).toList();
      
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
                       if (i < _contents.length) _contents.removeAt(i);
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

  Future<void> _pickContentFile(String type, FileType fileType, [List<String>? extensions]) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(type: fileType, allowedExtensions: extensions, allowMultiple: true);
      if (result != null) {
        for (var file in result.files) {
          if (file.path != null) {
            String durationStr = "00:00";
            if (type == 'video') {
              durationStr = await _getVideoDuration(file.path!);
            }
            if (mounted) {
              setState(() {
                _contents.add({
                  'type': type, 
                  'name': file.name, 
                  'path': file.path, 
                  'duration': durationStr,
                  'isLocal': true
                });
              });
            }
          }
        }
        unawaited(_savePersistentContent());
      }
    } catch (e) { 
       // debugPrint('Error picking file: $e'); 
    }
  }

  Future<String> _getVideoDuration(String path) async {
    final player = Player();
    final completer = Completer<String>();
    
    final subscription = player.stream.duration.listen((dur) {
      if (dur != Duration.zero && !completer.isCompleted) {
        completer.complete(_formatDurationString(dur));
      }
    });

    try {
      await player.open(Media(path), play: false);
      final result = await completer.future.timeout(
        const Duration(seconds: 5), 
        onTimeout: () => "00:00"
      );
      await subscription.cancel();
      await player.dispose();
      return result;
    } catch (e) {
      // debugPrint("Error extracting duration: $e");
      await subscription.cancel();
      await player.dispose();
      return "00:00";
    }
  }

  String _formatDurationString(Duration dur) {
    String two(int n) => n.toString().padLeft(2, "0");
    if (dur.inHours > 0) {
      return "${dur.inHours}:${two(dur.inMinutes % 60)}:${two(dur.inSeconds % 60)}";
    } else {
      return "${two(dur.inMinutes)}:${two(dur.inSeconds % 60)}";
    }
  }

  Future<void> _fixMissingDurations() async {
    bool changed = false;
    for (int i = 0; i < _contents.length; i++) {
      if (_contents[i]['type'] == 'video' && 
          (_contents[i]['duration'] == null || _contents[i]['duration'] == '00:00') &&
          _contents[i]['path'] != null) {
        final realDur = await _getVideoDuration(_contents[i]['path']);
        if (realDur != '00:00') {
          _contents[i]['duration'] = realDur;
          changed = true;
        }
      }
    }
    if (changed && mounted) {
      setState(() {});
      unawaited(_savePersistentContent());
    }
  }

  void _handleContentTap(Map<String, dynamic> item, int index) {
      if (_isSelectionMode) { _toggleSelection(index); return; }
      // HapticFeedback.lightImpact(); // Removed as requested - no feedback on content tap
      final String? path = item['path'];
      if (item['type'] == 'folder') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => FolderDetailScreen(folderName: item['name'], contentList: (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? []))).then((_) => _refresh());
      } else if (item['type'] == 'image' && path != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(filePath: path)));
      } else if (item['type'] == 'video' && path != null) {
          // CREATE PLAYLIST: Filter only video items
          final videoList = _contents.where((element) => element['type'] == 'video' && element['path'] != null).toList();
          final initialIndex = videoList.indexOf(item);
          
          Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(
            playlist: videoList, 
            initialIndex: initialIndex >= 0 ? initialIndex : 0,
          )));
      } else if (item['type'] == 'pdf' && path != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PDFViewerScreen(filePath: path)));
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
        backgroundColor: _isSelectionMode ? AppTheme.primaryColor : null,
        iconTheme: IconThemeData(color: _isSelectionMode ? Colors.white : null),
        leading: _isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedIndices.clear(); }))
          : null,
        title: Text(_isSelectionMode ? '${_selectedIndices.length} Selected' : widget.folderName, style: TextStyle(color: _isSelectionMode ? Colors.white : null)),
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
          // Add Button (Top Right aligned, scrolls with content)
          SliverToBoxAdapter(
            child: (!_isSelectionMode)
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

          // Content List
          _contents.isEmpty
             ? SliverFillRemaining(
                 hasScrollBody: false,
                 child: Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                       const SizedBox(height: 16),
                       Text('No content in this folder', style: TextStyle(color: Colors.grey.shade400)),
                     ],
                   ),
                 ),
               )
             : SliverPadding(
                 padding: EdgeInsets.fromLTRB(16, (_isSelectionMode) ? 20 : 12, 16, 24),
                 sliver: SliverList(
                   delegate: SliverChildBuilderDelegate(
                     (context, index) {
                        final item = _contents[index];
                        final isSelected = _selectedIndices.contains(index);
                        IconData icon; Color color;
                        switch(item['type']) {
                          case 'folder': icon = Icons.folder; color = Colors.orange; break;
                          case 'video': icon = Icons.video_library; color = Colors.red; break;
                          case 'pdf': icon = Icons.picture_as_pdf; color = Colors.redAccent; break;
                          case 'image': icon = Icons.image; color = Colors.purple; break;
                          default: icon = Icons.insert_drive_file; color = Colors.blue;
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            tileColor: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200, width: isSelected ? 2 : 1)),
                            onLongPress: () => _enterSelectionMode(index),
                            onTap: () => _handleContentTap(item, index),
                            leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
                            title: Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppTheme.primaryColor : null)),
                            trailing: _isSelectionMode 
                              ? (isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : const Icon(Icons.circle_outlined)) 
                              : PopupMenuButton<String>(
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
                        );
                     },
                     childCount: _contents.length,
                   ),
                 ),
               ),
        ],
      ),
     ),
    );
  }
}
