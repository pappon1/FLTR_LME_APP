import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/student_model.dart';
import '../models/video_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== COURSES ====================

  /// Get all courses
  Stream<List<CourseModel>> getCourses() {
    print("📡 FETCHING COURSES FROM FIRESTORE...");
    return _firestore
        .collection('courses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print("📊 Firestore Emitted ${snapshot.docs.length} documents");
          final courses = <CourseModel>[];
          for (var doc in snapshot.docs) {
            try {
              final course = CourseModel.fromFirestore(doc);
              print("📖 Loaded Course: ${course.title}");
              courses.add(course);
            } catch (e) {
              print("❌ FAILED TO PARSE COURSE [${doc.id}]: $e");
              // Continue to next course instead of failing entire stream
            }
          }
          print(
            "✅ Successfully parsed ${courses.length} / ${snapshot.docs.length} courses",
          );
          return courses;
        });
  }

  /// Get single course stream
  Stream<CourseModel> getCourseStream(String courseId) {
    return _firestore.collection('courses').doc(courseId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) {
        throw Exception("Course not found");
      }
      return CourseModel.fromFirestore(doc);
    });
  }

  /// Add new course
  Future<String> addCourse(CourseModel course) async {
    final docRef = await _firestore.collection('courses').add(course.toMap());
    return docRef.id;
  }

  /// Update course
  Future<void> updateCourse(String courseId, Map<String, dynamic> data) async {
    await _firestore.collection('courses').doc(courseId).update(data);
  }

  /// Delete course
  Future<void> deleteCourse(String courseId) async {
    await _firestore.collection('courses').doc(courseId).delete();
  }

  // ==================== VIDEOS ====================

  /// Get videos for a course
  Stream<List<VideoModel>> getVideosForCourse(String courseId) {
    return _firestore
        .collection('videos')
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => VideoModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Add new video
  Future<String> addVideo(VideoModel video) async {
    final docRef = await _firestore.collection('videos').add(video.toMap());
    return docRef.id;
  }

  /// Update video
  Future<void> updateVideo(String videoId, Map<String, dynamic> data) async {
    await _firestore.collection('videos').doc(videoId).update(data);
  }

  /// Delete video
  Future<void> deleteVideo(String videoId) async {
    await _firestore.collection('videos').doc(videoId).delete();
  }

  /// Delete all videos for a course (Batch Delete, No Order Required)
  Future<void> deleteCourseVideos(String courseId) async {
    final snapshot = await _firestore
        .collection('videos')
        .where('courseId', isEqualTo: courseId)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ==================== STUDENTS/USERS ====================

  /// Get all students (Legacy, avoids breaking current listeners)
  Stream<List<StudentModel>> getStudents() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'user')
        // .orderBy('createdAt', descending: true) // Index required
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StudentModel.fromFirestore(doc))
              .where(
                (s) => s.email != 'admin@lme.com' && !s.email.contains('admin'),
              )
              .toList(),
        );
  }

  /// Get students with pagination support
  Future<QuerySnapshot> getStudentsPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
    bool onlyBuyers = false,
  }) async {
    var query = _firestore.collection('users').where('role', isEqualTo: 'user');

    if (onlyBuyers) {
      query = query.where('enrolledCourses', isGreaterThan: 0);
    }

    query = query.limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.get();
  }

  /// Get student by ID
  Future<StudentModel?> getStudentById(String studentId) async {
    final doc = await _firestore.collection('users').doc(studentId).get();
    if (doc.exists) {
      return StudentModel.fromFirestore(doc);
    }
    return null;
  }

  /// Delete user and their enrollments (Atomic Cleanup)
  Future<void> deleteUser(String userId) async {
    final batch = _firestore.batch();

    // 1. Delete user document
    batch.delete(_firestore.collection('users').doc(userId));

    // 2. Delete all user enrollments
    final enrollRef = await _firestore
        .collection('enrollments')
        .where('studentId', isEqualTo: userId)
        .get();

    for (var doc in enrollRef.docs) {
      batch.delete(doc.reference);

      // OPTIONAL: We could also decrement enrolledStudents on each course here
      // But for a fast delete, this is the essential cleanup
    }

    await batch.commit();
  }

  // ==================== ENROLLMENTS ====================

  /// Enroll student in course (Atomic Batch Update)
  Future<void> enrollStudent(
    String studentId,
    String courseId, {
    DateTime? expiryDate,
  }) async {
    final batch = _firestore.batch();

    // 1. Create enrollment document
    final enrollmentRef = _firestore.collection('enrollments').doc();
    batch.set(enrollmentRef, {
      'studentId': studentId,
      'courseId': courseId,
      'enrolledAt': FieldValue.serverTimestamp(),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'progress': 0,
      'completedVideos': [],
      'isActive': true,
    });

    // 2. Increment enrolledCourses count on user document
    final userRef = _firestore.collection('users').doc(studentId);
    batch.update(userRef, {'enrolledCourses': FieldValue.increment(1)});

    // 3. Increment enrolledStudents count on course document
    final courseRef = _firestore.collection('courses').doc(courseId);
    batch.update(courseRef, {'enrolledStudents': FieldValue.increment(1)});

    await batch.commit();
  }

  /// Get enrollments for a student
  Future<List<String>> getStudentEnrollments(String studentId) async {
    final snapshot = await _firestore
        .collection('enrollments')
        .where('studentId', isEqualTo: studentId)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['courseId'] as String)
        .toList();
  }

  /// Get detailed enrollments for a student
  Stream<List<Map<String, dynamic>>> getStudentEnrollmentDetails(
    String studentId,
  ) {
    return _firestore
        .collection('enrollments')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .asyncMap((snapshot) async {
          final futures = snapshot.docs.map((doc) async {
            final data = doc.data();
            final courseId = data['courseId'];

            // Fetch course details
            String courseTitle = 'Unknown Course';
            String courseThumbnail = '';
            String price = 'Free';

            if (courseId != null) {
              final courseDoc = await _firestore
                  .collection('courses')
                  .doc(courseId)
                  .get();
              if (courseDoc.exists) {
                final courseData = courseDoc.data()!;
                courseTitle = courseData['title'] ?? 'Unknown Course';
                courseThumbnail =
                    courseData['thumbnailUrl'] ??
                    ''; // Adjust key based on CourseModel
                price = courseData['price']?.toString() ?? 'Free';
              }
            }

            return {
              'enrollmentId': doc.id,
              'courseId': courseId,
              'isActive': data['isActive'] ?? false,
              'enrolledAt': (data['enrolledAt'] as Timestamp?)?.toDate(),
              'expiryDate': (data['expiryDate'] as Timestamp?)
                  ?.toDate(), // Nullable
              'courseTitle': courseTitle,
              'courseThumbnail': courseThumbnail,
              'price': '₹$price', // Formatting
              'paymentDetail': 'Online', // Placeholder
            };
          });

          return Future.wait(futures);
        });
  }

  /// Toggle Enrollment Status (Active/Inactive)
  Future<void> toggleEnrollmentStatus(
    String enrollmentId,
    bool newStatus,
  ) async {
    try {
      await _firestore.collection('enrollments').doc(enrollmentId).update({
        'isActive': newStatus,
      });
    } catch (e) {
      // debugPrint('Error toggling status: $e');
      rethrow;
    }
  }

  /// Revoke (Delete) Enrollment
  Future<void> revokeEnrollment(String enrollmentId) async {
    try {
      await _firestore.collection('enrollments').doc(enrollmentId).delete();
    } catch (e) {
      // debugPrint('Error revoking enrollment: $e');
      rethrow;
    }
  }

  /// Get User Login/Device History (Mock for now, can be real later)
  Future<List<Map<String, String>>> getLoginHistory(String userId) async {
    return [
      {
        'sessionId': 'sess_1',
        'device': 'Samsung Galaxy S23 Ultra',
        'location': 'New Delhi, India',
        'ip': '192.168.1.45',
        'time': DateTime.now().subtract(const Duration(minutes: 15)).toString(),
      },
      {
        'sessionId': 'sess_2',
        'device': 'Chrome Browser (Windows)',
        'location': 'New Delhi, India',
        'ip': '192.168.1.45',
        'time': DateTime.now().subtract(const Duration(hours: 4)).toString(),
      },
      {
        'sessionId': 'sess_3',
        'device': 'Samsung Galaxy S23 Ultra',
        'location': 'Mumbai, India',
        'ip': '10.0.0.12',
        'time': DateTime.now().subtract(const Duration(days: 2)).toString(),
      },
      {
        'sessionId': 'sess_4',
        'device': 'OnePlus 11R',
        'location': 'Pune, India',
        'ip': '172.16.0.5',
        'time': DateTime.now().subtract(const Duration(days: 5)).toString(),
      },
    ];
  }

  /// Revoke a specific device session (Logout device)
  Future<void> revokeDeviceSession(String userId, String sessionId) async {
    // Mock delay
    await Future.delayed(const Duration(seconds: 1));
    // In real app, you would delete the session token from 'user_sessions' collection
    // await _firestore.collection('users').doc(userId).collection('sessions').doc(sessionId).delete();
  }

  // ==================== NOTIFICATIONS ====================

  /// Send notification to all users
  Future<void> sendNotificationToAll({
    required String title,
    required String message,
    String? imageUrl,
  }) async {
    await _firestore.collection('notifications').add({
      'title': title,
      'message': message,
      'imageUrl': imageUrl,
      'targetAudience': 'all',
      'sentAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  /// Send notification to specific users
  Future<void> sendNotificationToUsers({
    required String title,
    required String message,
    required List<String> userIds,
    String? imageUrl,
  }) async {
    final batch = _firestore.batch();

    for (final userId in userIds) {
      final docRef = _firestore.collection('notifications').doc();
      batch.set(docRef, {
        'userId': userId,
        'title': title,
        'message': message,
        'imageUrl': imageUrl,
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    await batch.commit();
  }

  // ==================== ANALYTICS ====================

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final coursesCount = await _firestore
          .collection('courses')
          .count()
          .get(source: AggregateSource.server);
      final videosCount = await _firestore
          .collection('videos')
          .count()
          .get(source: AggregateSource.server);
      final usersCount = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'user')
          .count()
          .get(source: AggregateSource.server);

      final buyersCount = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'user')
          .where('enrolledCourses', isGreaterThan: 0)
          .count()
          .get(source: AggregateSource.server);

      return {
        'totalCourses': coursesCount.count ?? 0,
        'totalVideos': videosCount.count ?? 0,
        'totalStudents': usersCount.count ?? 0,
        'totalBuyers': buyersCount.count ?? 0,
        'totalRevenue': 0, // Calculate from payments collection
      };
    } catch (e) {
      debugPrint("❌ Error fetching dashboard stats: $e");
      return {};
    }
  }
}
