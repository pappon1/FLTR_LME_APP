import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../utils/clipboard_manager.dart';
import '../../../utils/simple_file_explorer.dart';
import '../../../../utils/app_theme.dart';
import 'package:media_kit/media_kit.dart';
import 'state_manager.dart';
import 'draft_manager.dart';

class ContentManager {
  final CourseStateManager state;
  final DraftManager draftManager;

  ContentManager(this.state, this.draftManager);

  Future<void> pickContentFile(
    BuildContext context,
    String type, [
    List<String>? allowedExtensions,
  ]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SimpleFileExplorer(allowedExtensions: allowedExtensions ?? []),
      ),
    );

    if (result != null && result is List) {
      final List<String> paths = result.cast<String>();
      if (paths.isEmpty) return;

      final List<Map<String, dynamic>> newItems = [];
      for (var path in paths) {
        String name = path.split('/').last;
        if (name.length > 40) {
          final extensionIndex = name.lastIndexOf('.');
          if (extensionIndex != -1 && name.length - extensionIndex < 10) {
            final ext = name.substring(extensionIndex);
            name = name.substring(0, 40 - ext.length) + ext;
          } else {
            name = name.substring(0, 40);
          }
        }
        newItems.add({
          'type': type,
          'name': name,
          'path': path,
          'isLocal': true,
          'isLocked': true,
          'thumbnail': null,
        });
      }

      state.courseContents.insertAll(0, newItems);
      state.updateState();

      if (type == 'video') {
        // Background scan for metadata
        unawaited(_processVideos(newItems));
      }

      unawaited(draftManager.saveCourseDraft());
    }
  }

  Future<void> _processVideos(List<Map<String, dynamic>> items) async {
    for (var item in items) {
      if (item['type'] == 'video' && item['path'] != null) {
        final duration = await _getVideoDuration(item['path']);
        if (duration > 0) {
          // Find the item in the list and update it
          final index = state.courseContents.indexWhere(
            (e) => e['path'] == item['path'],
          );
          if (index != -1) {
            state.courseContents[index]['duration'] = duration;
            state.updateState();
            unawaited(draftManager.saveCourseDraft());
          }
        }
      }
    }
  }

  Future<int> _getVideoDuration(String path) async {
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
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );

      final dur = player.state.duration;
      await sub.cancel();
      await player.dispose();

      return dur.inSeconds;
    } catch (e) {
      await player.dispose();
      return 0;
    }
  }

  void pasteContent(BuildContext context) {
    if (ContentClipboard.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
      return;
    }

    final List<Map<String, dynamic>> itemsToPaste = [];
    final List<String> skippedNames = [];
    final Set<String> existingNames = state.courseContents
        .map((e) => e['name'].toString())
        .toSet();

    for (var item in ContentClipboard.items!) {
      if (existingNames.contains(item['name'])) {
        skippedNames.add(item['name']);
      } else {
        itemsToPaste.add(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(item))),
        );
      }
    }

    if (itemsToPaste.isEmpty && skippedNames.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Conflict: "${skippedNames.join(', ')}" already exists in this root.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    for (var newItem in itemsToPaste) {
      newItem['isLocal'] = true;
      newItem['isLocked'] = true;
    }

    state.courseContents.insertAll(0, itemsToPaste);
    state.updateState();
    unawaited(draftManager.saveCourseDraft());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ContentClipboard.items!.length} items pasted')),
    );
  }

  Future<void> confirmRemoveContent(BuildContext context, int index) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Content'),
        content: Text(
          'Are you sure you want to remove "${state.courseContents[index]['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Free up cache space logic from original
      final item = state.courseContents[index];
      final path = item['path'];
      if (path != null && path.toString().contains('/cache/')) {
        try {
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }

      state.courseContents.removeAt(index);
      state.updateState();
      unawaited(draftManager.saveCourseDraft());
    }
  }

  void showCreateFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: 'Folder Name',
            counterText: "",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3.0),
            ),
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                state.courseContents.insert(0, {
                  'type': 'folder',
                  'name': name,
                  'isLocal': true,
                  'isLocked': true,
                  'contents': [],
                });
                state.updateState();
                unawaited(draftManager.saveCourseDraft());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3.0),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void pasteFromClipboard(BuildContext context) {
    pasteContent(context);
  }

  void handleBulkCopyCut(BuildContext context, bool isCut) {
    if (state.selectedIndices.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCut ? 'Cut Items?' : 'Copy Items?'),
        content: Text(
          '${isCut ? 'Cut' : 'Copy'} ${state.selectedIndices.length} items to clipboard?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final List<Map<String, dynamic>> itemsToCopy = [];
              for (var index in state.selectedIndices) {
                itemsToCopy.add(state.courseContents[index]);
              }

              if (isCut) {
                ContentClipboard.cut(itemsToCopy);
                final List<int> sortedIndices = state.selectedIndices.toList()
                  ..sort((a, b) => b.compareTo(a));
                for (var index in sortedIndices) {
                  state.courseContents.removeAt(index);
                }
              } else {
                ContentClipboard.copy(itemsToCopy);
              }

              state.selectedIndices.clear();
              state.isSelectionMode = false;
              state.updateState();
              unawaited(draftManager.saveCourseDraft());

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${itemsToCopy.length} items ${isCut ? 'cut' : 'copied'}',
                  ),
                ),
              );
            },
            child: Text(isCut ? 'Cut' : 'Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> handleBulkDelete(BuildContext context) async {
    if (state.selectedIndices.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${state.selectedIndices.length} items?'),
        content: const Text(
          'Are you sure you want to delete all selected items?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final List<int> sortedIndices = state.selectedIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (var index in sortedIndices) {
        // Free up cache space logic from original
        final item = state.courseContents[index];
        final path = item['path'];
        if (path != null && path.toString().contains('/cache/')) {
          try {
            final file = File(path);
            if (file.existsSync()) file.deleteSync();
          } catch (_) {}
        }
        state.courseContents.removeAt(index);
      }
      state.selectedIndices.clear();
      state.isSelectionMode = false;
      state.updateState();
      unawaited(draftManager.saveCourseDraft());
    }
  }

  // NEW: Rename Content Method
  void renameContent(BuildContext context, int index) {
    final TextEditingController renameController = TextEditingController(
      text: state.courseContents[index]['name'],
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Content'),
        content: TextField(
          controller: renameController,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            counterText: "",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (renameController.text.trim().isNotEmpty) {
                state.courseContents[index]['name'] = renameController.text
                    .trim();
                state.updateState();
                unawaited(draftManager.saveCourseDraft());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  // NEW: Show Thumbnail Manager Dialog
  void showThumbnailManagerDialog(BuildContext context, int index) {
    String? errorMessage;
    bool isProcessing = false;
    String? currentThumbnail = state.courseContents[index]['thumbnail'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool hasThumbnail = currentThumbnail != null;

            Future<void> pickAndValidate() async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SimpleFileExplorer(
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                  ),
                ),
              );

              if (result != null && result is List && result.isNotEmpty) {
                setDialogState(() => isProcessing = true);
                final String filePath = result.first as String;

                try {
                  final File file = File(filePath);
                  final decodedImage = await decodeImageFromList(
                    await file.readAsBytes(),
                  );

                  final double ratio = decodedImage.width / decodedImage.height;
                  if (ratio < 1.7 || ratio > 1.85) {
                    setDialogState(() {
                      errorMessage =
                          "Invalid Ratio: ${ratio.toStringAsFixed(2)}\n\n"
                          "Required: 16:9 (YouTube Standard)\n"
                          "Please crop your image to 1920x1080.";
                      isProcessing = false;
                    });
                    return;
                  }

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
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (hasThumbnail)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3.0),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.file(
                              File(currentThumbnail!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Center(child: Icon(Icons.broken_image)),
                            ),
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
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                          style: BorderStyle.solid,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No Thumbnail',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                  if (isProcessing)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: pickAndValidate,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: Text(hasThumbnail ? 'Change' : 'Add Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (hasThumbnail)
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() => currentThumbnail = null);
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    state.courseContents[index]['thumbnail'] = currentThumbnail;
                    state.updateState();
                    unawaited(draftManager.saveCourseDraft());
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thumbnail Saved!')),
                    );
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
