class DashboardStats {
  final int totalCourses;
  final int totalVideos;
  final int totalStudents;
  final int totalRevenue;
  final int coursesThisWeek;
  final int videosThisWeek;
  final int studentsThisMonth;
  final int revenueGrowth;

  DashboardStats({
    required this.totalCourses,
    required this.totalVideos,
    required this.totalStudents,
    required this.totalRevenue,
    required this.coursesThisWeek,
    required this.videosThisWeek,
    required this.studentsThisMonth,
    required this.revenueGrowth,
  });

  DashboardStats copyWith({
    int? totalCourses,
    int? totalVideos,
    int? totalStudents,
    int? totalRevenue,
    int? coursesThisWeek,
    int? videosThisWeek,
    int? studentsThisMonth,
    int? revenueGrowth,
  }) {
    return DashboardStats(
      totalCourses: totalCourses ?? this.totalCourses,
      totalVideos: totalVideos ?? this.totalVideos,
      totalStudents: totalStudents ?? this.totalStudents,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      coursesThisWeek: coursesThisWeek ?? this.coursesThisWeek,
      videosThisWeek: videosThisWeek ?? this.videosThisWeek,
      studentsThisMonth: studentsThisMonth ?? this.studentsThisMonth,
      revenueGrowth: revenueGrowth ?? this.revenueGrowth,
    );
  }
}
