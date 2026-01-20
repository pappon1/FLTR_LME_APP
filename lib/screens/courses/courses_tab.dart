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
import '../../widgets/course_card.dart';
import 'add_course_screen.dart';

class CoursesTab extends StatefulWidget {
  const CoursesTab({super.key});

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  @override
  void initState() {
    super.initState();
    // Request status from background service once UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
       FlutterBackgroundService().invoke('get_status');
    });
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
          // Upload Monitor Button
          StreamBuilder<Map<String, dynamic>?>(
            stream: FlutterBackgroundService().on('update'),
            builder: (context, snapshot) {
              bool hasActiveUploads = false;
              if (snapshot.hasData && snapshot.data != null) {
                 final List queue = snapshot.data!['queue'] ?? [];
                 // Show badge if any uploads are pending, uploading, OR paused
                 hasActiveUploads = queue.any((t) => 
                    t['status'] == 'uploading' || 
                    t['status'] == 'pending' ||
                    t['paused'] == true
                 );
              }
              
              if (!hasActiveUploads) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  onPressed: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadProgressScreen()));
                  },
                  icon: Badge(
                    label: const Text('!'),
                    child: Icon(Icons.cloud_sync, color: AppTheme.primaryColor),
                  ),
                  tooltip: 'View Uploads',
                ),
              );
            }
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
            if (provider.isLoading) {
              return _buildShimmerGrid();
            }

            if (provider.courses.isEmpty) {
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
              itemCount: provider.courses.length,
              itemBuilder: (context, index) {
                final course = provider.courses[index];
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
    return SimpleShimmerList(itemCount: 4, itemHeight: 120.0);
  }
}
