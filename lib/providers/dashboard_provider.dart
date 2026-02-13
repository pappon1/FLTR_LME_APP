import 'dart:async';
import 'package:flutter/material.dart';
import '../models/dashboard_stats.dart';
import '../models/course_model.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();

  DashboardStats _stats = DashboardStats(
    totalCourses: 0,
    totalVideos: 0,
    totalStudents: 0,
    totalBuyers: 0,
    totalRevenue: 0,
    coursesThisWeek: 0,
    videosThisWeek: 0,
    studentsThisMonth: 0,
    revenueGrowth: 0,
  );

  final List<CourseModel> _courses = [];
  List<CourseModel> _popularCourses = [];
  final List<StudentModel> _students = [];
  final List<StudentModel> _buyers = [];

  // Pagination State for Students
  DocumentSnapshot? _lastStudentDoc;
  DocumentSnapshot? _lastBuyerDoc;
  bool _hasMoreStudents = true;
  bool _hasMoreBuyers = true;
  bool _isLoadingMoreStudents = false;
  bool _isLoadingMoreBuyers = false;

  StreamSubscription? _coursesSubscription;
  StreamSubscription? _studentsSubscription;
  Timer? _coursesDebounce;
  int? _lastCourseEventTs;

  // Getters
  int get selectedIndex => _selectedIndex;
  bool get isLoading => _isLoading;
  DashboardStats get stats => _stats;
  List<CourseModel> get courses => _courses;
  List<CourseModel> get popularCourses => _popularCourses;
  List<StudentModel> get students => _students;
  List<StudentModel> get buyers => _buyers;
  bool get hasMoreStudents => _hasMoreStudents;
  bool get hasMoreBuyers => _hasMoreBuyers;
  bool get isLoadingMoreStudents => _isLoadingMoreStudents;
  bool get isLoadingMoreBuyers => _isLoadingMoreBuyers;

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
    if (_isLoading) return; // Prevent multiple simultaneous refreshes

    final user = FirebaseAuth.instance.currentUser;
    debugPrint("🔍 [DASHBOARD_DEBUG] User: ${user?.email} (ID: ${user?.uid})");

    if (user != null) {
      try {
        final idToken = await user.getIdTokenResult();
        debugPrint("🔍 [DASHBOARD_DEBUG] Auth Claims: ${idToken.claims}");
      } catch (e) {
        debugPrint("🔍 [DASHBOARD_DEBUG] Failed to get Auth Claims: $e");
      }
    } else {
      debugPrint("🔍 [DASHBOARD_DEBUG] NO AUTHENTICATED USER FOUND!");
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Reset pagination on full refresh
      _lastStudentDoc = null;
      _hasMoreStudents = true;
      _students.clear();

      // Run parallel fetches for core data
      await Future.wait([
        _fetchStats(),
        _fetchPopularCourses(),
        _fetchStudents(
          silent: true,
        ), // Silenced notification since we notify at end
      ]);

      // Stream subscription for real-time courses (handled separately)
      await _fetchCourses(silent: true);
    } catch (e) {
      debugPrint('❌ Error refreshing dashboard: $e');
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
      final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
      final statsMap = await _firestoreService.getDashboardStats(
        excludeEmail: currentUserEmail,
      );
      _stats = _stats.copyWith(
        totalCourses: statsMap['totalCourses'] ?? 0,
        totalVideos: statsMap['totalVideos'] ?? 0,
        totalStudents: statsMap['totalStudents'] ?? 0,
        totalBuyers: statsMap['totalBuyers'] ?? 0,
      );
    } catch (e) {
      // print('Error fetching stats: $e');
    }
  }

  Future<void> _fetchPopularCourses() async {
    try {
      // Fetch top courses by enrolledStudents
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .orderBy('enrolledStudents', descending: true)
          .limit(5)
          .get(const GetOptions(source: Source.serverAndCache));

      _popularCourses = snapshot.docs
          .map((doc) => CourseModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching popular courses: $e');
    }
  }

  Future<void> _fetchCourses({bool silent = false}) async {
    try {
      await _coursesSubscription?.cancel();
      _coursesSubscription = _firestoreService.getCourses().listen((
        courseList,
      ) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _lastCourseEventTs ??= 0;
        bool changed = _courses.length != courseList.length;
        if (!changed) {
          for (int i = 0; i < courseList.length; i++) {
            if (_courses[i].id != courseList[i].id) {
              changed = true;
              break;
            }
          }
        }
        if (changed) {
          _courses
            ..clear()
            ..addAll(courseList);
          if (!silent) {
            if (_coursesDebounce?.isActive ?? false) _coursesDebounce!.cancel();
            final int elapsed = now - _lastCourseEventTs!;
            final int delayMs = elapsed < 500 ? 500 - elapsed : 0;
            _coursesDebounce = Timer(Duration(milliseconds: delayMs), () {
              _lastCourseEventTs = DateTime.now().millisecondsSinceEpoch;
              notifyListeners();
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error fetching courses: $e');
    }
  }

  Future<void> _fetchStudents({bool silent = false}) async {
    try {
      final snapshot = await _firestoreService.getStudentsPaginated(limit: 50);

      final currentUserEmail = FirebaseAuth.instance.currentUser?.email
          ?.toLowerCase();

      if (snapshot.docs.isNotEmpty) {
        _lastStudentDoc = snapshot.docs.last;
        _students.clear();
        _students.addAll(
          snapshot.docs.map((doc) => StudentModel.fromFirestore(doc)).where((
            s,
          ) {
            final email = s.email.toLowerCase();
            return email != 'admin@lme.com' &&
                !email.contains('admin') &&
                email != currentUserEmail;
          }).toList(),
        );
        _hasMoreStudents = snapshot.docs.length == 50;
      } else {
        _hasMoreStudents = false;
      }

      // Parallel fetch for buyers
      final buyerSnap = await _firestoreService.getStudentsPaginated(
        limit: 50,
        onlyBuyers: true,
      );
      if (buyerSnap.docs.isNotEmpty) {
        _lastBuyerDoc = buyerSnap.docs.last;
        _buyers.clear();
        _buyers.addAll(
          buyerSnap.docs.map((doc) => StudentModel.fromFirestore(doc)).where((
            s,
          ) {
            final email = s.email.toLowerCase();
            return email != 'admin@lme.com' &&
                !email.contains('admin') &&
                email != currentUserEmail;
          }).toList(),
        );
        _hasMoreBuyers = buyerSnap.docs.length == 50;
      } else {
        _hasMoreBuyers = false;
      }

      if (!silent) notifyListeners();
    } catch (e) {
      debugPrint('Error fetching students: $e');
    }
  }

  Future<void> loadMoreStudents({bool onlyBuyers = false}) async {
    if (onlyBuyers) {
      if (_isLoadingMoreBuyers || !_hasMoreBuyers) return;
      _isLoadingMoreBuyers = true;
    } else {
      if (_isLoadingMoreStudents || !_hasMoreStudents) return;
      _isLoadingMoreStudents = true;
    }

    notifyListeners();

    try {
      final snapshot = await _firestoreService.getStudentsPaginated(
        limit: 50,
        startAfter: onlyBuyers ? _lastBuyerDoc : _lastStudentDoc,
        onlyBuyers: onlyBuyers,
      );

      if (snapshot.docs.isNotEmpty) {
        final currentUserEmail = FirebaseAuth.instance.currentUser?.email
            ?.toLowerCase();
        final newList = snapshot.docs
            .map((doc) => StudentModel.fromFirestore(doc))
            .where((s) {
              final email = s.email.toLowerCase();
              return email != 'admin@lme.com' &&
                  !email.contains('admin') &&
                  email != currentUserEmail;
            })
            .toList();
        if (onlyBuyers) {
          _lastBuyerDoc = snapshot.docs.last;
          _buyers.addAll(newList);
          _hasMoreBuyers = snapshot.docs.length == 50;
        } else {
          _lastStudentDoc = snapshot.docs.last;
          _students.addAll(newList);
          _hasMoreStudents = snapshot.docs.length == 50;
        }
      } else {
        if (onlyBuyers) {
          _hasMoreBuyers = false;
        } else {
          _hasMoreStudents = false;
        }
      }
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      if (onlyBuyers) {
        _isLoadingMoreBuyers = false;
      } else {
        _isLoadingMoreStudents = false;
      }
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
