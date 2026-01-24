import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class CourseCardSkeleton extends StatelessWidget {
  const CourseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Helper for consistency
    Widget shimmerBox({double? width, required double height}) {
       return Shimmer.fromColors(
        baseColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[300]!,
        highlightColor: isDark ? const Color(0xFF3D3D3D) : Colors.grey[100]!,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[300]!,
            borderRadius: BorderRadius.circular(4), // Slight radius for text lines
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // Square matching actual CourseCard
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
          width: 1,
        ),
      ),
      color: isDark ? const Color(0xFF000000) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🖼️ Thumbnail Placeholder
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            child: Container(
              height: 200,
              width: double.infinity,
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
            ),
          ),

          // 📝 Content Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✨ Badges Row Placeholder
                Row(
                  children: [
                    shimmerBox(width: 40, height: 12),
                    const SizedBox(width: 14),
                    shimmerBox(width: 80, height: 12),
                    const SizedBox(width: 14),
                    shimmerBox(width: 70, height: 12),
                  ],
                ),
                
                const SizedBox(height: 6), // Matching CourseCard Spacing

                // 🏷️ Title Placeholder (2 lines)
                shimmerBox(height: 18, width: double.infinity),
                const SizedBox(height: 4),
                shimmerBox(height: 18, width: 200),
                
                const SizedBox(height: 6), // Matching Divider Spacing
                
                // ➖ Divider Placeholder
                shimmerBox(height: 1, width: double.infinity),
                
                const SizedBox(height: 6), // Matching Divider Spacing
                
                // 💰 Pricing & Button Placeholder
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price Group
                    Row(
                      children: [
                        shimmerBox(width: 50, height: 24), // Main Price
                        const SizedBox(width: 12),
                        shimmerBox(width: 40, height: 15), // Strikethrough
                        const SizedBox(width: 12),
                        shimmerBox(width: 50, height: 15), // Discount
                      ],
                    ),
                    
                    // Button Placeholder
                    Shimmer.fromColors(
                      baseColor: const Color(0xFF536DFE).withOpacity(0.5),
                      highlightColor: const Color(0xFF536DFE).withOpacity(0.8),
                      child: Container(
                        width: 80,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF536DFE),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
