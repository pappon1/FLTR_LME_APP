import 'dart:async';
import 'package:flutter/material.dart';
import '../models/dashboard_stats.dart';
import '../models/course_model.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  
  // Pagination State for Students
  DocumentSnapshot? _lastStudentDoc;
  bool _hasMoreStudents = true;
  bool _isLoadingMoreStudents = false;
  
  StreamSubscription? _coursesSubscription;
  StreamSubscription? _studentsSubscription;

  // Getters
  int get selectedIndex => _selectedIndex;
  bool get isLoading => _isLoading;
  DashboardStats get stats => _stats;
  List<CourseModel> get courses => _courses;
  List<StudentModel> get students => _students;
  bool get hasMoreStudents => _hasMoreStudents;
  bool get isLoadingMoreStudents => _isLoadingMoreStudents;

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
      // Reset pagination on full refresh
      _lastStudentDoc = null;
      _hasMoreStudents = true;
      _students.clear();

      await Future.wait([
        _fetchStats(),
        _fetchCourses(),
        _fetchStudents(), // This will now fetch the first page
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
      // Logic Fix: Switch to paginated fetch to prevent app hang with large user base
      final snapshot = await _firestoreService.getStudentsPaginated(limit: 50);
      
      if (snapshot.docs.isNotEmpty) {
        _lastStudentDoc = snapshot.docs.last;
        _students.clear();
        
        final newList = snapshot.docs
            .map((doc) => StudentModel.fromFirestore(doc))
            .where((s) => !s.email.toLowerCase().contains('admin'))
            .toList();
            
        _students.addAll(newList);
        _hasMoreStudents = snapshot.docs.length == 50;
      } else {
        _hasMoreStudents = false;
      }
      notifyListeners();
    } catch (e) {
      // debugPrint('Error fetching students: $e');
    }
  }

  Future<void> loadMoreStudents() async {
    if (_isLoadingMoreStudents || !_hasMoreStudents) return;

    _isLoadingMoreStudents = true;
    notifyListeners();

    try {
      final snapshot = await _firestoreService.getStudentsPaginated(
        limit: 50, 
        startAfter: _lastStudentDoc
      );

      if (snapshot.docs.isNotEmpty) {
        _lastStudentDoc = snapshot.docs.last;
        
        final newList = snapshot.docs
            .map((doc) => StudentModel.fromFirestore(doc))
            .where((s) => !s.email.toLowerCase().contains('admin'))
            .toList();
            
        _students.addAll(newList);
        _hasMoreStudents = snapshot.docs.length == 50;
      } else {
        _hasMoreStudents = false;
      }
    } catch (e) {
      // debugPrint('Error loading more students: $e');
    } finally {
      _isLoadingMoreStudents = false;
      notifyListeners();
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
