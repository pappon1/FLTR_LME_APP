import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/dashboard_provider.dart';
import '../../utils/app_theme.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/course_card.dart';
import 'add_course_screen.dart';

class CoursesTab extends StatelessWidget {
  const CoursesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Courses',
          style: AppTheme.heading2(context),
        ),
        actions: [
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
              label: const Text('Add Course'),
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
