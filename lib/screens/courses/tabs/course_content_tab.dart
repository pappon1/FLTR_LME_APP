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
            contentList:
                (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [],
            isReadOnly: true, // Enable Read-Only
          ),
        ),
      );
    } else if (item['type'] == 'video') {
      // Convert all iframe URLs to actual video URLs
      final List<Map<String, dynamic>> videoList = _contents
          .where((e) => e['type'] == 'video')
          .map((video) {
            final converted = Map<String, dynamic>.from(video);
            final path = video['path'];

            // Convert iframe URL to actual video URL
            if (path != null &&
                path.toString().contains('iframe.mediadelivery.net')) {
              final videoId = path.toString().split('/').last;
              converted['path'] =
                  'https://vz-583681.b-cdn.net/$videoId/playlist.m3u8';

              // Add thumbnail if missing
              if (converted['thumbnail'] == null) {
                converted['thumbnail'] =
                    'https://vz-583681.b-cdn.net/$videoId/thumbnail.jpg';
              }
            }

            return converted;
          })
          .toList();

      final initialIndex = videoList.indexWhere(
        (e) => e['name'] == item['name'],
      );

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
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "No content available for this course.",
              style: GoogleFonts.manrope(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      key: const PageStorageKey('content_tab'),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = _contents[index];
              return CourseContentListItem(
                item: item,
                index: index,
                isSelected: false,
                isSelectionMode: false,
                isDragMode: false,
                leftOffset: 5.0, // Matches UIConstants.contentItemLeftOffset
                videoThumbTop: 0.50, // Matches UIConstants.videoThumbTop
                videoThumbBottom: 0.50, // Matches UIConstants.videoThumbBottom
                imageThumbTop: 0.50, // Matches UIConstants.imageThumbTop
                imageThumbBottom: 0.50, // Matches UIConstants.imageThumbBottom
                bottomSpacing: 5.0, // Matches UIConstants.itemBottomSpacing
                tagLabelFontSize: 6.0, // Matches UIConstants.tagLabelFontSize
                onTap: () => _handleContentTap(item, index),
                onToggleSelection: () {},
                onEnterSelectionMode: () {},
                onStartHold: () {},
                onCancelHold: () {},
                onRename: () {},
                onRemove: () {},
                isReadOnly: true,
              );
            }, childCount: _contents.length),
          ),
        ),
      ],
    );
  }
}
