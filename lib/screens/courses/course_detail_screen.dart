import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/course_model.dart';
import '../../models/video_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_video_player.dart';
import 'add_video_screen.dart';
import '../content_viewers/video_player_screen.dart';
import '../content_viewers/pdf_viewer_screen.dart';
import 'folder_detail_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.course.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // TODO: Edit Course
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _confirmDelete(),
                ),
              ],
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryColor,
                  tabs: const [
                    Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Content'))),
                    Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Students'))),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildContentTab(),
            _buildStudentsTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_video_btn',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddVideoScreen(courseId: widget.course.id),
            ),
          );
        },
        label: const Text('Add Video'),
        icon: const Icon(Icons.video_call),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildContentTab() {
    // 1. Check for Nested Content (New Structure)
    if (widget.course.contents.isNotEmpty) {
      return _buildNestedContentList(widget.course.contents.cast<Map<String, dynamic>>());
    }

    // 2. Fallback to Legacy Video Collection
    return StreamBuilder<List<VideoModel>>(
      stream: _firestoreService.getVideosForCourse(widget.course.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No videos yet', style: AppTheme.bodyLarge(context)),
                Text('Tap "Add Video" to get started', style: AppTheme.bodyMedium(context)),
              ],
            ),
          );
        }

        final videos = snapshot.data!;
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () {
                   if (video.videoUrl.isNotEmpty) {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => 
                       Scaffold(
                         backgroundColor: Colors.black,
                         appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
                         body: Center(child: CustomVideoPlayer(videoUrl: video.videoUrl, autoPlay: true)),
                       )
                     ));
                   }
                },
                leading: Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                    image: video.thumbnailUrl.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(video.thumbnailUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: video.thumbnailUrl.isEmpty 
                      ? const Center(child: Icon(Icons.play_circle_fill, color: Colors.white))
                      : const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 32)),
                ),
                title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${video.duration} min • ${video.isFree ? "Free" : "Paid"}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _confirmDeleteVideo(video),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNestedContentList(List<Map<String, dynamic>> contents) {
    if (contents.isEmpty) {
       return Center(child: Text('No content available', style: AppTheme.bodyMedium(context)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contents.length,
      itemBuilder: (context, index) {
        final item = contents[index];
        final type = item['type'];
        final name = item['name'] ?? 'Untitled';
        
        IconData icon;
        Color color;
        if (type == 'folder') {
          icon = Icons.folder;
          color = Colors.orange;
        } else if (type == 'video') {
          icon = Icons.play_circle_fill;
          color = Colors.red;
        } else if (type == 'pdf') {
          icon = Icons.picture_as_pdf;
          color = Colors.redAccent;
        } else {
          icon = Icons.insert_drive_file;
          color = Colors.grey;
        }

        return Card(
           margin: const EdgeInsets.only(bottom: 8),
           child: ListTile(
             leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
             title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
             subtitle: type == 'video' ? Text(item['duration'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis) : null,
             trailing: const Icon(Icons.arrow_forward_ios, size: 16),
             onTap: () {
               if (type == 'folder') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FolderDetailScreen(
                    folderName: name, 
                    contentList: (item['contents'] as List?)?.cast<Map<String, dynamic>>() ?? []
                  )));
               } else if (type == 'video') {
                   // Build playlist for the player from all videos in this current list
                   final videoList = contents.where((e) => e['type'] == 'video' && e['path'] != null).toList();
                   final initialIndex = videoList.indexOf(item);
                   if (initialIndex >= 0) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(
                        playlist: videoList, 
                        initialIndex: initialIndex
                      )));
                   }
               } else if (type == 'pdf') {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => PDFViewerScreen(filePath: item['path'])));
               }
             },
           ),
        );
      },
    );
  }

  Widget _buildStudentsTab() {
    return const Center(child: Text('Enrolled Students List (Coming Soon)'));
  }

  Future<void> _confirmDeleteVideo(VideoModel video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Video?'),
        content: Text('Are you sure you want to delete "${video.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Delete from Firestore
        await _firestoreService.deleteVideo(video.id);
        
        // 2. Delete from BunnyCDN (Optional: clean up storage)
        // Note: We need remote path logic here, or just leave it for manual cleanup
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting video: $e')),
          );
        }
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course?'),
        content: const Text('This will delete the course and ALL its videos. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              unawaited(_deleteCourse());
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCourse() async {
    try {
      // 1. Get all videos to delete them locally first (or cloud function ideal)
      // For now, simple delete course doc. 
      // Ideally we should delete related videos collection/docs too.
      
      // 1. Delete all videos (using batch delete method)
      await _firestoreService.deleteCourseVideos(widget.course.id);

      await _firestoreService.deleteCourse(widget.course.id);

      if (mounted) {
        Navigator.pop(context); // Go back to list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting course: $e')),
        );
      }
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _tabBar,
          const Divider(height: 1),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
