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
  final int courseValidityDays;
  final bool hasCertificate;
  final String? certificateUrl1;
  final String? certificateUrl2;
  final int selectedCertificateSlot; // 1 or 2
  final List<dynamic> demoVideos; // List of demo video objects
  final List<String> highlights;
  final List<Map<String, String>> faqs;
  final bool isOfflineDownloadEnabled;
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
    this.courseValidityDays = 0, // 0 for Lifetime
    this.hasCertificate = false,
    this.certificateUrl1,
    this.certificateUrl2,
    this.selectedCertificateSlot = 1,
    this.demoVideos = const [],
    this.highlights = const [],
    this.faqs = const [],
    this.isOfflineDownloadEnabled = true,
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
      'courseValidityDays': courseValidityDays,
      'hasCertificate': hasCertificate,
      'certificateUrl1': certificateUrl1,
      'certificateUrl2': certificateUrl2,
      'selectedCertificateSlot': selectedCertificateSlot,
      'demoVideos': demoVideos,
      'highlights': highlights,
      'faqs': faqs,
      'isOfflineDownloadEnabled': isOfflineDownloadEnabled,
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
      price: _toInt(data['price'], 0),
      discountPrice: _toInt(data['discountPrice'] ?? data['price'], 0),
      description: data['description'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      duration: data['duration'] ?? '0 hours',
      difficulty: data['difficulty'] ?? 'Beginner',
      enrolledStudents: data['enrolledStudents'] ?? 0,
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalVideos: data['totalVideos'] ?? 0,
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : null,
      newBatchDays: _toInt(data['newBatchDays'], 90),
      courseValidityDays: _toInt(data['courseValidityDays'], 0),
      hasCertificate: data['hasCertificate'] ?? false,
      certificateUrl1: data['certificateUrl1']?.toString(),
      certificateUrl2: data['certificateUrl2']?.toString(),
      selectedCertificateSlot: _toInt(data['selectedCertificateSlot'], 1),
      demoVideos: data['demoVideos'] ?? [],
      highlights: List<String>.from(data['highlights'] ?? []),
      faqs: (data['faqs'] as List<dynamic>?)?.map((e) => Map<String, String>.from(e)).toList() ?? [],
      isOfflineDownloadEnabled: data['isOfflineDownloadEnabled'] ?? true,
      contents: data['contents'] ?? [],
    );
  }

  static int _toInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
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
      courseValidityDays: map['courseValidityDays'] ?? 0,
      hasCertificate: map['hasCertificate'] ?? false,
      certificateUrl1: map['certificateUrl1'],
      certificateUrl2: map['certificateUrl2'],
      selectedCertificateSlot: map['selectedCertificateSlot'] ?? 1,
      demoVideos: map['demoVideos'] ?? [],
      highlights: List<String>.from(map['highlights'] ?? []),
      faqs: (map['faqs'] as List<dynamic>?)?.map((e) => Map<String, String>.from(e)).toList() ?? [],
      isOfflineDownloadEnabled: map['isOfflineDownloadEnabled'] ?? true,
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
    int? courseValidityDays,
    bool? hasCertificate,
    String? certificateUrl1,
    String? certificateUrl2,
    int? selectedCertificateSlot,
    List<dynamic>? demoVideos,
    List<String>? highlights,
    List<Map<String, String>>? faqs,
    bool? isOfflineDownloadEnabled,
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
      courseValidityDays: courseValidityDays ?? this.courseValidityDays,
      hasCertificate: hasCertificate ?? this.hasCertificate,
      certificateUrl1: certificateUrl1 ?? this.certificateUrl1,
      certificateUrl2: certificateUrl2 ?? this.certificateUrl2,
      selectedCertificateSlot: selectedCertificateSlot ?? this.selectedCertificateSlot,
      demoVideos: demoVideos ?? this.demoVideos,
      highlights: highlights ?? this.highlights,
      faqs: faqs ?? this.faqs,
      isOfflineDownloadEnabled: isOfflineDownloadEnabled ?? this.isOfflineDownloadEnabled,
      contents: contents ?? this.contents,
    );
  }
}
