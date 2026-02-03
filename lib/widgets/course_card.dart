import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/course_model.dart';
import '../services/bunny_cdn_service.dart';
import '../screens/courses/course_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CourseCard extends StatelessWidget {
  final CourseModel course;
  final bool isEdgeToEdge;
  final double? customHorizontalMargin;
  final double? bottomMargin;
  final double? cornerRadius;
  final bool? showBorder;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    this.isEdgeToEdge = false,
    this.customHorizontalMargin,
    this.bottomMargin,
    this.cornerRadius,
    this.showBorder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double sellingPrice = course.price.toDouble();
    final double originalPrice = (course.discountPrice > course.price) 
        ? course.discountPrice.toDouble() 
        : sellingPrice;
        
    final int discountPercent = originalPrice > 0 
        ? ((originalPrice - sellingPrice) / originalPrice * 100).round()
        : 0;
    
    final bool isNew = DateTime.now().difference(course.createdAt ?? DateTime.now()).inDays < (course.newBatchDays);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.only(
        bottom: bottomMargin ?? 20, 
        left: customHorizontalMargin ?? (isEdgeToEdge ? 0 : 16), 
        right: customHorizontalMargin ?? (isEdgeToEdge ? 0 : 16)
      ),
      elevation: 0,  
      clipBehavior: Clip.antiAlias,
      color: isDark ? const Color(0xFF000000) : Colors.white, // Deep Black
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius ?? 0), 
        side: (showBorder ?? !isEdgeToEdge) 
          ? BorderSide(
              color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
              width: 1,
            )
          : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap ?? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseDetailScreen(course: course),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                ),
              child: CachedNetworkImage(
                imageUrl: BunnyCDNService.signUrl(course.thumbnailUrl),
                httpHeaders: BunnyCDNService.signUrl(course.thumbnailUrl).contains('storage.bunnycdn.com') 
                    ? const {'AccessKey': BunnyCDNService.apiKey} 
                    : null,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: Container(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 48),
                ),
              ),
              ),
            ),

            // 📝 Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✨ Badges Row (Warped for better visibility)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // ✨ New
                      if (isNew) ...[
                        _buildBadge(
                          icon: Icons.auto_awesome,
                          label: 'New',
                          color: const Color(0xFFFFA000),
                        ),
                      ],

                      // 🌐 Language
                      _buildBadge(
                        icon: Icons.language,
                        label: course.language,
                        color: const Color(0xFF9C27B0),
                      ),

                      // 🎥 Mode
                      _buildBadge(
                        icon: course.courseMode.toLowerCase().contains('live')
                            ? Icons.sensors
                            : Icons.play_circle_outline,
                        label: course.courseMode,
                        color: const Color(0xFFFF5722),
                      ),

                      // 🎗️ Cert
                      if (course.hasCertificate) ...[
                        _buildBadge(
                          icon: Icons.workspace_premium,
                          label: 'Certificate',
                          color: const Color(0xFFFF5252),
                        ),
                      ],

                      // ▶️ Demo
                      _buildBadge(
                        icon: Icons.play_arrow,
                        label: 'Demo',
                        color: const Color(0xFF00E676),
                      ),

                      // 💻 Web Support
                      if (course.isBigScreenEnabled) ...[
                        _buildBadge(
                          icon: Icons.computer,
                          label: 'PC Support',
                          color: const Color(0xFF03A9F4),
                        ),
                      ],

                      // 💬 WhatsApp Support Group
                      if (course.supportType == 'WhatsApp Group') ...[
                        _buildBadge(
                          icon: FontAwesomeIcons.whatsapp,
                          label: 'WhatsApp Support Group',
                          color: const Color(0xFF25D366),
                        ),
                      ],

                      // 📖 Videos
                      _buildBadge(
                        icon: Icons.menu_book,
                        label: '${course.totalVideos} Videos',
                        color: const Color(0xFF536DFE),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  
                  // 🏷️ Title
                  Text(
                    course.title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: 0.1,
                      height: 1.0, 
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // ➖ Divider (Match Grey)
                  Divider(
                    color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                    thickness: 1,
                    height: 1, 
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // 💰 Pricing & Button
                  Row(
                    children: [
                      // Pricing Info (Auto-Fit)
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              // Bold Price
                              Text(
                                '₹${course.price}',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Red Strikethrough
                              Text(
                                '₹${originalPrice.toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: const Color(0xFFFF5252),
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: const Color(0xFFFF5252),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Neon Green Discount
                              Text(
                                '$discountPercent % Off',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: const Color(0xFF00E676),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 10),
                      
                      // See More Button (Indigo Pill)
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: onTap ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF536DFE),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
                            elevation: 0,
                          ),
                          child: const Text('See More', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10.2, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 11.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
