import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/app_theme.dart';
import '../../services/bunny_cdn_service.dart';
import '../../services/logger_service.dart';
import '../../services/config_service.dart';
import 'dart:async';

// ══════════════════════════════════════════════════════════════════════════════
// MASTER COURSE DELETE SCREEN & LOGIC (Single Source of Truth)
// ══════════════════════════════════════════════════════════════════════════════

class MasterCourseDeleteScreen extends StatefulWidget {
  const MasterCourseDeleteScreen({super.key});

  @override
  State<MasterCourseDeleteScreen> createState() =>
      _MasterCourseDeleteScreenState();
}

class _MasterCourseDeleteScreenState extends State<MasterCourseDeleteScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Course Delete'),
        actions: [
          TextButton.icon(
            onPressed: _isProcessing
                ? null
                : () => _showMasterDeleteDialog(context),
            icon: const Icon(Icons.warning, color: Colors.red),
            label: const Text(
              'WIPE ALL',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('courses').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Text('Database is clean!', style: AppTheme.heading3(context)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.red),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Master Course Delete: Backend and Frontend All Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final course = docs[index];
                    final data = course.data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Untitled Course';
                    final courseId = course.id;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: () {
                          String? thumbUrl;
                          if (data.containsKey('media_assets')) {
                            thumbUrl = data['media_assets']['thumbnailUrl'];
                          }
                          thumbUrl ??= data['thumbnailUrl'] ?? data['imageUrl'];

                          if (thumbUrl != null && thumbUrl.isNotEmpty) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                thumbUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image_not_supported),
                              ),
                            );
                          }
                          return const Icon(Icons.book);
                        }(),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'ID: $courseId',
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          onPressed: () => _confirmIndividualDelete(
                            context,
                            courseId,
                            title,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // UI - DIALOGS & OVERLAYS
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _showMasterDeleteDialog(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color subTextColor =
        Theme.of(context).textTheme.bodySmall?.color ??
        (isDark ? Colors.white70 : Colors.black54);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 24,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: surfaceColor,
              border: Border.all(
                color: isDark
                    ? Colors.red.withOpacity(0.2)
                    : Colors.transparent,
              ),
              gradient: isDark
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [surfaceColor, Colors.red.shade50],
                    ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.dangerous_outlined,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'NUCLEAR WIPE',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.red,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete System Data Reset',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.red.shade300 : Colors.red.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.red.withOpacity(0.2)),
                const SizedBox(height: 16),
                _buildDetailRow(
                  context,
                  Icons.cloud_off,
                  'FIRESTORE',
                  'All Course documents & records',
                ),
                _buildDetailRow(
                  context,
                  Icons.video_collection_outlined,
                  'BUNNY STREAM',
                  'All videos from your library',
                ),
                _buildDetailRow(
                  context,
                  Icons.photo_library_outlined,
                  'BUNNY STORAGE',
                  'Thumbnails, covers, & images',
                ),
                _buildDetailRow(
                  context,
                  Icons.picture_as_pdf_outlined,
                  'STORAGE FILES',
                  'All PDF notes & study materials',
                ),
                _buildDetailRow(
                  context,
                  Icons.workspace_premium_outlined,
                  'CERTIFICATES',
                  'All generated student certificates',
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Irreversible. Cloud data will be destroyed forever.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.red.shade200
                                : Colors.red.shade900,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: subTextColor,
                        ),
                        child: const Text(
                          'SAFE EXIT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _startMasterWipe();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'WIPE NOW',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String sub,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black);
    final Color subTextColor =
        Theme.of(context).textTheme.bodySmall?.color ??
        (isDark ? Colors.white70 : Colors.black54);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.red.shade400),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                Text(sub, style: TextStyle(color: subTextColor, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmIndividualDelete(
    BuildContext context,
    String courseId,
    String title,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course?'),
        content: Text(
          'This will permanently delete "$title" and all its videos/files from the server. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _startIndividualDelete(courseId, title);
    }
  }

  void _showProcessingOverlay(String message, String sub) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.red),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  decoration: TextDecoration.none,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // LOGIC - BACKEND OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _startMasterWipe() async {
    setState(() => _isProcessing = true);
    _showProcessingOverlay(
      'INITIATING SYSTEM WIPE...',
      'Cleaning cloud storage & databases',
    );

    try {
      await _deleteAllDataLogic();
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ System wiped successfully!'),
            backgroundColor: Colors.black,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Wipe Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startIndividualDelete(String courseId, String title) async {
    setState(() => _isProcessing = true);
    _showProcessingOverlay('DELETING COURSE...', 'Removing files from server');

    try {
      await _deleteSingleCourseLogic(courseId);
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted $title'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete course: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteAllDataLogic() async {
    LoggerService.info('🔥 MASTER DELETE: STARTING...', tag: 'CLEANUP');
    final firestore = FirebaseFirestore.instance;
    final bunnyService = BunnyCDNService();
    final config = ConfigService();
    if (!config.isReady) await config.initialize();

    final String mainLibraryId = config.bunnyLibraryId;
    final String mainApiKey = config.bunnyStreamKey;

    // 1. Storage
    await bunnyService.deleteFolder('courses');

    // 2. Stream Videos & Collections (Bulk)
    try {
      await bunnyService.deleteAllVideosFromLibrary(
        libraryId: mainLibraryId,
        apiKey: mainApiKey,
      );
    } catch (e) {
      LoggerService.error('Bulk video delete error: $e', tag: 'CLEANUP');
    }

    // 3. Firestore (Batch)
    final snapshot = await firestore.collection('courses').get();
    final batch = firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _deleteSingleCourseLogic(String courseId) async {
    final firestore = FirebaseFirestore.instance;
    final bunnyService = BunnyCDNService();
    final config = ConfigService();
    if (!config.isReady) await config.initialize();

    final String mainLibraryId = config.bunnyLibraryId;
    final String mainApiKey = config.bunnyStreamKey;

    final doc = await firestore.collection('courses').doc(courseId).get();
    if (doc.exists) {
      final data = doc.data()!;

      // 1. Delete Bunny Stream Collection (Folder System)
      final String? collectionId =
          data['media_assets']?['bunnyCollectionId']?.toString() ??
          data['bunnyCollectionId']?.toString();

      if (collectionId != null && collectionId.isNotEmpty) {
        LoggerService.info(
          "Deleting Bunny Stream Collection: $collectionId",
          tag: 'CLEANUP',
        );
        await bunnyService.deleteCollectionWithVideos(
          libraryId: mainLibraryId,
          apiKey: mainApiKey,
          collectionId: collectionId,
        );
      }

      // 2. Individual video cleanup (Legacy/Fallback)
      final contents = data['curriculum'] ?? data['contents'] ?? [];
      for (var content in contents) {
        if (content is Map &&
            content['type'] == 'video' &&
            content['videoId'] != null) {
          await bunnyService.deleteVideo(
            libraryId: content['libraryId'] ?? mainLibraryId,
            videoId: content['videoId'],
            apiKey: content['streamApiKey'] ?? mainApiKey,
          );
        }
      }
    }

    // 3. Storage Cleanup
    await bunnyService.deleteFolder('courses/$courseId');
    // 4. Firestore Cleanup
    await firestore.collection('courses').doc(courseId).delete();
  }
}
