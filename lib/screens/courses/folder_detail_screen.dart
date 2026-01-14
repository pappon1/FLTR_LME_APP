import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
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
    _contents = widget.contentList;
  }

  void _refresh() => setState(() {});

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
         var newItem = Map<String, dynamic>.from(jsonDecode(jsonEncode(item)));
         newItem['name'] = '${newItem['name']} (Copy)';
         _contents.add(newItem);
      }
    });
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ContentClipboard.items!.length} items pasted')));
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (renameController.text.trim().isNotEmpty) {
                  setState(() { _contents[index]['name'] = renameController.text.trim(); });
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
        title: const Text('New Folder'),
        content: TextField(controller: folderNameController, autofocus: true, decoration: const InputDecoration(labelText: 'Folder Name', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (folderNameController.text.trim().isNotEmpty) {
                setState(() { _contents.add({'type': 'folder', 'name': folderNameController.text.trim(), 'contents': <Map<String, dynamic>>[]}); });
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: fileType, allowedExtensions: extensions, allowMultiple: true);
      if (result != null) {
        setState(() {
          for (var file in result.files) {
            if (file.path != null) _contents.add({'type': type, 'name': file.name, 'path': file.path});
          }
        });
      }
    } catch (e) { debugPrint('Error picking file: $e'); }
  }

  void _handleContentTap(Map<String, dynamic> item, int index) {
      if (_isSelectionMode) { _toggleSelection(index); return; }
      // HapticFeedback.lightImpact(); // Removed as requested - no feedback on content tap
      String? path = item['path'];
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
    return Scaffold(
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
                            tileColor: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200, width: isSelected ? 2 : 1)),
                            onLongPress: () => _enterSelectionMode(index),
                            onTap: () => _handleContentTap(item, index),
                            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
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
    );
  }
}
