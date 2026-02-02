import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/dashboard_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/student_list_item.dart';
import '../../models/student_model.dart';
import 'package:shimmer/shimmer.dart'; 
import '../../widgets/shimmer_loading.dart';
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
    // Explicitly refresh data on screen open to show Skeleton Shimmer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).refreshData();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
       Provider.of<DashboardProvider>(context, listen: false).loadMoreStudents(onlyBuyers: widget.showOnlyBuyers);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTheme.bodyLarge(context).copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                cursorColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search name, email, phone',
                  hintStyle: TextStyle(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.7),
                    fontSize: 13.5,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero, // Align closely with existing baseline
                ),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  // Ultra-fast debounce for local filtering (50ms)
                  _debounce = Timer(const Duration(milliseconds: 50), () {
                    if (mounted) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    }
                  });
                },
              )
            : Consumer<DashboardProvider>(
                builder: (context, provider, _) {
                  final list = widget.showOnlyBuyers 
                    ? provider.students.where((s) => s.enrolledCourses > 0).toList() 
                    : provider.students;
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(
                          widget.showOnlyBuyers ? 'Course Buyers' : 'App Download (Students)',
                          style: AppTheme.heading2(context),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            _formatCount(widget.showOnlyBuyers ? provider.stats.totalBuyers : provider.stats.totalStudents),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        actions: [
          // 🔥 Result Count Chip (Visible during search)
          if (_isSearching)
            Consumer<DashboardProvider>(
              builder: (context, provider, _) {
                // Calculate count for current filters (local list during search)
                var list = widget.showOnlyBuyers ? provider.buyers : provider.students;
                if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery;
                    list = list.where((s) => s.name.toLowerCase().contains(q) || s.email.toLowerCase().contains(q) || s.phone.contains(q)).toList();
                }
                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${list.length} results',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ).animate().scale(duration: 200.ms),
                );
              },
            ),

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

            // 1. Filtered list (All or Buyers Only)
            // 🔥 Optimized: Use specialized server-filtered list for buyers
            List<StudentModel> studentsList = widget.showOnlyBuyers ? provider.buyers : provider.students;

            // 2. Apply Search Filter
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery;
              final normalizedQuery = query.replaceAll(' ', '');
              
              studentsList = studentsList.where((s) {
                return s.name.toLowerCase().contains(query) ||
                    s.email.toLowerCase().contains(query) ||
                    s.phone.replaceAll(' ', '').contains(normalizedQuery);
              }).toList();
            }

            if (studentsList.isEmpty) {
              return _buildEmptyState();
            }

            final bool hasMore = widget.showOnlyBuyers ? provider.hasMoreBuyers : provider.hasMoreStudents;
            final bool isLoadingMore = widget.showOnlyBuyers ? provider.isLoadingMoreBuyers : provider.isLoadingMoreStudents;
            final itemCount = studentsList.length + (hasMore && _searchQuery.isEmpty ? 1 : 0);

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return GridView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 500,
                      mainAxisExtent: 170,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: itemCount,
                    itemBuilder: (context, index) => _buildStudentItem(context, index, studentsList, provider, isLoadingMore),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: itemCount,
                  itemBuilder: (context, index) => _buildStudentItem(context, index, studentsList, provider, isLoadingMore),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStudentItem(BuildContext context, int index, List<StudentModel> studentsList, DashboardProvider provider, bool isLoadingMore) {
    if (index == studentsList.length) {
      if (isLoadingMore) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Shimmer.fromColors(
          baseColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          highlightColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          child: Container(
            height: 80,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(3.0),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final student = studentsList[index];
    return StudentListItem(student: student)
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 30 <= 500 ? index * 30 : 500).ms)
        .slideX(begin: -0.1, end: 0);
  }

  Widget _buildEmptyState() {
    return Stack(
      children: [
        ListView(), // Scrollable wrapper for RefreshIndicator
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FaIcon(FontAwesomeIcons.users, size: 64, color: Colors.grey),
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
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShimmerList() {
    return const ShimmerList(
      itemCount: 8,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemBuilder: StudentShimmerItem(),
    );
  }
}


