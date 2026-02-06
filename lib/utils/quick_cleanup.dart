import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/bunny_cdn_service.dart';
import '../services/logger_service.dart';
import 'dart:async';

/// Simple, no-dialog direct deletion script
class QuickCleanup {
  
  /// Delete everything from Firestore AND BunnyCDN (PERMANENT!)
  static Future<void> deleteAllCoursesNow() async {
    try {
      LoggerService.info('STARTING COMPLETE DELETION (Firestore + BunnyCDN)...', tag: 'CLEANUP');
      
      final firestore = FirebaseFirestore.instance;
      final bunnyService = BunnyCDNService();
      
      final snapshot = await firestore.collection('courses').get();
      
      print('📊 Found ${snapshot.docs.length} courses');
      
      if (snapshot.docs.isEmpty) {
        print('✅ No courses to delete');
        return;
      }
      
      // STEP 1: Delete all files from BunnyCDN
      print('🔥 STEP 1: Deleting BunnyCDN files...');
      int filesDeleted = 0;
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final List<String> filesToDelete = [];

          // Collect thumbnail
          if (data['thumbnailUrl'] != null && data['thumbnailUrl'].toString().contains('b-cdn.net')) {
            filesToDelete.add(data['thumbnailUrl']);
          }
          
          // Collect certificates
          if (data['certificateUrl1'] != null && data['certificateUrl1'].toString().contains('b-cdn.net')) {
            filesToDelete.add(data['certificateUrl1']);
          }
          if (data['certificateUrl2'] != null && data['certificateUrl2'].toString().contains('b-cdn.net')) {
            filesToDelete.add(data['certificateUrl2']);
          }

          // Recursively collect ALL content files (videos, PDFs, images, thumbnails)
          void collectFiles(List<dynamic> items) {
            for (var item in items) {
              // Main file
              if (item['path'] != null && item['path'].toString().contains('b-cdn.net')) {
                filesToDelete.add(item['path']);
              }
              // Thumbnail
              if (item['thumbnail'] != null && item['thumbnail'].toString().contains('b-cdn.net')) {
                filesToDelete.add(item['thumbnail']);
              }
              // Recurse into folders
              if (item['type'] == 'folder' && item['contents'] != null) {
                collectFiles(item['contents']);
              }
            }
          }

          if (data['contents'] != null) {
            collectFiles(data['contents']);
          }
          
          // Collect demo videos


          // Delete each file from BunnyCDN
          for (var fileUrl in filesToDelete) {
            try {
              await bunnyService.deleteFile(fileUrl);
              filesDeleted++;
              print('  ✅ Deleted file: ${fileUrl.split('/').last}');
            } catch (e) {
              print('  ⚠️ Failed to delete $fileUrl: $e');
            }
          }
        } catch (e) {
          print('⚠️ Error processing course ${doc.id}: $e');
        }
      }
      
      print('🔥 Deleted $filesDeleted files from BunnyCDN');
      
      // STEP 2: Delete Firestore documents
      print('🔥 STEP 2: Deleting Firestore documents...');
      final batch = firestore.batch();
      for (var doc in snapshot.docs) {
        print('  🗑️ Deleting: ${doc.id}');
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('✅ Deleted ${snapshot.docs.length} Firestore documents!');
      
      // STEP 3: Clean local storage
      print('🔥 STEP 3: Cleaning local storage...');
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Clear upload queue
        await prefs.remove('upload_queue_v1');
        print('  ✅ Cleared upload queue');
        
        // Clear pending course
        await prefs.remove('pending_course_v1');
        print('  ✅ Cleared pending course');
        
        // Clear course draft
        await prefs.remove('course_creation_draft');
        print('  ✅ Cleared course draft');
        
        // Delete pending_uploads directory
        final appDir = await getApplicationDocumentsDirectory();
        final pendingUploadsDir = Directory('${appDir.path}/pending_uploads');
        if (await pendingUploadsDir.exists()) {
          await pendingUploadsDir.delete(recursive: true);
          print('  ✅ Deleted pending_uploads directory');
        }
        
        print('✅ Local storage cleaned!');
      } catch (e) {
        print('⚠️ Local cleanup warning: $e');
      }
      
      print('✅ COMPLETE! Deleted ${snapshot.docs.length} courses + $filesDeleted files!');
      
    } catch (e, stack) {
      LoggerService.error('ERROR: $e', tag: 'CLEANUP', stackTrace: stack);
    }
  }

  /// Show a simple button to trigger deletion
  static void showQuickDeleteButton(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: const Text('⚠️ Quick Delete'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text(
              'This will PERMANENTLY DELETE:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              '• All courses from Firebase\n'
              '• All videos from BunnyCDN\n'
              '• All images & PDFs\n'
              '• All thumbnails\n'
              '• Local upload queue\n'
              '• Local drafts & cache\n'
              '• Everything!',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'NO CONFIRMATION, NO UNDO!',
              style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog first
              
              // Show loading
              unawaited(showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const PopScope(
                  canPop: false,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Deleting...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ));
              
              // Execute
              await deleteAllCoursesNow();
              
              // Close loading and show result
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ All courses deleted!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE NOW'),
          ),
        ],
      ),
    );
  }
}
