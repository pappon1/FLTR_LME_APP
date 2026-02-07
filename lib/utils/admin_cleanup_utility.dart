import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bunny_cdn_service.dart';
import '../services/logger_service.dart';
import 'dart:async';

class AdminCleanupUtility {
  static Future<void> showCleanupDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('⚠️ Admin Cleanup'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose cleanup option:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),

            _buildCleanupOption(
              context,
              icon: Icons.delete_outline,
              title: 'Delete All Courses',
              subtitle: 'Only Firestore data',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _deleteAllCourses(context, deleteFiles: false);
              },
            ),

            const SizedBox(height: 12),

            _buildCleanupOption(
              context,
              icon: Icons.delete_forever,
              title: 'Nuclear Cleanup',
              subtitle: 'Firestore + BunnyCDN files',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deleteAllCourses(context, deleteFiles: true);
              },
            ),

            const SizedBox(height: 12),

            _buildCleanupOption(
              context,
              icon: Icons.restart_alt,
              title: 'Complete Reset',
              subtitle: 'Everything + local drafts',
              color: Colors.deepPurple,
              onTap: () {
                Navigator.pop(context);
                _completeReset(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  static Widget _buildCleanupOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(3.0),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  static Future<void> _deleteAllCourses(
    BuildContext context, {
    required bool deleteFiles,
  }) async {
    // SAFETY CHECK 1: Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '⚠️ DANGEROUS OPERATION',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will PERMANENTLY delete:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _buildWarningItem('All courses from Firestore'),
            if (deleteFiles) ...[
              _buildWarningItem('All files from BunnyCDN'),
              _buildWarningItem('All thumbnails and media'),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(3.0),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action CANNOT be undone!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('I UNDERSTAND, PROCEED'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // SAFETY CHECK 2: Type confirmation
    final typeConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('🔐 Final Confirmation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Type "DELETE EVERYTHING" to confirm:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'DELETE EVERYTHING',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim() == 'DELETE EVERYTHING') {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Incorrect confirmation text'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('CONFIRM DELETE'),
            ),
          ],
        );
      },
    );

    if (typeConfirmed != true) return;
    if (!context.mounted) return;

    // Show Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                'Deleting... Please wait',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                deleteFiles ? 'This may take a while...' : 'Almost done...',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final firestore = FirebaseFirestore.instance;

      // Step 1: Get all courses
      final coursesSnapshot = await firestore.collection('courses').get();
      LoggerService.info(
        'Found ${coursesSnapshot.docs.length} courses to delete',
        tag: 'CLEANUP',
      );

      // Step 2: Delete files from BunnyCDN (if requested)
      if (deleteFiles) {
        final bunnyService = BunnyCDNService();

        for (var doc in coursesSnapshot.docs) {
          try {
            final data = doc.data();
            final List<String> filesToDelete = [];

            // Collect all file URLs
            if (data['thumbnailUrl'] != null)
              filesToDelete.add(data['thumbnailUrl']);
            if (data['certificateUrl1'] != null)
              filesToDelete.add(data['certificateUrl1']);
            if (data['certificateUrl2'] != null)
              filesToDelete.add(data['certificateUrl2']);

            // Recursively collect content files
            void collectFiles(List<dynamic> items) {
              for (var item in items) {
                if (item['path'] != null &&
                    item['path'].toString().contains('b-cdn.net')) {
                  filesToDelete.add(item['path']);
                }
                if (item['thumbnail'] != null &&
                    item['thumbnail'].toString().contains('b-cdn.net')) {
                  filesToDelete.add(item['thumbnail']);
                }
                if (item['type'] == 'folder' && item['contents'] != null) {
                  collectFiles(item['contents']);
                }
              }
            }

            if (data['contents'] != null) collectFiles(data['contents']);

            // Delete each file
            for (var fileUrl in filesToDelete) {
              try {
                await bunnyService.deleteFile(fileUrl);
                LoggerService.success('Deleted: $fileUrl', tag: 'CLEANUP');
              } catch (e) {
                LoggerService.warning(
                  'Failed to delete $fileUrl: $e',
                  tag: 'CLEANUP',
                );
              }
            }
          } catch (e) {
            LoggerService.error(
              'Error processing course ${doc.id}: $e',
              tag: 'CLEANUP',
            );
          }
        }
      }

      // Step 3: Delete all Firestore documents
      final batch = firestore.batch();
      for (var doc in coursesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      LoggerService.success(
        'Deleted ${coursesSnapshot.docs.length} courses from Firestore',
        tag: 'CLEANUP',
      );

      // Close progress dialog
      if (context.mounted) {
        Navigator.pop(context);

        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Successfully deleted ${coursesSnapshot.docs.length} courses${deleteFiles ? ' and all associated files' : ''}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Cleanup Error: $e', tag: 'CLEANUP');
      if (context.mounted) {
        Navigator.pop(context); // Close progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  static Future<void> _completeReset(BuildContext context) async {
    // First delete courses
    await _deleteAllCourses(context, deleteFiles: true);

    // Then clear local data
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      LoggerService.success('Cleared all local storage', tag: 'CLEANUP');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Complete reset successful! App is now fresh.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Error clearing local storage: $e', tag: 'CLEANUP');
    }
  }

  static Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.close, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
