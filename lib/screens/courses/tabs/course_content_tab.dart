import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/course_model.dart';
import '../../../models/video_model.dart';
import '../../../services/firestore_service.dart';
import '../../../services/bunny_cdn_service.dart';
import '../course_detail_screen.dart'; // For callbacks if needed, but preferably standalone
import '../folder_detail_screen.dart';
import '../../content_viewers/video_player_screen.dart';
import '../../content_viewers/pdf_viewer_screen.dart';
import '../../../widgets/custom_video_player.dart';

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
  
  // Color Constants
  final Color _bgPurpleLight = const Color(0xFFF3E8FF);
  final Color _primaryPurple = const Color(0xFF6C5DD3);

  // Design Constants
  static const double cardRadius = 3.0;
  static const double thumbRadius = 3.0;
  static const double thumbWidth = 110.0;
  static const double itemGap = 6.0;
  static const double cardPadding = 4.0;
  static const bool isThumbLeft = true;
  static const double tabsToContentGap = 3.0; 
  static const double headerToCardsGap = 10.0;
  static const bool showThumbnails = true; 

  // Image Settings
  static const bool hideImageIcon = true;
  static const bool showImagePreview = true;
  static const bool hideImageContainer = false;
  static const double imgWidth = 74.0;
  static const double imgHeight = 74.0;
  static const double imgXOffset = 0.0;
  static const double imgRadius = 3.0;

  final double cardBgValue = 18.0; 
  final double cardBgOpacity = 0.67;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CourseModel>(
      stream: widget.firestoreService.getCourseStream(widget.course.id),
      initialData: widget.course,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading content',
              style: GoogleFonts.manrope(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
           return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
           return Center(child: Text('Course not found', style: GoogleFonts.manrope(color: Colors.grey)));
        }

        final course = snapshot.data!;
        
        final contents = course.contents.map((e) {
           if (e is Map) return Map<String, dynamic>.from(e);
           return <String, dynamic>{};
        }).toList();

        if (contents.isEmpty) {
           return StreamBuilder<List<VideoModel>>(
             stream: widget.firestoreService.getVideosForCourse(widget.course.id),
             builder: (context, videoSnapshot) {
               if (videoSnapshot.connectionState == ConnectionState.waiting) {
                 return const Center(child: CircularProgressIndicator());
               }
               
               if (!videoSnapshot.hasData || videoSnapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 48, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No content added yet', 
                          style: GoogleFonts.manrope(color: Colors.grey)
                        ),
                      ],
                    ),
                  );
               }

               final videoItems = videoSnapshot.data!.map((v) => {
                 'type': 'video',
                 'title': v.title,
                 'thumbnail': v.thumbnailUrl,
                 'duration': v.duration,
                 'url': v.videoUrl,
                 'videoUrl': v.videoUrl,
               }).toList();

               return _buildContentList(videoItems);
             },
           );
        }

        return _buildContentList(contents);
      },
    );
  }



  Widget _buildContentList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: tabsToContentGap, bottom: 80), 
      itemCount: items.length + 1, // Header (0) + Items (1..N)
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.only(bottom: headerToCardsGap), // LINKED: headerToCardsGap
            child: Row(
              children: [
                const Icon(Icons.library_books_rounded, color: Color(0xFFFFA000), size: 18),
                const SizedBox(width: 8),
                Text(
                  "Course Content",
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${items.length} Items",
                    style: GoogleFonts.manrope(color: Colors.grey, fontSize: 12),
                  ),
                )
              ],
            ),
          );
        }
        

        final item = items[index - 1];
        
        // Use Video Row for ALL videos
        if (item['type'] == 'video') {
           return _buildVideoRow(item);
        }

        return _buildContentItem(item);
      },
    );
  }
  
  // Reusable Item Row (Folders, PDFs, Basic Videos)
  Widget _buildContentItem(Map<String, dynamic> item) {
    IconData icon = Icons.insert_drive_file;
    Color iconColor = Colors.grey;
    Color iconBg = Colors.grey.withOpacity(0.1);
    
    final type = item['type'].toString().toLowerCase();
    final bool isFolder = type == 'folder';
    
    if (isFolder) {
      icon = Icons.folder_rounded;
      iconColor = const Color(0xFFFFA000); // Amber Folder
      iconBg = const Color(0xFFFFA000).withOpacity(0.1);
    } else if (type == 'video') {
      icon = Icons.play_circle_fill;
      iconColor = const Color(0xFF7B5CFF); // Purple
      iconBg = const Color(0xFF7B5CFF).withOpacity(0.1);
    } else if (type == 'pdf') {
      icon = Icons.picture_as_pdf;
      iconColor = const Color(0xFFFF5252); // Red PDF
      iconBg = const Color(0xFFFF5252).withOpacity(0.1);
    } else if (type == 'image') {
      icon = Icons.image;
      iconColor = const Color(0xFF2196F3); // Blue Image
      iconBg = const Color(0xFF2196F3).withOpacity(0.1);
    } else if (type == 'zip') {
      icon = Icons.folder_zip;
      iconColor = const Color(0xFFFF9800); // Orange Zip
      iconBg = const Color(0xFFFF9800).withOpacity(0.1);
    }

    String title = item['title'] ?? item['name'] ?? 'Untitled';

    // Default File/Folder Row
    return Container(
      margin: EdgeInsets.only(bottom: itemGap),
      decoration: BoxDecoration(
        color: Color.fromRGBO(cardBgValue.toInt(), cardBgValue.toInt(), cardBgValue.toInt(), cardBgOpacity), 
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _handleContentItemTap(item),
        borderRadius: BorderRadius.circular(cardRadius),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Row(
            children: [
              // Image/Icon Section - Always show container for images to act as placeholder
              if (type != 'image' || !hideImageContainer)
              Transform.translate(
                offset: Offset(type == 'image' ? imgXOffset : 0, 0),
                child: Container(
                  width: type == 'image' ? imgWidth : 48, 
                  height: type == 'image' ? imgHeight : 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(type == 'image' ? imgRadius : 12),
                  ),
                  child: type == 'image' 
                    ? (showImagePreview && item['path'] != null)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(imgRadius),
                          child: CachedNetworkImage(
                            imageUrl: _getAuthenticatedUrl(item['path']),
                            httpHeaders: _getAuthenticatedUrl(item['path']).contains('storage.bunnycdn.com') 
                              ? {'AccessKey': BunnyCDNService.apiKey}
                              : null,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) {
                              debugPrint("❌ Image Load Error: $error | URL: $url");
                              return hideImageIcon ? const SizedBox.shrink() : Icon(icon, color: iconColor, size: 24);
                            },
                          ),
                        )
                      : (hideImageIcon ? const SizedBox.shrink() : Icon(icon, color: iconColor, size: 24))
                    : Icon(icon, color: iconColor, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : (item['name'] ?? 'Untitled'),
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600, 
                        fontSize: 14, 
                        color: Colors.white,
                        height: 1.3
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFolder ? "FOLDER" : type.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        color: const Color(0xFF9ca3af),
                        letterSpacing: 0.5
                      ),
                    ),
                  ],
                ),
              ),
              if (isFolder)
                const Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 20)
              else
                Icon(Icons.download_rounded, color: const Color(0xFF7B5CFF).withOpacity(0.8), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoRow(Map<String, dynamic> item) {
    return _buildMediaRow(item, Icons.play_arrow_rounded, const Color(0xFF7B5CFF), isVideo: true);
  }

  // Unified Media Row for Videos and Images
  Widget _buildMediaRow(Map<String, dynamic> item, IconData overlayIcon, Color accentColor, {bool isVideo = false}) {
    String title = item['title'] ?? item['name'] ?? 'Untitled Item';
    String? duration = item['duration'];
    String? thumbUrl = isVideo ? item['thumbnail'] : item['path'];
    
    final height = thumbWidth / 1.77;

    final thumbWidget = Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(thumbRadius),
          child: (showThumbnails && thumbUrl != null && thumbUrl.isNotEmpty && !thumbUrl.contains('mediadelivery.net')) 
            ? CachedNetworkImage(
                imageUrl: _getAuthenticatedUrl(thumbUrl),
                httpHeaders: _getAuthenticatedUrl(thumbUrl).contains('storage.bunnycdn.com')
                  ? {'AccessKey': BunnyCDNService.apiKey}
                  : null,
                width: thumbWidth, height: height, fit: BoxFit.cover,
                placeholder: (_,__) => Container(color: Colors.grey[900], width: thumbWidth, height: height),
                errorWidget: (_,__,___) => _buildPlaceholderThumb(height, overlayIcon),
              ) 
            : _buildPlaceholderThumb(height, overlayIcon),
        ),
        // Overlay Icon
        Container(
          width: thumbWidth, height: height,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(thumbRadius),
          ),
          child: Center(
            child: Icon(overlayIcon, color: Colors.white, size: 28),
          ),
        ),
        // Duration Badge (Videos Only)
        if (isVideo && duration != null)
          Positioned(
            bottom: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                 duration,
                 style: GoogleFonts.manrope(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          )
      ],
    );

    return Container(
      margin: EdgeInsets.only(bottom: itemGap),
      decoration: BoxDecoration(
        color: Color.fromRGBO(cardBgValue.toInt(), cardBgValue.toInt(), cardBgValue.toInt(), cardBgOpacity), 
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _handleContentItemTap(item),
        borderRadius: BorderRadius.circular(cardRadius),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Row(
            children: [
              thumbWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, height: 1.2
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isVideo ? "DURATION • ${duration ?? '05:00'}" : "IMAGE FILE",
                      style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF9ca3af), letterSpacing: 0.5
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderThumb(double height, IconData icon) {
    return Container(
      width: thumbWidth, height: height,
      color: Colors.black,
      child: Icon(icon, color: Colors.white.withOpacity(0.2), size: 24),
    );
  }

  void _handleContentItemTap(Map<String, dynamic> item) {
    if (item['type'] == 'folder') {
       Navigator.push(context, MaterialPageRoute(
         builder: (_) => FolderDetailScreen(
           folderName: item['title'] ?? item['name'] ?? 'Folder',
            contentList: (item['contents'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
         )
       ));
    } else if (item['type'] == 'video') {
       String? url = item['videoUrl'] ?? item['url'];
       
       // Fallback logic for 'path'
       if (url == null || url.isEmpty) {
          String? path = item['path'];
          if (path != null && path.isNotEmpty) {
             if (path.startsWith('http')) {
                url = path;
             } else if (path.contains('lme-media-storage')) {
                // Sign relative Bunny Storage Path
                url = BunnyCDNService.signUrl(path); 
             } else {
                // Assume local file path
                url = path;
             }
          }
       }

       if (url != null && url.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => 
             Scaffold(
               backgroundColor: Colors.black,
               appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
               body: Center(child: CustomVideoPlayer(videoUrl: url!, autoPlay: true)),
             )
          ));
       } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video URL not found")));
       }
    } else if (item['type'] == 'pdf') {
       String? url = item['url'] ?? item['path'];
       if (url != null && url.isNotEmpty) {
         Navigator.push(context, MaterialPageRoute(builder: (_) => PDFViewerScreen(filePath: url, title: item['title'] ?? item['name'] ?? 'PDF')));
       }
    }
  }

  String _getAuthenticatedUrl(String? url) {
    if (url == null || url.isEmpty) return "";
    
    // Ignore playback URLs for image loading
    if (url.contains('mediadelivery.net') || url.contains('iframe.mediadelivery.net')) {
      return ""; 
    }

    return BunnyCDNService.signUrl(url);
  }
}
