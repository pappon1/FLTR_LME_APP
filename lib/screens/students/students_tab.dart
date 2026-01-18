import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/dashboard_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/student_list_item.dart';
import '../../models/student_model.dart';
import 'package:shimmer/shimmer.dart'; // Add this
import 'enrollment/manual_enrollment_screen.dart';

class StudentsTab extends StatefulWidget {
  final bool showOnlyBuyers;

  const StudentsTab({super.key, this.showOnlyBuyers = false});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
       Provider.of<DashboardProvider>(context, listen: false).loadMoreStudents();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTheme.heading2(context),
                decoration: InputDecoration(
                  hintText: 'Search by name, email, phone...',
                  hintStyle: TextStyle(color: Theme.of(context).hintColor),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    }
                  });
                },
              )
            : Text(
                widget.showOnlyBuyers ? 'Course Buyers' : 'App Download (Students)',
                style: AppTheme.heading2(context),
              ),
        actions: [
          IconButton(
            icon: FaIcon(_isSearching ? FontAwesomeIcons.xmark : FontAwesomeIcons.magnifyingGlass, size: 20),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  // Clear search on close
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
            tooltip: _isSearching ? 'Close Search' : 'Search',
          ),
          
          // Manual Enrollment (Only visible in Course Buyers mode)
          if (widget.showOnlyBuyers && !_isSearching)
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.userPlus, size: 20),
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualEnrollmentScreen()));
              },
              tooltip: 'Manual Enroll / Migration',
            ),
            
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<DashboardProvider>(context, listen: false).refreshData();
        },
        child: Consumer<DashboardProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.students.isEmpty) {
               return _buildShimmerList();
            }

            // 1. Initial filtered list (All or Buyers Only)
            List<StudentModel> studentsList = widget.showOnlyBuyers 
                ? provider.students.where((s) => s.enrolledCourses > 0).toList()
                : provider.students;
            
            // 2. Apply Search Filter
            if (_searchQuery.isNotEmpty) {
              studentsList = studentsList.where((s) {
                 final name = s.name.toLowerCase();
                 final email = s.email.toLowerCase();
                 final phone = s.phone.toLowerCase();
                 return name.contains(_searchQuery) || email.contains(_searchQuery) || phone.contains(_searchQuery);
              }).toList();
            }

            if (studentsList.isEmpty) {
              return Stack(
                children: [
                   ListView(), // Scrollable wrapper
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.users,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ? 'No matches found' : 'No students yet',
                          style: AppTheme.heading3(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                           _searchQuery.isNotEmpty ? 'Try a different keyword' : 'Students will appear here once they enroll',
                          style: AppTheme.bodyMedium(context),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
 
            return ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: studentsList.length + (provider.hasMoreStudents ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == studentsList.length) {
                  return Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      height: 80,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
                
                final student = studentsList[index];
                return StudentListItem(student: student)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: (index * 30 <= 500 ? index * 30 : 500).ms) 
                    .slideX(begin: -0.1, end: 0);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

