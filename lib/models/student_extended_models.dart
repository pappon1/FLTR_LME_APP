import 'package:cloud_firestore/cloud_firestore.dart';

class EnrollmentDetail {
  final String enrollmentId;
  final String courseId;
  final String studentId;
  final bool isActive;
  final DateTime enrolledAt;
  final DateTime? expiryDate;
  // Merged Course Data
  final String courseTitle;
  final String courseThumbnail;

  EnrollmentDetail({
    required this.enrollmentId,
    required this.courseId,
    required this.studentId,
    required this.isActive,
    required this.enrolledAt,
    this.expiryDate,
    required this.courseTitle,
    required this.courseThumbnail,
  });
}

class LoginHistoryModel {
  final String deviceName;
  final String location;
  final String ipAddress;
  final DateTime loginTime;

  LoginHistoryModel({
    required this.deviceName,
    required this.location,
    required this.ipAddress,
    required this.loginTime,
  });
}
