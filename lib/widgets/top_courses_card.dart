import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/course_model.dart';
import '../utils/app_theme.dart';

class TopCoursesCard extends StatelessWidget {
  final List<CourseModel> courses;

  const TopCoursesCard({
    super.key,
    required this.courses,
  });

  @override
  Widget build(BuildContext context) {
    final topCourses = courses.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.trophy,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Top Courses',
                      style: AppTheme.heading3(context),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topCourses.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final course = topCourses[index];
                return Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: index == 0
                            ? AppTheme.warningGradient
                            : index == 1
                                ? LinearGradient(
                                    colors: [Colors.grey.shade400, Colors.grey.shade300],
                                  )
                                : LinearGradient(
                                    colors: [Colors.brown.shade400, Colors.brown.shade300],
                                  ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Course Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: course.thumbnailUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Course Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.title,
                            style: AppTheme.bodyMedium(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.users,
                                size: 10,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${course.enrolledStudents} students',
                                style: AppTheme.bodySmall(context),
                              ),
                              const SizedBox(width: 12),
                              const FaIcon(
                                FontAwesomeIcons.star,
                                size: 10,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                course.rating.toString(),
                                style: AppTheme.bodySmall(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Revenue
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${(course.price * course.enrolledStudents / 1000).toStringAsFixed(0)}k',
                          style: AppTheme.bodyMedium(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGradient.colors.first,
                          ),
                        ),
                        Text(
                          'revenue',
                          style: AppTheme.bodySmall(context),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
