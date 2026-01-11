import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String duration; // e.g., "15:30"
  final int orderIndex;
  final bool isPublished;
  final bool isFree;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VideoModel({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.orderIndex,
    this.isPublished = false,
    this.isFree = false,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'orderIndex': orderIndex,
      'isPublished': isPublished,
      'isFree': isFree,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create from Firestore DocumentSnapshot
  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoModel(
      id: doc.id,
      courseId: data['courseId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      duration: data['duration'] ?? '0:00',
      orderIndex: data['orderIndex'] ?? 0,
      isPublished: data['isPublished'] ?? false,
      isFree: data['isFree'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Create from Map
  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      id: map['id'] ?? '',
      courseId: map['courseId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      duration: map['duration'] ?? '0:00',
      orderIndex: map['orderIndex'] ?? 0,
      isPublished: map['isPublished'] ?? false,
      isFree: map['isFree'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  VideoModel copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    String? videoUrl,
    String? thumbnailUrl,
    String? duration,
    int? orderIndex,
    bool? isPublished,
    bool? isFree,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      orderIndex: orderIndex ?? this.orderIndex,
      isPublished: isPublished ?? this.isPublished,
      isFree: isFree ?? this.isFree,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
