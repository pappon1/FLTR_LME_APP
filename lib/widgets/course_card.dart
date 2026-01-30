import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/course_model.dart';
import '../services/bunny_cdn_service.dart';
import '../screens/courses/course_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

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
      margin: EdgeInsets.only(bottom: bottomMargin ?? 20, left: customHorizontalMargin ?? (isEdgeToEdge ? 0 : 16), right: customHorizontalMargin ?? (isEdgeToEdge ? 0 : 16)),
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
                   // ✨ Badges Row (Standard Icons for Clean Look)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // ✨ New
                        if (isNew) ...[
                          const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFFFA000)),
                          const SizedBox(width: 4),
                          Text(
                            'New',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFFA000),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],

                        // 📖 Videos (Standard Book)
                        const Icon(Icons.menu_book, size: 14, color: Color(0xFF536DFE)),
                        const SizedBox(width: 4),
                        Text(
                          '${course.totalVideos} Course Videos',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF536DFE),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // ▶️ Demo (Standard Play Arrow)
                        const Icon(Icons.play_arrow, size: 16, color: Color(0xFF00E676)),
                        const SizedBox(width: 4),
                        Text(
                          'Demo Videos',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF00E676),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // 🎗️ Cert (Standard Medal)
                        const Icon(Icons.workspace_premium, size: 15, color: Color(0xFFFF5252)),
                        const SizedBox(width: 4),
                        Text(
                          'Certificate',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF5252),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 🏷️ Title
                  Text(
                    course.title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: 0.1,
                      height: 1.0, // Reduced from 1.2 to remove extra gap
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // ➖ Divider (Match Grey)
                  Divider(
                    color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                    thickness: 1,
                    height: 1, // Fix: Set height to avoid default 16px padding
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
}

