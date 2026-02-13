import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_mobile_engineer_official/models/course_model.dart';
import 'package:local_mobile_engineer_official/services/firestore_service.dart';
import 'package:local_mobile_engineer_official/screens/courses/components/course_content_list_item.dart';
import 'package:local_mobile_engineer_official/screens/courses/folder_detail_screen.dart';
import 'package:local_mobile_engineer_official/screens/content_viewers/video_player_screen.dart';
import 'package:local_mobile_engineer_official/screens/content_viewers/pdf_viewer_screen.dart';
import 'package:local_mobile_engineer_official/screens/content_viewers/image_viewer_screen.dart';
import 'package:local_mobile_engineer_official/services/config_service.dart';

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
    _contents = _normalizeContents(widget.course.contents);
  }

  @override
  void didUpdateWidget(covariant CourseContentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course.contents != widget.course.contents) {
      setState(() {
        _contents = _normalizeContents(widget.course.contents);
      });
    }
  }

  List<Map<String, dynamic>> _normalizeContents(List<dynamic> rawContents) {
    final cdnHost = ConfigService().bunnyStreamCdnHost;
    debugPrint('🛠️ [NORMALIZE] Using CDN Host: $cdnHost');
    
    return rawContents.map((item) {
      final converted = Map<String, dynamic>.from(item);
      final String? rawPath = (converted['path'] ?? converted['videoUrl'] ?? converted['url'])?.toString();

      if (rawPath != null && rawPath.contains(cdnHost)) {
        try {
          final uri = Uri.parse(rawPath);
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

          String? videoId;
          if (segments.isNotEmpty) {
            try {
              videoId = segments.firstWhere(
                (s) => s.length > 20 && !s.contains('.'),
                orElse: () => segments[0],
              );
            } catch (_) {
              videoId = segments[0];
            }
          }

          if (videoId != null && videoId != cdnHost && !videoId.startsWith('http') && videoId.length > 5) {
            if (videoId.contains('?')) videoId = videoId.split('?').first;

            // Standardize to HLS path
            converted['path'] = 'https://$cdnHost/$videoId/playlist.m3u8';
            
            // Only set fallback thumbnail if missing
            if (converted['thumbnail'] == null ||
                converted['thumbnail'].toString().isEmpty ||
                !converted['thumbnail'].toString().startsWith('http')) {
              final String thumbUrl = 'https://$cdnHost/$videoId/thumbnail.jpg';
              converted['thumbnail'] = thumbUrl;
              converted['thumbnailUrl'] = thumbUrl;
            } else if (converted['thumbnailUrl'] == null ||
                       converted['thumbnailUrl'].toString().isEmpty ||
                       !converted['thumbnailUrl'].toString().startsWith('http')) {
              converted['thumbnailUrl'] = converted['thumbnail'];
            }
            
            debugPrint('✅ [NORMALIZE] Standardized Video: ${converted['name']} -> ID: $videoId');
          }
        } catch (e) {
          debugPrint('❌ [NORMALIZE] Error: $e');
        }
      }
      return converted;
    }).toList();
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
            isReadOnly: true, // Back to read-only
          ),
        ),
      );
    } else if (item['type'] == 'video') {
      final List<Map<String, dynamic>> videoList = _contents
          .where((e) => e['type'] == 'video')
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
      physics: const AlwaysScrollableScrollPhysics(),
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
