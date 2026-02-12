import 'package:cloud_firestore/cloud_firestore.dart';

enum AnnouncementActionType { none, link, course, screen }

class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final String imageUrl;
  final AnnouncementActionType actionType;
  final String? actionValue; // URL or Course ID
  final DateTime createdAt;
  final DateTime? expiryDate;
  final bool isActive;
  final String createdBy;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.imageUrl,
    this.actionType = AnnouncementActionType.none,
    this.actionValue,
    required this.createdAt,
    this.expiryDate,
    this.isActive = true,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'imageUrl': imageUrl,
      'actionType': actionType.name,
      'actionValue': actionValue,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isActive': isActive,
      'createdBy': createdBy,
    };
  }

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnnouncementModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      actionType: AnnouncementActionType.values.firstWhere(
        (e) => e.name == (data['actionType'] ?? 'none'),
        orElse: () => AnnouncementActionType.none,
      ),
      actionValue: data['actionValue'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      createdBy: data['createdBy'] ?? 'admin',
    );
  }

  AnnouncementModel copyWith({
    String? id,
    String? title,
    String? message,
    String? imageUrl,
    AnnouncementActionType? actionType,
    String? actionValue,
    DateTime? createdAt,
    DateTime? expiryDate,
    bool? isActive,
    String? createdBy,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      imageUrl: imageUrl ?? this.imageUrl,
      actionType: actionType ?? this.actionType,
      actionValue: actionValue ?? this.actionValue,
      createdAt: createdAt ?? this.createdAt,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
