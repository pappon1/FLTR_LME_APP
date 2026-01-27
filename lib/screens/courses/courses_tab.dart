import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/dashboard_provider.dart';
import '../../utils/app_theme.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../uploads/upload_progress_screen.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/course_card_skeleton.dart';
import '../../widgets/course_card.dart';
import '../../models/course_model.dart';
import 'add_course_screen.dart';

class CoursesTab extends StatefulWidget {
  const CoursesTab({super.key});

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  // Dummy Data for UI Testing
  final List<CourseModel> _dummyCourses = [
    CourseModel(
      id: '101',
      title: 'Advanced Chip Level Repairing',
      category: 'Hardware',
      price: 25000,
      discountPrice: 19999,
      description: 'Master mobile hardware repairing from basics to advanced chip level.',
      thumbnailUrl: 'https://picsum.photos/id/1/800/450',
      duration: '3 Months',
      difficulty: 'Advanced',
      enrolledStudents: 1540,
      rating: 4.8,
      totalVideos: 120,
      isPublished: true,
      hasCertificate: true,
    ),
    CourseModel(
      id: '102',
      title: 'iPhone Schematic Diagrams Masterclass',
      category: 'Schematics',
      price: 8000,
      discountPrice: 4999,
      description: 'Learn to read and understand iPhone schematics layouts like a pro.',
      thumbnailUrl: 'https://picsum.photos/id/2/800/450',
      duration: '45 Days',
      difficulty: 'Intermediate',
      enrolledStudents: 850,
      rating: 4.6,
      totalVideos: 45,
      isPublished: true,
    ),
    CourseModel(
      id: '103',
      title: 'Android Software Flashing & Unlocking',
      category: 'Software',
      price: 12000,
      discountPrice: 6999,
      description: 'Complete guide to software flashing, FRP bypass, and unlocking tools.',
      thumbnailUrl: 'https://picsum.photos/id/3/800/450',
      duration: '2 Months',
      difficulty: 'Intermediate',
      enrolledStudents: 2100,
      rating: 4.7,
      totalVideos: 80,
      isPublished: true,
    ),
    CourseModel(
      id: '104',
      title: 'Basic Electronics Components',
      category: 'Basics',
      price: 5000,
      discountPrice: 999,
      description: 'Understanding resistors, capacitors, and coils.',
      thumbnailUrl: 'https://picsum.photos/id/4/800/450',
      duration: '15 Days',
      difficulty: 'Beginner',
      enrolledStudents: 500,
      rating: 4.2,
      totalVideos: 15,
      isPublished: false, // Draft example
    ),
  ];

  @override
  void initState() {
    super.initState();
    // DON'T invoke service on init - it starts the service!
    // Request status from background service once UI is ready
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //    FlutterBackgroundService().invoke('get_status');
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Courses',
            style: AppTheme.heading2(context),
          ),
        ),
        actions: [
          // Upload Monitor Button - ALWAYS VISIBLE (For UI Access)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadProgressScreen()));
              },
              icon: Icon(Icons.cloud_upload_outlined, color: AppTheme.primaryColor),
              tooltip: 'Upload Manager',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddCourseScreen()),
                );
              },
              icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Add Course'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<DashboardProvider>(context, listen: false).refreshData();
        },
        child: Consumer<DashboardProvider>(
          builder: (context, provider, child) {
            // Use dummy data regardless of provider state
            final displayCourses = _dummyCourses;

            // Optional: Simulate loading if you want, but for dummy data instant is usually better
            // if (provider.isLoading) { return _buildShimmerGrid(); }

            if (displayCourses.isEmpty) {
              return Stack(
                children: [
                   ListView(), // Always scrollable for RefreshIndicator
                   Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.graduationCap,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No courses yet',
                          style: AppTheme.heading3(context).copyWith(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Add Course" above to start',
                          style: AppTheme.bodyMedium(context).copyWith(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
 
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: displayCourses.length,
              itemBuilder: (context, index) {
                final course = displayCourses[index];
                return CourseCard(course: course)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: (index * 100).ms)
                    .slideX(begin: -0.1, end: 0);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4, // Show 4 skeleton items
      itemBuilder: (context, index) {
        return const CourseCardSkeleton(); // Use the custom square skeleton
      },
    );
  }
}
