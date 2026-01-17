import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dashboard_stats.dart';
import '../models/course_model.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';

class DashboardProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();
  
  DashboardStats _stats = DashboardStats(
    totalCourses: 0,
    totalVideos: 0,
    totalStudents: 0,
    totalRevenue: 0,
    coursesThisWeek: 0,
    videosThisWeek: 0,
    studentsThisMonth: 0,
    revenueGrowth: 0,
  );

  final List<CourseModel> _courses = [];
  final List<StudentModel> _students = [];
  
  StreamSubscription? _coursesSubscription;
  StreamSubscription? _studentsSubscription;

  // Getters
  int get selectedIndex => _selectedIndex;
  bool get isLoading => _isLoading;
  DashboardStats get stats => _stats;
  List<CourseModel> get courses => _courses;
  List<StudentModel> get students => _students;

  DashboardProvider() {
    // Initial fetch
    refreshData();
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  /// Refresh all dashboard data
  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _fetchStats(),
        _fetchCourses(),
        _fetchStudents(),
      ]);
    } catch (e) {
      // print('Error refreshing dashboard data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _coursesSubscription?.cancel();
    _studentsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final statsMap = await _firestoreService.getDashboardStats();
      _stats = _stats.copyWith(
        totalCourses: statsMap['totalCourses'] ?? 0,
        totalVideos: statsMap['totalVideos'] ?? 0,
        // totalStudents: statsMap['totalStudents'] ?? 0, // Reliance on visible list count instead
        // Other stats would ideally come from backend logic or aggregation
      );
    } catch (e) {
      // print('Error fetching stats: $e');
    }
  }

    Future<void> _fetchCourses() async {
    try {
      await _coursesSubscription?.cancel();
      _coursesSubscription = _firestoreService.getCourses().listen((courseList) {
        _courses.clear();
        _courses.addAll(courseList);
        notifyListeners();
      });
    } catch (e) {
      // print('Error fetching courses: $e');
    }
  }

    Future<void> _fetchStudents() async {
    try {
      await _studentsSubscription?.cancel();
      // Get current logged in admin email to exclude from list
      final currentAdminEmail = FirebaseAuth.instance.currentUser?.email;
      
      _studentsSubscription = _firestoreService.getStudents().listen((studentList) {
        _students.clear();
        // Filter out admin
        final filteredList = studentList.where((s) {
          return s.email != currentAdminEmail && !s.email.toLowerCase().contains('admin');
        }).toList();
        
        _students.addAll(filteredList);

        // --- DEMO / DUMMY DATA (If list is empty) ---
        if (_students.isEmpty) {
          _students.add(StudentModel(
            id: 'dummy1',
            name: 'Rahul Sharma (Demo)',
            email: 'rahul.demo@example.com',
            phone: '9876543210',
            enrolledCourses: 1,
            joinedDate: DateTime.now().subtract(const Duration(days: 2)),
            isActive: true,
            avatarUrl: 'https://ui-avatars.com/api/?name=Rahul+Sharma&background=0D8ABC&color=fff'
          ));
           _students.add(StudentModel(
            id: 'dummy2',
            name: 'Priya Patel (Demo)',
            email: 'priya.demo@example.com',
            phone: '',
            enrolledCourses: 0,
            joinedDate: DateTime.now().subtract(const Duration(days: 5)),
            isActive: true,
            avatarUrl: 'https://ui-avatars.com/api/?name=Priya+Patel&background=FF4081&color=fff'
          ));
        }

        // Sync Stats Count with actual list
        _stats = _stats.copyWith(totalStudents: _students.length);
        
        notifyListeners();
      });
    } catch (e) {
      // print('Error fetching students: $e');
    }
  }

  // --- CRUD Operations Wrappers ---

  Future<void> addCourse(CourseModel course) async {
    try {
      await _firestoreService.addCourse(course);
      // Stats will update automatically via listeners/refresh
      await _fetchStats(); 
    } catch (e) {
      // print('Error adding course: $e');
      rethrow;
    }
  }

  Future<void> deleteCourse(String courseId) async {
    try {
      await _firestoreService.deleteCourse(courseId);
      await _fetchStats();
    } catch (e) {
      // print('Error deleting course: $e');
      rethrow;
    }
  }

  // Legacy method for compatibility if needed, but prefer real fetch
  void loadDummyData() {
    // No-op or log warning
    // print('Warning: loadDummyData called but provider is using Firestore');
  }
}
