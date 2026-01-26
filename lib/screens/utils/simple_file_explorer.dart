import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import '../../utils/app_theme.dart';

class SimpleFileExplorer extends StatefulWidget {
  final List<String> allowedExtensions;
  final String? initialPath;

  const SimpleFileExplorer({
    super.key, 
    required this.allowedExtensions,
    this.initialPath,
  });

  @override
  State<SimpleFileExplorer> createState() => _SimpleFileExplorerState();
}

class _SimpleFileExplorerState extends State<SimpleFileExplorer> {
  // Mode: 0 = Smart Gallery (Scan), 1 = Folder Browser
  int _viewMode = 0; 
  
  // Gallery Data
  List<File> _galleryFiles = [];
  bool _isScanning = true;
  
  // Folder Browser Data
  late Directory _currentDirectory;
  List<FileSystemEntity> _folderFiles = [];
  bool _isLoadingFolder = false;
  
  // Selection Data
  final Set<String> _selectedPaths = {};
  bool _isSelectionMode = false;
  
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPath();
  }

  // ... (Init Path and Smart Scan Logic remains same, only UI interactions change) ... 
  Future<void> _initPath() async {
    // 1. Permissions
    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.isGranted) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
             if (!await Permission.storage.isGranted) {
                 await Permission.storage.request();
             }
        }
      }
    }

    final rootPath = widget.initialPath ?? '/storage/emulated/0';
    _currentDirectory = Directory(rootPath);
    if (!await _currentDirectory.exists()) {
       _currentDirectory = Directory.systemTemp;
    }

    _startSmartScan();
  }

  // --- SMART SCAN LOGIC ---
  Future<void> _startSmartScan() async {
    setState(() {
      _isScanning = true;
      _galleryFiles.clear();
      _selectedPaths.clear();
      _isSelectionMode = false;
    });

    try {
      final List<String> scanPaths = [
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/WhatsApp/Media',
        '/storage/emulated/0/Android/media',
      ];
      
      final List<File> found = [];
      final Set<String> processedPaths = {};

      for (var path in scanPaths) {
         final dir = Directory(path);
         if (await dir.exists()) {
            await _recursiveScan(dir, found, processedPaths, 0);
         }
      }
      
      if (mounted) {
        setState(() {
          _galleryFiles = found.reversed.toList();
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _recursiveScan(Directory dir, List<File> found, Set<String> processed, int depth) async {
    if (depth > 4) return; 
    try {
      final List<FileSystemEntity> entities = await dir.list(followLinks: false).toList();
      for (var e in entities) {
         if (e is Directory) {
            final name = e.path.split('/').last;
            if (!name.startsWith('.') && name != 'Android') { 
               await _recursiveScan(e, found, processed, depth + 1);
            }
         } else if (e is File) {
            final name = e.path.split('/').last;
            if (processed.contains(e.path)) continue;
            
            final ext = name.split('.').last.toLowerCase();
            if (widget.allowedExtensions.contains(ext)) {
               found.add(e);
               processed.add(e.path);
            }
         }
      }
    } catch (_) {}
  }
  
  // --- FOLDER BROWSER LOGIC ---
  Future<void> _refreshFolderFiles() async {
    setState(() {
      _isLoadingFolder = true;
      _errorMessage = null;
    });

    try {
      final List<FileSystemEntity> entities = await _currentDirectory.list(followLinks: false).toList();
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      final filtered = entities.where((e) {
        final name = e.path.split('/').last;
        if (name.startsWith('.')) return false;
        if (e is Directory) return true;
        if (e is File) {
           final ext = name.split('.').last.toLowerCase();
           return widget.allowedExtensions.contains(ext);
        }
        return false;
      }).toList();

      setState(() {
        _folderFiles = filtered;
        _isLoadingFolder = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Access Denied";
        _isLoadingFolder = false;
      });
    }
  }

  // --- SELECTION LOGIC ---
  void _onFileTap(String path) {
     if (_isSelectionMode) {
        setState(() {
           if (_selectedPaths.contains(path)) {
              _selectedPaths.remove(path);
              if (_selectedPaths.isEmpty) _isSelectionMode = false;
           } else {
              _selectedPaths.add(path);
           }
        });
     } else {
        // Single Pick (Legacy behavior, but return as List)
        Navigator.pop(context, [path]);
     }
  }

  void _onFileLongPress(String path) {
     setState(() {
        _isSelectionMode = true;
        _selectedPaths.add(path);
     });
  }

  void _submitSelection() {
     Navigator.pop(context, _selectedPaths.toList());
  }

  void _onFolderTap(FileSystemEntity entity) {
    if (entity is Directory) {
      setState(() => _currentDirectory = entity);
      _refreshFolderFiles();
    } else if (entity is File) {
      _onFileTap(entity.path); 
    }
  }

  void _folderGoUp() {
    final parent = _currentDirectory.parent;
    if (parent.path == _currentDirectory.path) return;
    if (parent.path == '/storage/emulated') return;
    setState(() => _currentDirectory = parent);
    _refreshFolderFiles();
  }

  @override
  Widget build(BuildContext context) {
    final bool isGallery = _viewMode == 0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedPaths.length} Selected' : 'Select ${_getFileTypeLabel()}', style: const TextStyle(fontSize: 16)),
        leading: _isSelectionMode 
           ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedPaths.clear(); }))
           : (_currentDirectory.path == '/storage/emulated/0' 
                   ? const CloseButton() 
                   : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _folderGoUp)),
        actions: [
           if (_isSelectionMode)
              TextButton(
                 onPressed: _selectedPaths.isNotEmpty ? _submitSelection : null,
                 child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ),

           if (!_isSelectionMode)
           IconButton(
             icon: Icon(isGallery ? Icons.folder_open : Icons.grid_view),
             tooltip: isGallery ? 'Browse Folders' : 'Smart Gallery',
             onPressed: () {
                setState(() {
                   _viewMode = isGallery ? 1 : 0;
                });
                if (_viewMode == 1 && _folderFiles.isEmpty) {
                   _refreshFolderFiles();
                }
             },
           )
        ],
      ),
      body: isGallery ? _buildGalleryView() : _buildFolderView(),
    );
  }

  Widget _buildGalleryView() {
     if (_isScanning) {
        return const Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning storage...'),
          ],
        ));
     }
     
     if (_galleryFiles.isEmpty) {
        return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No files found.'),
            TextButton(
               onPressed: _startSmartScan,
               child: const Text('Rescan'),
            )
          ],
        ));
     }

     return Scrollbar(
       child: GridView.builder(
         padding: const EdgeInsets.all(8),
         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
           crossAxisCount: 3,
           childAspectRatio: 1.0, 
           crossAxisSpacing: 8,
           mainAxisSpacing: 8,
         ),
         itemCount: _galleryFiles.length,
         itemBuilder: (context, index) {
            final file = _galleryFiles[index];
            final name = file.path.split('/').last;
            final isVideo = widget.allowedExtensions.contains('mp4') || widget.allowedExtensions.contains('mkv');
            final isImage = widget.allowedExtensions.contains('jpg') || widget.allowedExtensions.contains('png');
            final isSelected = _selectedPaths.contains(file.path);

            return Material(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3.0),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _onFileTap(file.path),
                onLongPress: () => _onFileLongPress(file.path),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                     // Thumbnail Layer
                     if (isImage)
                        Image.file(file, fit: BoxFit.cover, cacheWidth: 200)
                     else if (isVideo)
                        _VideoThumbnailBox(file: file)
                     else
                        Center(child: Icon(_getFileIcon(name), size: 40, color: _getFileColor(name))),

                     // Name Gradient Layer
                     Positioned(
                       bottom: 0, left: 0, right: 0,
                       child: Container(
                         decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent])),
                         padding: const EdgeInsets.all(4),
                         child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                       ),
                     ),
                     
                     // Format Badge
                     if (!isSelected)
                     Positioned(
                       top: 4, right: 4,
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                         decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(3.0)),
                         child: Text(name.split('.').last.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8)),
                       ),
                     ),
                     
                     // SELECTION OVERLAY
                     if (isSelected)
                        Container(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          child: const Center(
                            child: Icon(Icons.check_circle, color: Colors.white, size: 32),
                          ),
                        )
                  ],
                ),
              ),
            );
         },
       ),
     );
  }


  Widget _buildFolderView() {
    if (_isLoadingFolder) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_upward, size: 20), onPressed: _folderGoUp),
              Expanded(child: Text(_currentDirectory.path.replaceAll('/storage/emulated/0', 'Internal'), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _folderFiles.length,
            itemBuilder: (context, index) {
               final entity = _folderFiles[index];
               final isDir = entity is Directory;
               final name = entity.path.split('/').last;
               return ListTile(
                 leading: Icon(isDir ? Icons.folder : _getFileIcon(name), color: isDir ? Colors.orange : _getFileColor(name)),
                 title: Text(name),
                 onTap: () => _onFolderTap(entity),
               );
            },
          ),
        ),
      ],
    );
  }

  String _getFileTypeLabel() {
     if (widget.allowedExtensions.contains('jpg')) return 'Image';
     if (widget.allowedExtensions.contains('pdf')) return 'PDF';
     if (widget.allowedExtensions.contains('zip')) return 'Zip';
     return 'Video';
  }

  IconData _getFileIcon(String name) {
     final ext = name.split('.').last.toLowerCase();
     if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) return Icons.image;
     if (['pdf'].contains(ext)) return Icons.picture_as_pdf;
     if (['zip', 'rar'].contains(ext)) return Icons.folder_zip;
     return Icons.video_file;
  }

  Color _getFileColor(String name) {
     final ext = name.split('.').last.toLowerCase();
     if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) return Colors.purple;
     if (['pdf'].contains(ext)) return Colors.redAccent;
     if (['zip', 'rar'].contains(ext)) return Colors.blueGrey;
     return Colors.red;
  }
}

class _VideoThumbnailBox extends StatefulWidget {
  final File file;
  const _VideoThumbnailBox({required this.file});

  @override
  State<_VideoThumbnailBox> createState() => _VideoThumbnailBoxState();
}

class _VideoThumbnailBoxState extends State<_VideoThumbnailBox> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      // Memory Only - No File Cache
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 128, 
        quality: 50,
      );
      if (mounted) setState(() => _bytes = uint8list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return Container(
      color: Colors.black12,
      child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white54)),
    );
  }
}



