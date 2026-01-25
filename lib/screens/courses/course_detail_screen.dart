import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/course_model.dart';
import '../../models/video_model.dart';
import '../../services/firestore_service.dart';
import '../../services/bunny_cdn_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_video_player.dart';
import 'add_video_screen.dart';
import '../content_viewers/video_player_screen.dart';
import '../content_viewers/pdf_viewer_screen.dart';
import '../content_viewers/pdf_viewer_screen.dart';
import 'folder_detail_screen.dart';
import 'tabs/course_content_tab.dart'; // New Clean Import

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedTabIndex = 0; // 0: Overview, 1: Content, 2: Students
  bool _isDescriptionExpanded = false;

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
  static const double _fFaqRadius = 9.1;
  static const bool _fShowFaqDivider = true;
  static const double _fFaqDivSpace = 0.0;
  static const double _fHighTextSize = 13.5;
  static const double _fHighSpaceB = 10.0;
  static const double _fHighDotSize = 8.0;

  // Finalized WhatsApp CTA Constants
  static const double _fWaPadding = 5.4;
  static const double _fWaRadius = 34.9;
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
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(isDark, bgColor),
      body: Column(
        children: [
          _buildCustomTabBar(isDark),
          Expanded(
            child: _selectedTabIndex == 0 
                ? _buildOverviewTab(isDark)
                : _selectedTabIndex == 1 
                    ? _buildContentTab()
                    : _buildStudentsTab(),
          ),
          if (_selectedTabIndex == 0) _buildBottomBar(isDark),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isDark, Color bgColor) {
    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      centerTitle: true,
      leading: Transform.translate(
        offset: const Offset(_fHBackShiftX, 0),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : _textDark, size: _fHBackIconSize),
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
                icon: Icon(Icons.mode_edit_outlined, color: isDark ? Colors.white70 : _textDark, size: _fHActionIconSize),
                onPressed: () {},
              ),
              // Heart Badge - Precise Mirror of Reference
              if (_fHShowBadge)
                Transform.translate(
                  offset: const Offset(_fHBadgeShiftX, 0),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(horizontal: _fHBadgeHPadding, vertical: _fHBadgeVPadding),
                      decoration: BoxDecoration(
                        color: _fHShowBadgeBg 
                            ? (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF3E8FF))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, color: const Color(0xFFFF3B30), size: _fHHeartIconSize),
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
                icon: Icon(Icons.share_outlined, color: isDark ? Colors.white70 : _textDark, size: _fHActionIconSize),
                onPressed: () {},
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF3F4F6), 
        borderRadius: BorderRadius.circular(30),
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
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF6C5DD3).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: isSelected ? Colors.white : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Thumbnail
          AspectRatio(
            aspectRatio: 16 / 9, // Standard YouTube Aspect Ratio
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDark ? Colors.grey[900] : Colors.grey[200],
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: BunnyCDNService.signUrl(widget.course.thumbnailUrl),
                httpHeaders: BunnyCDNService.signUrl(widget.course.thumbnailUrl).contains('storage.bunnycdn.com') 
                    ? {'AccessKey': BunnyCDNService.apiKey} 
                    : null,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator(color: _primaryPurple)),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50),
              ),
            ),
          ),
          const SizedBox(height: _fOvGapThumbTitle),

          // Title
          Text(
            widget.course.title.isNotEmpty ? widget.course.title : "Advance Mobile Repairing Trainings",
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
            widget.course.description.isNotEmpty 
                ? widget.course.description 
                : "Iss advanced course mein aap seekhenge mobile hardware repair, chip-level soldering, IC reballing aur latest techniques...",
            maxLines: _isDescriptionExpanded ? null : 2, 
            overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: _fOvDescSize,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
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
                    _isDescriptionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: _fOvSeeMoreColor,
                    size: _fOvSeeMoreSize + 3,
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: _fOvGapSeeMoreHigh),

          // Highlights Section
          if (widget.course.highlights.isNotEmpty) ...[
            _buildSectionHeader("Course Highlights", showEdit: false),
            const SizedBox(height: 16),
            ...widget.course.highlights.asMap().entries.map((entry) {
              return _buildHighlightItem(
                entry.value, 
                isDark, 
                isFirst: entry.key == 0,
                isLast: entry.key == widget.course.highlights.length - 1
              );
            }),
            const SizedBox(height: _fOvGapHighFaq),
          ],

          // FAQs
          if (widget.course.faqs.isNotEmpty) ...[
            _buildSectionHeader("FAQs", showEdit: false),
            const SizedBox(height: 16),
            ...widget.course.faqs.map((faq) => _buildFAQItem(
              faq['question'] ?? '', 
              faq['answer'] ?? '', 
              isDark
            )),
          ],
          
          const SizedBox(height: 24),
          
          // Chat Banner - One Line Fix
          // Chat Banner - One Line Fix
            Container(
            padding: const EdgeInsets.all(_fWaPadding),
            decoration: BoxDecoration(
              color: const Color(0xFF2C254D), // Deep Reference Purple
              borderRadius: BorderRadius.circular(_fWaRadius),
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
                    child: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: _fWaIconSize),
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
          ),
          
          
          const SizedBox(height: 40),

          const SizedBox(height: 40), 
        ],
      ),
    );
  }

  Widget _buildHighlightItem(String text, bool isDark, {bool isFirst = false, bool isLast = false}) {
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
                         color: isDark ? const Color(0xFF333344) : const Color(0xFFE5E7EB),
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
                      color: isDark ? const Color(0xFF333344) : const Color(0xFFE5E7EB),
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
                      boxShadow: [BoxShadow(color: _primaryPurple.withOpacity(0.5), blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Highlight Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: _fHighSpaceB, top: 2), // Perfectly aligned with dot
              child: Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: _fHighTextSize,
                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
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
        color: isDark ? const Color(0xFF111111) : Colors.white, // Very Dark Card
        borderRadius: BorderRadius.circular(_fFaqRadius),
        border: Border.all(
           color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.15), 
           width: 1
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
                  color: _primaryPurple,
                  fontSize: _fFaqQSize + 1.5,
                ),
              ),
              Expanded(
                child: Text(
                  question,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : _textDark,
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
                Divider(color: isDark ? Colors.white10 : Colors.black12, thickness: 1),
             ],
             const SizedBox(height: _fFaqDivSpace),
             Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A. ',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: _primaryPurple.withOpacity(0.5),
                    fontSize: _fFaqASize + 1.5,
                  ),
                ),
                Expanded(
                  child: Text(
                    answer,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
            color: const Color(0xFF818CF8), // Reference Indigo
            letterSpacing: 0.1,
          ),
        ),
        if (showEdit)
          Icon(Icons.mode_edit_outline_outlined, size: 18, color: _textGrey),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final double sellingPrice = widget.course.price.toDouble();
    final double originalPrice = (widget.course.discountPrice > widget.course.price) 
        ? widget.course.discountPrice.toDouble() 
        : sellingPrice * 7; 
    final int discountPercent = originalPrice > 0 
        ? ((originalPrice - sellingPrice) / originalPrice * 100).round()
        : 85; 

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: _fBarPaddingV),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!)),
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
                ),
              ),
            ),
            
            const SizedBox(width: 8),

            // BUY NOW Pill Button
            InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(30),
              child: Container(
                height: _fBtnHeight,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5DD3), Color(0xFF8E81E8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C5DD3).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: _fIconRotate,
                      child: const Icon(
                        Icons.local_offer_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BUY NOW',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: _fBtnTextSize,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CONTENT SECTION (Videos/PDFs) ---
  Widget _buildContentTab() {
    return CourseContentTab(
      course: widget.course,
      firestoreService: _firestoreService,
    );
  }
  
  Widget _buildStudentsTab() {
    return Center(child: Text("Coming Soon", style: GoogleFonts.manrope(color: Colors.grey)));
  }
}
