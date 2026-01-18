import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String id;
  final String title;
  final String category;
  final int price;
  final int discountPrice;
  final String description;
  final String thumbnailUrl;
  final String duration;
  final String difficulty;
  final int enrolledStudents;
  final double rating;
  final int totalVideos;
  final bool isPublished;
  final DateTime? createdAt;
  final int newBatchDays;
  final List<dynamic> contents; // Nested content structure (Folders, Videos, PDFs)

  CourseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    this.discountPrice = 0,
    required this.description,
    required this.thumbnailUrl,
    required this.duration,
    required this.difficulty,
    required this.enrolledStudents,
    required this.rating,
    required this.totalVideos,
    required this.isPublished,
    DateTime? createdAt,
    this.newBatchDays = 90,
    this.contents = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'price': price,
      'discountPrice': discountPrice,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'difficulty': difficulty,
      'enrolledStudents': enrolledStudents,
      'rating': rating,
      'totalVideos': totalVideos,
      'isPublished': isPublished,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'newBatchDays': newBatchDays,
      'contents': contents,
    };
  }

  // Create from Firestore DocumentSnapshot
  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseModel(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      price: data['price'] ?? 0,
      discountPrice: data['discountPrice'] ?? data['price'] ?? 0,
      description: data['description'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      duration: data['duration'] ?? '0 hours',
      difficulty: data['difficulty'] ?? 'Beginner',
      enrolledStudents: data['enrolledStudents'] ?? 0,
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalVideos: data['totalVideos'] ?? 0,
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      newBatchDays: data['newBatchDays'] ?? 90,
      contents: data['contents'] ?? [],
    );
  }

  // Create from Map
  factory CourseModel.fromMap(Map<String, dynamic> map, String id) {
    return CourseModel(
      id: id,
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      price: map['price'] ?? 0,
      discountPrice: map['discountPrice'] ?? map['price'] ?? 0,
      description: map['description'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      duration: map['duration'] ?? '0 hours',
      difficulty: map['difficulty'] ?? 'Beginner',
      enrolledStudents: map['enrolledStudents'] ?? 0,
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalVideos: map['totalVideos'] ?? 0,
      isPublished: map['isPublished'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      newBatchDays: map['newBatchDays'] ?? 90,
      contents: map['contents'] ?? [],
    );
  }

  CourseModel copyWith({
    String? id,
    String? title,
    String? category,
    int? price,
    int? discountPrice,
    String? description,
    String? thumbnailUrl,
    String? duration,
    String? difficulty,
    int? enrolledStudents,
    double? rating,
    int? totalVideos,
    bool? isPublished,
    DateTime? createdAt,
    int? newBatchDays,
    List<dynamic>? contents,
  }) {
    return CourseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      price: price ?? this.price,
      discountPrice: discountPrice ?? this.discountPrice,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      difficulty: difficulty ?? this.difficulty,
      enrolledStudents: enrolledStudents ?? this.enrolledStudents,
      rating: rating ?? this.rating,
      totalVideos: totalVideos ?? this.totalVideos,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      newBatchDays: newBatchDays ?? this.newBatchDays,
      contents: contents ?? this.contents,
    );
  }
}
