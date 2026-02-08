import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/course_model.dart';
import '../../services/firestore_service.dart';
import '../../services/bunny_cdn_service.dart';
import '../../utils/app_theme.dart';
import 'tabs/course_content_tab.dart';
import 'edit_course_info_screen.dart';
import '../../data/dummy_course_data.dart'; // Import dummy data file

import '../user_profile/user_profile_screen.dart';
import '../../models/student_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedTabIndex = 0; // 0: Overview, 1: Content, 2: Students
  bool _isDescriptionExpanded = false;

  final TextEditingController _studentSearchController =
      TextEditingController();
  String _studentSearchQuery = '';

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  // Finalized Design Constants
  static const double _fPriceSize = 21.2;
  static const double _fOldPriceSize = 14.9;
  static const double _fDiscSize = 12.7;
  static const double _fElemSpace = 8.3;
  static const double _fBarPaddingV = 5.8;
  static const double _fBtnHeight = 35.7;
  static const double _fBtnTextSize = 9.2;
  static const double _fIconRotate = 0.0;

  // Finalized FAQ & Highlights Constants
  static const double _fFaqQSize = 13.5;
  static const double _fFaqASize = 12.5;
  static const double _fFaqPadding = 8.7;
  static const double _fFaqMarginB = 10.0;
  static const double _fFaqRadius = 3.0;
  static const bool _fShowFaqDivider = true;
  static const double _fFaqDivSpace = 0.0;
  static const double _fHighTextSize = 13.5;
  static const double _fHighSpaceB = 10.0;
  static const double _fHighDotSize = 8.0;

  // Finalized WhatsApp CTA Constants
  static const double _fWaPadding = 5.4;
  static const double _fWaRadius = 3.0;
  static const double _fWaIconPadding = 8.5;
  static const double _fWaIconSize = 25.1;
  static const double _fWaGap = 13.8;
  static const double _fWaTextSize = 11.5;
  static const double _fWaIconShiftX = 0.8;

  // Finalized Header Constants
  static const double _fHTitleSize = 15.9;
  static const double _fHTitleShiftX = -22.8;
  static const double _fHBackShiftX = 0.0;
  static const double _fHActionShiftX = -14.1;
  static const double _fHBackIconSize = 24.0;
  static const double _fHActionIconSize = 20.0;
  static const double _fHHeartIconSize = 19.5;
  static const double _fHHeartTextSize = 10.7;
  static const double _fHBadgeHPadding = 9.9;
  static const double _fHBadgeVPadding = 5.3;
  static const bool _fHShowBadge = true;
  static const bool _fHShowBadgeBg = false;
  static const double _fHBadgeShiftX = 0.0;

  // Finalized Overview Spacing Constants
  static const double _fOvGapThumbTitle = 20.0;
  static const double _fOvGapTitleDesc = 8.7;
  static const double _fOvGapSeeMoreHigh = 11.5;
  static const double _fOvGapHighFaq = 6.9;
  static const double _fOvTitleSize = 18.0;
  static const double _fOvDescSize = 13.5;
  static const double _fOvSeeMoreSize = 10.0;
  static const Color _fOvSeeMoreColor = Color(0xFF7B5CFF);

  // Colors extracted from reference
  final Color _primaryPurple = const Color(0xFF6C5DD3);
  final Color _bgPurpleLight = const Color(0xFFF3E8FF);
  final Color _textDark = const Color(0xFF1F1F39);
  final Color _textGrey = const Color(0xFF858597);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // Strict Dark Mode: Deep Black to match OLED/Reference
    final Color bgColor = isDark ? const Color(0xFF050505) : Colors.white;

    return StreamBuilder<CourseModel>(
      // 🔥 TO UI DESIGN: Switch back to _firestoreService.getCourseStream(widget.course.id) for real data
      stream: DummyCourseData.fetchCourseDetails(),
      initialData: DummyCourseData.sampleCourse,
      builder: (context, snapshot) {
        final course = snapshot.data ?? widget.course;

        return Scaffold(
          backgroundColor: bgColor,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: _buildSliverAppBar(isDark, bgColor, course),
                ),
              ];
            },
            body: _selectedTabIndex == 0
                ? _buildOverviewTab(isDark, course)
                : _selectedTabIndex == 1
                ? _buildContentTab(course)
                : _buildStudentsTab(),
          ),
          bottomNavigationBar: _selectedTabIndex == 0
              ? _buildBottomBar(isDark, course)
              : null,
        );
      },
    );
  }

  SliverAppBar _buildSliverAppBar(
    bool isDark,
    Color bgColor,
    CourseModel course,
  ) {
    return SliverAppBar(
      backgroundColor: bgColor,
      elevation: 0,
      centerTitle: true,
      pinned: true,
      floating: false, // Changed to false to prevent scrolling away completely
      leading: Transform.translate(
        offset: const Offset(_fHBackShiftX, 0),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : _textDark,
            size: _fHBackIconSize,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Transform.translate(
        offset: const Offset(_fHTitleShiftX, 0),
        child: Text(
          'Course Details',
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : _textDark,
            fontSize: _fHTitleSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      actions: [
        Transform.translate(
          offset: const Offset(_fHActionShiftX, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                icon: Icon(
                  Icons.mode_edit_outlined,
                  color: isDark ? Colors.white70 : _textDark,
                  size: _fHActionIconSize,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditCourseInfoScreen(course: course),
                    ),
                  );
                },
              ),
              if (_fHShowBadge)
                Transform.translate(
                  offset: const Offset(_fHBadgeShiftX, 0),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: _fHBadgeHPadding,
                        vertical: _fHBadgeVPadding,
                      ),
                      decoration: BoxDecoration(
                        color: _fHShowBadgeBg
                            ? (isDark
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFFF3E8FF))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Color(0xFFFF3B30),
                            size: _fHHeartIconSize,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '4',
                            style: GoogleFonts.manrope(
                              color: isDark ? Colors.white : _textDark,
                              fontSize: _fHHeartTextSize,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                icon: Icon(
                  Icons.share_outlined,
                  color: isDark ? Colors.white70 : _textDark,
                  size: _fHActionIconSize,
                ),
                onPressed: () {
                  debugPrint('Share button clicked for course: ${course.title}');
                  final String shareText = 'Check out this course: ${course.title}\n\n'
                      '${course.description.length > 200 ? '${course.description.substring(0, 200)}...' : course.description}\n\n'
                      '${course.websiteUrl.isNotEmpty ? "View more: ${course.websiteUrl}" : "Download the app for more details!"}';
                  Share.share(shareText);
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(color: bgColor, child: _buildCustomTabBar(isDark)),
      ),
    );
  }

  Widget _buildCustomTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(3.0),
      ),
      child: Row(
        children: [
          _buildTabItem(0, "Overview", isDark),
          _buildTabItem(1, "Content", isDark),
          _buildTabItem(2, "Students", isDark),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, bool isDark) {
    final bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF6C5DD3), Color(0xFF8E81E8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(3.0),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6C5DD3).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280)),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark, CourseModel course) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: const PageStorageKey('overview'),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 12),
                  // Thumbnail
                  AspectRatio(
                    aspectRatio: 16 / 9, // Standard YouTube Aspect Ratio
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3.0),
                        color: isDark ? Colors.grey[900] : Colors.grey[200],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: BunnyCDNService.signUrl(course.thumbnailUrl),
                        httpHeaders:
                            BunnyCDNService.signUrl(
                              course.thumbnailUrl,
                            ).contains('storage.bunnycdn.com')
                            ? {'AccessKey': BunnyCDNService.apiKey}
                            : null,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            color: _primaryPurple,
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: _fOvGapThumbTitle),

                  // Title
                  Text(
                    course.title.isNotEmpty
                        ? course.title
                        : "Advance Mobile Repairing Trainings",
                    style: GoogleFonts.poppins(
                      fontSize: _fOvTitleSize,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : _textDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: _fOvGapTitleDesc),

                  // Description Section - Prompt: 2 line preview
                  _buildSectionHeader("Description", showEdit: false),
                  const SizedBox(height: 8),
                  Text(
                    course.description.isNotEmpty
                        ? course.description
                        : "Iss advanced course mein aap seekhenge mobile hardware repair, chip-level soldering, IC reballing aur latest techniques...",
                    maxLines: _isDescriptionExpanded ? null : 2,
                    overflow: _isDescriptionExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: _fOvDescSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(
                      () => _isDescriptionExpanded = !_isDescriptionExpanded,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            _isDescriptionExpanded ? 'See less' : 'See more',
                            style: GoogleFonts.poppins(
                              fontSize: _fOvSeeMoreSize,
                              fontWeight: FontWeight.w500,
                              color: _fOvSeeMoreColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isDescriptionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: _fOvSeeMoreColor,
                            size: _fOvSeeMoreSize + 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: _fOvGapSeeMoreHigh),

                  _buildSectionHeader("Course Features & Benefits", showEdit: false),
                  const SizedBox(height: 12),

                  // 🏷️ Course Badges Row
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: () {
                      final List<Map<String, dynamic>> badgeData = [];
                      
                      // 🎥 Videos First
                      badgeData.add({
                        'icon': Icons.video_library,
                        'label': 'Course - ${course.totalVideos} Videos',
                        'color': const Color(0xFF536DFE),
                      });

                      if (course.category.isNotEmpty) {
                        badgeData.add({
                          'icon': Icons.category,
                          'label': 'Category - ${course.category}',
                          'color': course.category.toLowerCase() == 'hardware'
                              ? (isDark ? Colors.white : const Color(0xFF3F51B5))
                              : const Color(0xFF3F51B5),
                        });
                      }
                      if (course.difficulty.isNotEmpty) {
                        badgeData.add({
                          'icon': Icons.signal_cellular_alt,
                          'label': 'Course Type - ${course.difficulty}',
                          'color': course.difficulty.toLowerCase() == 'advanced'
                              ? Colors.amberAccent
                              : const Color(0xFF795548),
                        });
                      }
                      badgeData.add({
                        'icon': Icons.language,
                        'label': 'Course Language - ${course.language}',
                        'color': const Color(0xFF9C27B0),
                      });
                      badgeData.add({
                        'icon': course.courseMode.toLowerCase().contains('live')
                            ? Icons.sensors
                            : Icons.play_circle_outline,
                        'label': 'Course Mode - ${course.courseMode}',
                        'color': const Color(0xFFFF5722),
                      });
                      if (course.hasCertificate) {
                        badgeData.add({
                          'icon': Icons.workspace_premium,
                          'label': 'Course - Certificate',
                          'color': const Color(0xFFFF5252),
                        });
                      }
                      badgeData.add({
                        'icon': Icons.history_toggle_off,
                        'label': 'Course Validity - ${course.duration}',
                        'color': const Color(0xFF00BCD4),
                      });
                      if (course.isOfflineDownloadEnabled) {
                        badgeData.add({
                          'icon': Icons.download_for_offline,
                          'label': 'Course - Offline Access',
                          'color': const Color(0xFF009688),
                        });
                      }
                      if (course.supportType == 'WhatsApp Group') {
                        badgeData.add({
                          'icon': FontAwesomeIcons.whatsapp,
                          'label': 'Student Support - WhatsApp Support Group',
                          'color': const Color(0xFF25D366),
                          'extraPadding': const EdgeInsets.only(left: 5), // Reduced for static layout
                        });
                      }

                      // 📺 Demo Badge
                      badgeData.add({
                        'icon': Icons.play_lesson,
                        'label': 'Course - Demo',
                        'color': const Color(0xFFE91E63),
                        'extraPadding': const EdgeInsets.only(left: 2), // Reduced for static layout
                      });

                      // 💻 Web Access Badge
                      badgeData.add({
                        'icon': Icons.devices,
                        'label': 'Course Access - Web/PC Access',
                        'color': const Color(0xFF03A9F4),
                        'extraPadding': const EdgeInsets.only(left: 2),
                      });

                      return badgeData.map((data) {
                        return _buildBadge(
                          icon: data['icon'] as IconData,
                          label: data['label'] as String,
                          color: data['color'] as Color,
                          extraPadding: data['extraPadding'] as EdgeInsets? ?? EdgeInsets.zero,
                        );
                      }).toList();
                    }(),
                  ),

                  const SizedBox(height: 24),

                  // 🔗 WhatsApp Support Group Link Section
                  _buildSectionHeader("WhatsApp Support Group Link", showEdit: false),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C254D), // Deep Purple
                      borderRadius: BorderRadius.circular(100), // Capsule Shape
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.whatsapp,
                          color: Color(0xFF25D366),
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "https://chat.whatsapp.com/invite/LMESirSupportGroup",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(
                        duration: 2000.ms,
                        color: Colors.white.withOpacity(0.1),
                        angle: 45,
                      )
                      .then(delay: 1000.ms),

                  const SizedBox(height: 24),

                  // 📜 Download Certificate Section
                  _buildSectionHeader("Download Certificate", showEdit: false),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      // Logic for downloading certificate
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5DD3), Color(0xFF8E81E8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(100), // Capsule Shape
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C5DD3).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Download",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(
                          duration: 1500.ms,
                          color: Colors.white.withOpacity(0.2),
                          angle: 45,
                        )
                        .then(delay: 1000.ms),
                  ),

                  const SizedBox(height: 24),

                  // 💻 Website (PC Access) Section
                  _buildSectionHeader("Website (PC Access)", showEdit: false),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C254D), // Deep Purple
                      borderRadius: BorderRadius.circular(100), // Capsule Shape
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.laptop_mac_rounded,
                          color: Color(0xFF03A9F4),
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            course.websiteUrl.isNotEmpty 
                                ? course.websiteUrl 
                                : "https://www.lmestudy.com/login",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.open_in_new_rounded,
                          color: Colors.white.withOpacity(0.4),
                          size: 16,
                        ),
                      ],
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(
                        duration: 2000.ms,
                        color: Colors.white.withOpacity(0.1),
                        angle: 45,
                      )
                      .then(delay: 1500.ms),

                  const SizedBox(height: 24),

                  // Highlights Section
                  if (course.highlights.isNotEmpty) ...[
                    _buildSectionHeader("Course Highlights", showEdit: false),
                    const SizedBox(height: 16),
                    ...course.highlights.asMap().entries.map((entry) {
                      return _buildHighlightItem(
                        entry.value,
                        isDark,
                        isFirst: entry.key == 0,
                        isLast: entry.key == course.highlights.length - 1,
                      );
                    }),
                    const SizedBox(height: _fOvGapHighFaq),
                  ],

                  // FAQs
                  if (course.faqs.isNotEmpty) ...[
                    _buildSectionHeader("FAQs", showEdit: false),
                    const SizedBox(height: 16),
                    ...course.faqs.map(
                      (faq) => _buildFAQItem(
                        faq['question'] ?? '',
                        faq['answer'] ?? '',
                        isDark,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Chat Banner - One Line Fix
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: _fWaPadding),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C254D), // Deep Reference Purple
                      borderRadius: BorderRadius.circular(100), // Capsule Shape
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(_fWaIconShiftX, 0),
                          child: Container(
                            padding: const EdgeInsets.all(_fWaIconPadding),
                            decoration: const BoxDecoration(
                              color: Color(0xFF25D366),
                              shape: BoxShape.circle,
                            ),
                            child: const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              color: Colors.white,
                              size: _fWaIconSize,
                            ),
                          ),
                        ),
                        const SizedBox(width: _fWaGap),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Chat With LME Sir For More Course Details.',
                              style: GoogleFonts.poppins(
                                fontSize: _fWaTextSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(
                        duration: 2000.ms,
                        color: Colors.white.withOpacity(0.15),
                        angle: 45,
                      )
                      .then(delay: 500.ms), // Short pause between shines
                  const SizedBox(height: 30),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHighlightItem(
    String text,
    bool isDark, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Column: Dot + Precise Line Handling
          SizedBox(
            width: 32, // More width for proper dot centering
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Top Connector
                if (!isFirst)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1.5,
                      height: double.infinity,
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 1.5,
                        height: 12, // Gap to dot center
                        color: isDark
                            ? const Color(0xFF333344)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                // Bottom Connector
                if (!isLast)
                  Positioned(
                    top: 10, // From dot center
                    bottom: 0,
                    child: Container(
                      width: 1.5,
                      color: isDark
                          ? const Color(0xFF333344)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                // The Dot
                Positioned(
                  top: 10, // Center with first line of text
                  child: Container(
                    width: _fHighDotSize,
                    height: _fHighDotSize,
                    decoration: BoxDecoration(
                      color: _primaryPurple,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primaryPurple.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Highlight Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: _fHighSpaceB,
                top: 2,
              ), // Perfectly aligned with dot
              child: Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: _fHighTextSize,
                  color: Colors.white,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: _fFaqMarginB),
      padding: const EdgeInsets.all(_fFaqPadding),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111111)
            : Colors.white, // Very Dark Card
        borderRadius: BorderRadius.circular(_fFaqRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Q. ',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: _fFaqQSize + 1.5,
                ),
              ),
              Expanded(
                child: Text(
                  question,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: _fFaqQSize,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (answer.isNotEmpty) ...[
            if (_fShowFaqDivider) ...[
              const SizedBox(height: _fFaqDivSpace),
              Divider(
                color: isDark ? Colors.white10 : Colors.black12,
                thickness: 1,
              ),
            ],
            const SizedBox(height: _fFaqDivSpace),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A. ',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: _fFaqASize + 1.5,
                  ),
                ),
                Expanded(
                  child: Text(
                    answer,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      fontSize: _fFaqASize,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool showEdit = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.yellow,
            letterSpacing: 0.1,
          ),
        ),
        if (showEdit)
          Icon(Icons.mode_edit_outline_outlined, size: 18, color: _textGrey),
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
    EdgeInsets extraPadding = EdgeInsets.zero,
  }) {
    final parts = label.split(' - ');
    final String prefix = parts[0];
    final String value = parts.length > 1 ? parts[1] : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2).add(extraPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, 1), // Nudge icon down for perfect alignment
            child: Icon(icon, size: 18.0, color: Colors.white),
          ),
          const SizedBox(width: 6),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 13.2,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: '$prefix${value.isNotEmpty ? ' - ' : ''}',
                  style: const TextStyle(color: Colors.white),
                ),
                if (value.isNotEmpty)
                  TextSpan(
                    text: value,
                    style: const TextStyle(color: Color(0xFF2DC572)), // Vibrant Green
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark, CourseModel course) {
    // Correct Pricing Logic: price = MRP, discountPrice = Selling Price
    final double sellingPrice = course.discountPrice.toDouble();
    final double originalPrice = course.price.toDouble();

    final int discountPercent =
        (originalPrice > sellingPrice && originalPrice > 0)
        ? ((originalPrice - sellingPrice) / originalPrice * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: _fBarPaddingV,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0C1D), // Deep Dark Navy/Purple for focus
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.50),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Price Section
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹${sellingPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.manrope(
                        fontSize: _fPriceSize,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (discountPercent > 0) ...[
                      const SizedBox(width: _fElemSpace),
                      Text(
                        '₹${originalPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.manrope(
                          fontSize: _fOldPriceSize,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: const Color(0xFFF05151),
                          color: const Color(0xFFF05151),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: _fElemSpace),
                      Text(
                        '$discountPercent% OFF',
                        style: GoogleFonts.manrope(
                          fontSize: _fDiscSize,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2DC572),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // BUY NOW Pill Button
            InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(3.0),
            child: Container(
                height: _fBtnHeight,
                padding: const EdgeInsets.symmetric(horizontal: 18), // Restored original padding
                decoration: BoxDecoration(
                  color: Colors.yellow, // Solid Yellow
                  borderRadius: BorderRadius.circular(100), // Capsule Shape
                  boxShadow: [
                    BoxShadow(
                      color: Colors.yellow.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'BUY NOW',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w900, // Extra Bold
                      fontSize: _fBtnTextSize + 6, // Significantly larger text
                      color: Colors.black,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .shake(
                  delay: 1000.ms,
                  duration: 1000.ms,
                  hz: 4,
                  offset: const Offset(2, 0),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTab(CourseModel course) {
    return CourseContentTab(
      course: course,
      firestoreService: _firestoreService,
    );
  }

  Widget _buildStudentsTab() {
    return Builder(
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;

        // Dummy data for students
        final List<Map<String, String?>> allStudents = [
          {
            'name': 'Rahul Sharma',
            'email': 'rahul.sharma@example.com',
            'phone': '+91 98765 43210',
            'image': 'https://i.pravatar.cc/150?u=rahul',
          },
          {
            'name': 'Amit Verma',
            'email': 'amit.verma@example.com',
            'phone': '+91 98765 00000',
            'image': null,
          },
        ];

        // Filter Logic
        final filteredStudents = allStudents.where((student) {
          final query = _studentSearchQuery.toLowerCase().trim();
          if (query.isEmpty) return true;

          final name = (student['name'] ?? '').toLowerCase();
          final email = (student['email'] ?? '').toLowerCase();
          final phone = (student['phone'] ?? '').toLowerCase();

          return name.contains(query) ||
              email.contains(query) ||
              phone.contains(query);
        }).toList();

        return CustomScrollView(
          key: const PageStorageKey('students'),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: TextField(
                  controller: _studentSearchController,
                  style: GoogleFonts.manrope(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _studentSearchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by Name, Email or Phone...',
                    hintStyle: GoogleFonts.manrope(
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3.0),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3.0),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3.0),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (filteredStudents.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    "No students found",
                    style: GoogleFonts.manrope(color: Colors.grey),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final student = filteredStudents[index];
                    final hasImage =
                        student['image'] != null &&
                        student['image']!.isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(3.0),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.withValues(alpha: 0.15),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(3.0),
                          onTap: () {
                            final dummyStudent = StudentModel(
                              id: 'dummy_id_$index',
                              name: student['name'] ?? 'Unknown',
                              email: student['email'] ?? '',
                              phone: student['phone'] ?? '',
                              enrolledCourses: 1,
                              joinedDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              isActive: true,
                              avatarUrl: student['image'] ?? '',
                            );
                            unawaited(
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UserProfileScreen(student: dummyStudent),
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Profile Placeholder
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    image: hasImage
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              student['image']!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: !hasImage
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.grey,
                                          size: 24,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student['name']!,
                                        style: GoogleFonts.manrope(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1F1F39),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.email_outlined,
                                            size: 12,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            student['email']!,
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone_outlined,
                                            size: 12,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            student['phone']!,
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: filteredStudents.length),
                ),
              ),
          ],
        );
      },
    );
  }
}
