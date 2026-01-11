import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/course_model.dart';
import '../utils/app_theme.dart';
import '../services/bunny_cdn_service.dart';
import '../screens/courses/course_detail_screen.dart';

class CourseCard extends StatelessWidget {
  final CourseModel course;

  const CourseCard({
    super.key,
    required this.course,
  });

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logic for Price Display
    final double sellingPrice = course.price.toDouble();
    // Use discountPrice from model as MRP. If 0 or less than selling, assume no discount (same price).
    final double originalPrice = (course.discountPrice > course.price) 
        ? course.discountPrice.toDouble() 
        : sellingPrice;
        
    final int discountPercent = originalPrice > 0 
        ? ((originalPrice - sellingPrice) / originalPrice * 100).round()
        : 0;
    
    // Mock Logic for 'New' Badge (e.g., if created in last 'newBatchDays')
    final bool isNew = DateTime.now().difference(course.createdAt ?? DateTime.now()).inDays < (course.newBatchDays);
    const int demoCount = 2; // Mock data for now

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: InkWell(
        onTap: () {
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
            // 1. Full Size Image (No Cut)
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.black, // Background for 'contain' if ratio differs
              child: CachedNetworkImage(
                imageUrl: course.thumbnailUrl.contains('b-cdn.net') 
                    ? course.thumbnailUrl.replaceFirst('lme-media-storage.b-cdn.net', 'sg.storage.bunnycdn.com/lme-media-storage')
                    : course.thumbnailUrl,
                httpHeaders: course.thumbnailUrl.contains('b-cdn.net') 
                    ? {'AccessKey': BunnyCDNService.apiKey} 
                    : null,
                fit: BoxFit.fill, // User requested "Full Size", fill ensures no empty space.
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey.shade800,
                  highlightColor: Colors.grey.shade700,
                  child: Container(color: Colors.grey.shade800),
                ),
                errorWidget: (context, url, error) {
                   return Container(
                    color: Colors.grey.shade900,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, color: Colors.white24, size: 40),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // 1. Title (Top priority)
                   Text(
                      course.title,
                      style: AppTheme.heading3(context).copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                   const SizedBox(height: 12),

                   // 2. Stats Row: New Badge | Demos | Videos
                   Row(
                     children: [
                       if (isNew) ...[
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           decoration: BoxDecoration(
                             color: Colors.yellow,
                             borderRadius: BorderRadius.circular(20),
                           ),
                           child: const Text(
                             'NEW',
                             style: TextStyle(
                               color: Colors.black,
                               fontWeight: FontWeight.bold,
                               fontSize: 12,
                             ),
                           ),
                         ),
                         const Spacer(),
                       ],
                       
                       // Demos (Moves to Left if Not New)
                       Text(
                         '$demoCount Demo Videos',
                         style: TextStyle(
                           color: Colors.blue.shade600,
                           fontSize: 13,
                           fontWeight: FontWeight.w700,
                         ),
                       ),
                       
                       const Spacer(),
                       
                       // Total Videos (Right)
                       Text(
                         '${course.totalVideos} Videos',
                         style: TextStyle(
                           color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                           fontSize: 13,
                           fontWeight: FontWeight.w600,
                         ),
                       ),
                     ],
                   ),
                   
                   const SizedBox(height: 12),
                   
                   // 3. Category & Type Labels
                   Row(
                     children: [
                       // Category
                       Text(
                         'Category: ',
                         style: TextStyle(
                           color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
                           fontSize: 12,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       Text(
                         course.category,
                         style: TextStyle(
                           color: Theme.of(context).primaryColor,
                           fontSize: 12,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       
                       const Spacer(),
                       
                       // Type
                       Text(
                         'Type: ',
                         style: TextStyle(
                           color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
                           fontSize: 12,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       Text(
                         course.difficulty,
                         style: TextStyle(
                           color: _getDifficultyColor(course.difficulty),
                           fontSize: 12,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ],
                   ),

                   const SizedBox(height: 12),
                   const Divider(height: 1, color: Colors.black12),
                   const SizedBox(height: 12),

                   // 4. Pricing
                   Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Current Price (Selling)
                      Text(
                        '₹${course.price}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                        ),
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Discounted/Cut Price (Red Strikethrough)
                      Text(
                        '₹${originalPrice.toInt()}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      const SizedBox(width: 24), // Fixed gap instead of Spacer
                      
                      // Discount Percentage Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.5))
                        ),
                        child: Text(
                          '$discountPercent% OFF',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const Spacer(),
                      
                      // Buyers Count
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${course.enrolledStudents} Buyers',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
