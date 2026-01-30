import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_mobile_engineer_official/models/course_model.dart';
import 'package:local_mobile_engineer_official/services/firestore_service.dart';
import 'package:local_mobile_engineer_official/screens/courses/components/course_content_list_item.dart';
import 'package:local_mobile_engineer_official/screens/courses/folder_detail_screen.dart';
import 'package:local_mobile_engineer_official/screens/content_viewers/video_player_screen.dart';
import 'package:local_mobile_engineer_official/screens/content_viewers/pdf_viewer_screen.dart';
import 'package:local_mobile_engineer_official/screens/content_viewers/image_viewer_screen.dart';

class CourseContentTab extends StatefulWidget {
  final CourseModel course;
  final FirestoreService firestoreService;

  const CourseContentTab({
    super.key,
    required this.course,
    required this.firestoreService,
  });

  @override
  State<CourseContentTab> createState() => _CourseContentTabState();
}

class _CourseContentTabState extends State<CourseContentTab> {
  late List<Map<String, dynamic>> _contents;

  @override
  void initState() {
    super.initState();
    print("🔍 [DEBUG] RAW CONTENTS FROM FIRESTORE: ${widget.course.contents}");
    _contents = List<Map<String, dynamic>>.from(widget.course.contents);
  }


  void _handleContentTap(Map<String, dynamic> item, int index) {
    if (item['type'] == 'folder') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FolderDetailScreen(
            folderName: item['name'],
            contentList: (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [],
            isReadOnly: true, // Enable Read-Only
          ),
        ),
      );
    } else if (item['type'] == 'video') {
      print('🎥 [VIDEO TAP] Original item: ${item['path']}');
      
      // Convert all iframe URLs to actual video URLs
      final videoList = _contents
          .where((e) => e['type'] == 'video')
          .map((video) {
            final converted = Map<String, dynamic>.from(video);
            final path = video['path'];
            
            // Convert iframe URL to actual video URL
            if (path != null && path.toString().contains('iframe.mediadelivery.net')) {
              final videoId = path.toString().split('/').last;
              converted['path'] = 'https://vz-583681.b-cdn.net/$videoId/playlist.m3u8';
              
              print('🔄 [CONVERT] ${video['name']}: $path → ${converted['path']}');
              
              // Add thumbnail if missing
              if (converted['thumbnail'] == null) {
                converted['thumbnail'] = 'https://vz-583681.b-cdn.net/$videoId/thumbnail.jpg';
                print('🖼️ [THUMBNAIL] Generated: ${converted['thumbnail']}');
              }
            } else {
              print('⚠️ [SKIP] ${video['name']}: Not an iframe URL');
            }
            
            return converted;
          })
          .toList();
      
      print('📋 [PLAYLIST] Total videos: ${videoList.length}');
      
      final initialIndex = videoList.indexWhere((e) => e['name'] == item['name']);
      
      print('▶️ [PLAY] Starting at index: $initialIndex');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            playlist: videoList,
            initialIndex: initialIndex >= 0 ? initialIndex : 0,
          ),
        ),
      );
    } else if (item['type'] == 'pdf') {
      final String? url = item['url'] ?? item['path'];
      if (url == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PDFViewerScreen(
            filePath: url,
            title: item['name'],
            isNetwork: url.startsWith('http'),
          ),
        ),
      );
    } else if (item['type'] == 'image') {
      final String? url = item['url'] ?? item['path'];
      if (url == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageViewerScreen(
            filePath: url,
            title: item['name'],
            isNetwork: url.startsWith('http'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_contents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              "No content available for this course.",
              style: GoogleFonts.manrope(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _contents.length,
        itemBuilder: (context, index) {
          final item = _contents[index];
          return CourseContentListItem(
            item: item,
            index: index,
            isSelected: false,
            isSelectionMode: false,
            isDragMode: false,
            onTap: () => _handleContentTap(item, index),
            onToggleSelection: () {},
            onEnterSelectionMode: () {},
            onStartHold: () {},
            onCancelHold: () {},
            onRename: () {},
            onRemove: () {},
            isReadOnly: false,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.red,
        child: const Icon(Icons.bug_report, color: Colors.white),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('🔍 DEBUG: Raw Server Data'),
              content: SingleChildScrollView(
                child: SelectableText(
                  'Total Items: ${_contents.length}\n\n'
                  'Full JSON:\n${const JsonEncoder.withIndent('  ').convert(_contents)}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
