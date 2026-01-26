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
          ),
        ),
      );
    } else if (item['type'] == 'video') {
      final videoList = _contents.where((e) => e['type'] == 'video').toList();
      final initialIndex = videoList.indexOf(item);
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

    return ListView.builder(
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
        );
      },
    );
  }
}
