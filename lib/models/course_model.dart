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
  final int courseValidityDays;
  final bool hasCertificate;
  final String? certificateUrl1;
  final String? certificateUrl2;
  final int selectedCertificateSlot; // 1 or 2
  final List<String> highlights;
  final List<Map<String, String>> faqs;
  final bool isOfflineDownloadEnabled;
  final List<dynamic>
  contents; // Nested content structure (Folders, Videos, PDFs)
  final String language; // e.g. Hindi, English
  final String courseMode; // e.g. Recorded, Live
  final String supportType; // e.g. WhatsApp, Call
  final String whatsappNumber;
  final bool isBigScreenEnabled;
  final String websiteUrl;
  final String specialTag; // e.g. "Best Seller", "80% Off"
  final String specialTagColor; // Blue, Red, Green, Pink
  final bool isSpecialTagVisible;
  final int specialTagDurationDays; // 0 = Always
  final String? bunnyCollectionId;

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
    this.courseValidityDays = 0, // 0 for Lifetime
    this.hasCertificate = false,
    this.certificateUrl1,
    this.certificateUrl2,
    this.selectedCertificateSlot = 1,
    this.highlights = const [],
    this.faqs = const [],
    this.isOfflineDownloadEnabled = true,
    this.contents = const [],
    this.language = 'Hindi',
    this.courseMode = 'Recorded',
    this.supportType = 'WhatsApp Group',
    this.whatsappNumber = '',
    this.isBigScreenEnabled = false,
    this.websiteUrl = '',
    this.specialTag = '',
    this.specialTagColor = 'Blue',
    this.isSpecialTagVisible = true,
    this.specialTagDurationDays = 30,
    this.bunnyCollectionId,
  }) : createdAt = createdAt;

  // ══════════════════════════════════════════════════════════════════════════════
  // TO MAP - REFACTORED FOR FIRESTORE (Human Readable)
  // ══════════════════════════════════════════════════════════════════════════════
  Map<String, dynamic> toMap() {
    return {
      // 1. Core Info
      'title': title,
      'category': category,
      'price': price,
      'discountPrice': discountPrice,
      'description': description,
      'difficulty': difficulty,
      'language': language,
      'courseMode': courseMode,
      'isPublished': isPublished,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),

      // 2. Media Assets
      'media_assets': {
        'thumbnailUrl': thumbnailUrl,
        'promoVideoUrl': '', // Placeholder for future
        'bannerUrl': '', // Placeholder for future
        'bunnyCollectionId': bunnyCollectionId,
      },

      // 3. Curriculum (Videos/PDFs/Folders)
      'curriculum': contents,

      // 4. Certification
      'certification': {
        'hasCertificate': hasCertificate,
        'certificateUrl1': certificateUrl1,
        'certificateUrl2': certificateUrl2,
        'selectedSlot': selectedCertificateSlot,
      },

      // 5. Support & Links
      'support': {
        'type': supportType,
        'whatsappNumber': whatsappNumber,
        'websiteUrl': websiteUrl,
      },

      // 6. Marketing & Tags
      'marketing': {
        'specialTag': specialTag,
        'specialTagColor': specialTagColor,
        'isTagVisible': isSpecialTagVisible,
        'tagDurationDays': specialTagDurationDays,
        'highlights': highlights,
        'faqs': faqs,
      },

      // 7. System Config
      'config': {
        'validityDays': courseValidityDays,
        'isOfflineDownloadEnabled': isOfflineDownloadEnabled,
        'isBigScreenEnabled': isBigScreenEnabled,
      },

      // 8. Real-time Stats
      'stats': {
        'enrolledStudents': enrolledStudents,
        'rating': rating,
        'totalVideos': totalVideos,
        'durationText': duration,
      },

      // Legacy fields for backward compatibility (optional, but good for transition)
      'thumbnailUrl':
          thumbnailUrl, // Keep at root for now to avoid breaking existing queries
    };
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // FROM FIRESTORE - REFACTORED
  // ══════════════════════════════════════════════════════════════════════════════
  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    return CourseModel._fromData(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory CourseModel._fromData(Map<String, dynamic> data, String id) {
    // Grouped Blocks
    final media = data['media_assets'] as Map<String, dynamic>? ?? {};
    final cert = data['certification'] as Map<String, dynamic>? ?? {};
    final support = data['support'] as Map<String, dynamic>? ?? {};
    final marketing = data['marketing'] as Map<String, dynamic>? ?? {};
    final config = data['config'] as Map<String, dynamic>? ?? {};
    final stats = data['stats'] as Map<String, dynamic>? ?? {};

    return CourseModel(
      id: id,
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      price: _toInt(data['price'], 0),
      discountPrice: _toInt(data['discountPrice'] ?? data['price'], 0),
      description: data['description'] ?? '',
      difficulty: data['difficulty'] ?? 'Beginner',
      isPublished: data['isPublished'] ?? false,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is String)
              ? DateTime.tryParse(data['createdAt'] as String)
              : null,

      // Reading from Media Assets
      thumbnailUrl: media['thumbnailUrl'] ?? data['thumbnailUrl'] ?? '',
      bunnyCollectionId:
          media['bunnyCollectionId']?.toString() ??
          data['bunnyCollectionId']?.toString(),

      // Reading from Curriculum
      contents: data['curriculum'] ?? data['contents'] ?? [],

      // Reading from Certification
      hasCertificate: cert['hasCertificate'] ?? data['hasCertificate'] ?? false,
      certificateUrl1:
          cert['certificateUrl1']?.toString() ??
          data['certificateUrl1']?.toString(),
      certificateUrl2:
          cert['certificateUrl2']?.toString() ??
          data['certificateUrl2']?.toString(),
      selectedCertificateSlot: _toInt(
        cert['selectedSlot'] ?? data['selectedCertificateSlot'],
        1,
      ),

      // Reading from Support
      supportType: support['type'] ?? data['supportType'] ?? 'WhatsApp Group',
      whatsappNumber: support['whatsappNumber'] ?? data['whatsappNumber'] ?? '',
      websiteUrl: support['websiteUrl'] ?? data['websiteUrl'] ?? '',

      // Reading from Marketing
      specialTag: marketing['specialTag'] ?? data['specialTag'] ?? '',
      specialTagColor:
          marketing['specialTagColor'] ?? data['specialTagColor'] ?? 'Blue',
      isSpecialTagVisible:
          marketing['isTagVisible'] ?? data['isSpecialTagVisible'] ?? true,
      specialTagDurationDays: _toInt(
        marketing['tagDurationDays'] ?? data['specialTagDurationDays'],
        0,
      ),
      highlights: List<String>.from(
        marketing['highlights'] ?? data['highlights'] ?? [],
      ),
      faqs:
          (marketing['faqs'] as List<dynamic>? ??
                  data['faqs'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],

      // Reading from Config
      courseValidityDays: _toInt(
        config['validityDays'] ?? data['courseValidityDays'],
        0,
      ),
      isOfflineDownloadEnabled:
          config['isOfflineDownloadEnabled'] ??
          data['isOfflineDownloadEnabled'] ??
          true,
      isBigScreenEnabled:
          config['isBigScreenEnabled'] ?? data['isBigScreenEnabled'] ?? false,

      // Reading from Stats
      enrolledStudents: _toInt(
        stats['enrolledStudents'] ?? data['enrolledStudents'],
        0,
      ),
      rating: (stats['rating'] ?? data['rating'] ?? 0.0).toDouble(),
      totalVideos: _toInt(stats['totalVideos'] ?? data['totalVideos'], 0),
      duration: stats['durationText'] ?? data['duration'] ?? '0 hours',

      language: data['language'] ?? 'Hindi',
      courseMode: data['courseMode'] ?? 'Recorded',
    );
  }

  static int _toInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  // Create from Map (Local DTO)
  factory CourseModel.fromMap(Map<String, dynamic> map, String id) {
    // Check if it's already nested or flat
    final bool isNested = map.containsKey('media_assets');
    if (isNested) {
      return CourseModel._fromData(map, id);
    }

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
          : (map['createdAt'] is String
                ? DateTime.tryParse(map['createdAt'])
                : DateTime.now()),
      courseValidityDays: map['courseValidityDays'] ?? 0,
      hasCertificate: map['hasCertificate'] ?? false,
      certificateUrl1: map['certificateUrl1'],
      certificateUrl2: map['certificateUrl2'],
      selectedCertificateSlot: map['selectedCertificateSlot'] ?? 1,
      highlights: List<String>.from(map['highlights'] ?? []),
      faqs:
          (map['faqs'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      isOfflineDownloadEnabled: map['isOfflineDownloadEnabled'] ?? true,
      contents: map['contents'] ?? [],
      language: map['language'] ?? 'Hindi',
      courseMode: map['courseMode'] ?? 'Recorded',
      supportType: map['supportType'] ?? 'WhatsApp Group',
      whatsappNumber: map['whatsappNumber'] ?? '',
      isBigScreenEnabled: map['isBigScreenEnabled'] ?? false,
      websiteUrl: map['websiteUrl'] ?? '',
      specialTag: map['specialTag'] ?? '',
      specialTagColor: map['specialTagColor'] ?? 'Blue',
      isSpecialTagVisible: map['isSpecialTagVisible'] ?? true,
      specialTagDurationDays: map['specialTagDurationDays'] ?? 30,
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
    int? courseValidityDays,
    bool? hasCertificate,
    String? certificateUrl1,
    String? certificateUrl2,
    int? selectedCertificateSlot,
    List<String>? highlights,
    List<Map<String, String>>? faqs,
    bool? isOfflineDownloadEnabled,
    List<dynamic>? contents,
    String? language,
    String? courseMode,
    String? supportType,
    String? whatsappNumber,
    bool? isBigScreenEnabled,
    String? websiteUrl,
    String? specialTag,
    String? specialTagColor,
    bool? isSpecialTagVisible,
    int? specialTagDurationDays,
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
      courseValidityDays: courseValidityDays ?? this.courseValidityDays,
      hasCertificate: hasCertificate ?? this.hasCertificate,
      certificateUrl1: certificateUrl1 ?? this.certificateUrl1,
      certificateUrl2: certificateUrl2 ?? this.certificateUrl2,
      selectedCertificateSlot:
          selectedCertificateSlot ?? this.selectedCertificateSlot,
      highlights: highlights ?? this.highlights,
      faqs: faqs ?? this.faqs,
      isOfflineDownloadEnabled:
          isOfflineDownloadEnabled ?? this.isOfflineDownloadEnabled,
      contents: contents ?? this.contents,
      language: language ?? this.language,
      courseMode: courseMode ?? this.courseMode,
      supportType: supportType ?? this.supportType,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      isBigScreenEnabled: isBigScreenEnabled ?? this.isBigScreenEnabled,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      specialTag: specialTag ?? this.specialTag,
      specialTagColor: specialTagColor ?? this.specialTagColor,
      isSpecialTagVisible: isSpecialTagVisible ?? this.isSpecialTagVisible,
      specialTagDurationDays:
          specialTagDurationDays ?? this.specialTagDurationDays,
    );
  }
}
