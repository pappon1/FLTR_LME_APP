import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final int enrolledCourses;
  final DateTime joinedDate;
  final bool isActive;
  final String avatarUrl;

  StudentModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.enrolledCourses,
    required this.joinedDate,
    required this.isActive,
    required this.avatarUrl,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'enrolledCourses': enrolledCourses,
      'joinedDate': Timestamp.fromDate(joinedDate),
      'isActive': isActive,
      'avatarUrl': avatarUrl,
    };
  }

  // Create from Firestore DocumentSnapshot
  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentModel(
      id: doc.id,
      name: data['name'] ?? data['displayName'] ?? 'Unknown',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      enrolledCourses: data['enrolledCourses'] ?? 0,
      joinedDate: (data['joinedDate'] ?? data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      avatarUrl: data['avatarUrl'] ?? data['photoURL'] ?? 'https://ui-avatars.com/api/?name=${data['name'] ?? 'User'}&background=6366f1&color=fff',
    );
  }

  StudentModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    int? enrolledCourses,
    DateTime? joinedDate,
    bool? isActive,
    String? avatarUrl,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      enrolledCourses: enrolledCourses ?? this.enrolledCourses,
      joinedDate: joinedDate ?? this.joinedDate,
      isActive: isActive ?? this.isActive,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
