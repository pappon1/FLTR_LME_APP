import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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
  
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPath();
  }

  Future<void> _initPath() async {
    // 1. Permissions
    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.isGranted) {
        // Try requesting
        final status = await Permission.manageExternalStorage.request();
        // If that fails or is not available (older android), try storage
        if (!status.isGranted) {
             if (!await Permission.storage.isGranted) {
                 await Permission.storage.request();
             }
        }
      }
    }

    // 2. Initialize Folder View Path
    final rootPath = widget.initialPath ?? '/storage/emulated/0';
    _currentDirectory = Directory(rootPath);
    if (!await _currentDirectory.exists()) {
       _currentDirectory = Directory.systemTemp;
    }

    // 3. Start Smart Scan
    _startSmartScan();
  }

  // --- SMART SCAN LOGIC ---
  Future<void> _startSmartScan() async {
    setState(() {
      _isScanning = true;
      _galleryFiles.clear();
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
      
      // Sort by Recent (Modification Date)
      // Getting stats for all files might be slow, so we sort by path or just reverse finding order?
      // Let's try to get stats for the top 50, but for now just show them.
      // Reversing gives a slight "recent-ish" feel if system returns chronological
      
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
    if (depth > 4) return; // Prevent too deep
    try {
      final List<FileSystemEntity> entities = await dir.list(followLinks: false).toList();
      for (var e in entities) {
         if (e is Directory) {
            final name = e.path.split('/').last;
            if (!name.startsWith('.') && name != 'Android') { // Skip hidden and Android data
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

  void _onFolderTap(FileSystemEntity entity) {
    if (entity is Directory) {
      setState(() => _currentDirectory = entity);
      _refreshFolderFiles();
    } else if (entity is File) {
      Navigator.pop(context, entity.path);
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
        title: Text('${_getFileTypeLabel()} Selector', style: const TextStyle(fontSize: 16)),
        actions: [
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
       child: ListView.builder(
         itemCount: _galleryFiles.length,
         itemBuilder: (context, index) {
            final file = _galleryFiles[index];
            final name = file.path.split('/').last;
            
            return ListTile(
              leading: Icon(_getFileIcon(name), color: _getFileColor(name)),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(file.path.replaceFirst('/storage/emulated/0/', ''), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              onTap: () => Navigator.pop(context, file.path),
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

