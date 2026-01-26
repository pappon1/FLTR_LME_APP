import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../models/course_model.dart';
import '../screens/courses/course_detail_screen.dart';
import '../utils/app_theme.dart';

class PopularCoursesCarousel extends StatefulWidget {
  final List<CourseModel> courses;

  const PopularCoursesCarousel({
    super.key,
    required this.courses,
  });

  @override
  State<PopularCoursesCarousel> createState() => _PopularCoursesCarouselState();
}

class _PopularCoursesCarouselState extends State<PopularCoursesCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  Timer? _pauseTimer;
  bool _isPaused = false;

  // Only take top 3 courses
  List<CourseModel> get _popularCourses {
    // Sort by enrolled students desc, take top 3
    final sorted = List<CourseModel>.from(widget.courses)
      ..sort((a, b) => b.enrolledStudents.compareTo(a.enrolledStudents));
    return sorted.take(3).toList();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _pauseTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _stopAutoScroll(); // Clear existing
    if (_popularCourses.length <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentPage < _popularCourses.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _pauseAutoScroll() {
    if (_isPaused) return; // Already paused
    
    setState(() {
      _isPaused = true;
    });
    _stopAutoScroll();

    // Resume after 30 seconds
    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _isPaused = false;
        });
        _startAutoScroll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = _popularCourses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            children: [
              const FaIcon(FontAwesomeIcons.fire, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Popular Courses',
                  style: AppTheme.heading3(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        
        // Carousel Container
        if (courses.isEmpty)
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(3.0),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(FontAwesomeIcons.graduationCap, size: 40, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(
                  'No courses available yet',
                  style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate a dynamic height based on width to avoid overflow on wide screens
              // Image is 16:9, plus we need space for text (approx 100-120px)
              final imageHeight = constraints.maxWidth * (9/16);
              final dynamicHeight = imageHeight + 100; // 100px for text and padding
              
              return SizedBox(
                height: dynamicHeight, 
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return _buildCourseCard(context, course);
                  },
                ),
              );
            }
          ),

        const SizedBox(height: 12),

        // Dots Indicator
        if (courses.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(courses.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppTheme.primaryColor
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3.0),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildCourseCard(BuildContext context, CourseModel course) {
    // Calculate Discount
    int discountPercent = 0;
    if (course.price > 0 && course.discountPrice > 0 && course.discountPrice < course.price) {
      discountPercent = (((course.price - course.discountPrice) / course.price) * 100).round();
    }

    return GestureDetector(
      onTapDown: (_) => _pauseAutoScroll(), // Touch pauses scroll
      onTap: () {
        // Navigate
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailScreen(course: course),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8), // More spacing
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(3.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail (16:9)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: course.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.error, color: Colors.grey),
                ),
              ),
            ),

            // Content (Padding below image)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.heading3(context).copyWith(fontSize: 18),
                      ),
                    ),
                  
                  const SizedBox(height: 8),

                  // Price Row
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Discounted Price
                        Text(
                          '₹${course.discountPrice > 0 ? course.discountPrice : course.price}',
                          style: GoogleFonts.inter(
                            color: AppTheme.primaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(width: 8),
  
                        // Original Price (Strikethrough)
                        if (discountPercent > 0) ...[
                          Text(
                            '₹${course.price}',
                            style: GoogleFonts.inter(
                              color: Colors.grey,
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          
                          const SizedBox(width: 8),
  
                          // Discount Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3.0),
                            ),
                            child: Text(
                              '$discountPercent% OFF',
                              style: GoogleFonts.inter(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

