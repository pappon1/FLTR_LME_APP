import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 💎 JSON SAFETY: SINGLE SOURCE OF TRUTH FOR KEYS
// ══════════════════════════════════════════════════════════════════════════════
class CourseKeys {
  static const String id = 'id';
  static const String title = 'title';
  static const String category = 'category';
  static const String price = 'price';
  static const String discountPrice = 'discountPrice';
  static const String description = 'description';
  static const String difficulty = 'difficulty';
  static const String language = 'language';
  static const String courseMode = 'courseMode';
  static const String isPublished = 'isPublished';
  static const String createdAt = 'createdAt';
  
  // Nested Blocks
  static const String mediaAssets = 'media_assets';
  static const String curriculum = 'curriculum';
  static const String certification = 'certification';
  static const String support = 'support';
  static const String marketing = 'marketing';
  static const String config = 'config';
  static const String stats = 'stats';

  // Sub-keys: Media
  static const String thumbnailUrl = 'thumbnailUrl';
  static const String bunnyCollectionId = 'bunnyCollectionId';

  // Sub-keys: Certification
  static const String hasCertificate = 'hasCertificate';
  static const String certUrl1 = 'certificateUrl1';
  static const String certUrl2 = 'certificateUrl2';
  static const String selectedSlot = 'selectedSlot';

  // Sub-keys: Support
  static const String supportType = 'type';
  static const String whatsappNumber = 'whatsappNumber';
  static const String websiteUrl = 'websiteUrl';

  // Sub-keys: Marketing
  static const String specialTag = 'specialTag';
  static const String specialTagColor = 'specialTagColor';
  static const String isTagVisible = 'isTagVisible';
  static const String highlights = 'highlights';
  static const String faqs = 'faqs';

  // Sub-keys: Config
  static const String validityDays = 'validityDays';
  static const String offlineEnabled = 'isOfflineDownloadEnabled';
  static const String bigScreenEnabled = 'isBigScreenEnabled';
}

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
  // TO MAP - USING CONSTANT KEYS
  // ══════════════════════════════════════════════════════════════════════════════
  Map<String, dynamic> toMap() {
    return {
      CourseKeys.title: title,
      CourseKeys.category: category,
      CourseKeys.price: price,
      CourseKeys.discountPrice: discountPrice,
      CourseKeys.description: description,
      CourseKeys.difficulty: difficulty,
      CourseKeys.language: language,
      CourseKeys.courseMode: courseMode,
      CourseKeys.isPublished: isPublished,
      CourseKeys.createdAt: createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),

      CourseKeys.mediaAssets: {
        CourseKeys.thumbnailUrl: thumbnailUrl,
        CourseKeys.bunnyCollectionId: bunnyCollectionId,
      },

      CourseKeys.curriculum: contents,

      CourseKeys.certification: {
        CourseKeys.hasCertificate: hasCertificate,
        CourseKeys.certUrl1: certificateUrl1,
        CourseKeys.certUrl2: certificateUrl2,
        CourseKeys.selectedSlot: selectedCertificateSlot,
      },

      CourseKeys.support: {
        CourseKeys.supportType: supportType,
        CourseKeys.whatsappNumber: whatsappNumber,
        CourseKeys.websiteUrl: websiteUrl,
      },

      CourseKeys.marketing: {
        CourseKeys.specialTag: specialTag,
        CourseKeys.specialTagColor: specialTagColor,
        CourseKeys.isTagVisible: isSpecialTagVisible,
        'tagDurationDays': specialTagDurationDays,
        CourseKeys.highlights: highlights,
        CourseKeys.faqs: faqs,
      },

      CourseKeys.config: {
        CourseKeys.validityDays: courseValidityDays,
        CourseKeys.offlineEnabled: isOfflineDownloadEnabled,
        CourseKeys.bigScreenEnabled: isBigScreenEnabled,
      },

      CourseKeys.stats: {
        'enrolledStudents': enrolledStudents,
        'rating': rating,
        'totalVideos': totalVideos,
        'durationText': duration,
      },
    };
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // FROM FIRESTORE - ROBUST PARSING
  // ══════════════════════════════════════════════════════════════════════════════
  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    return CourseModel._fromData(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory CourseModel._fromData(Map<String, dynamic> data, String id) {
    final media = data[CourseKeys.mediaAssets] as Map<String, dynamic>? ?? {};
    final cert = data[CourseKeys.certification] as Map<String, dynamic>? ?? {};
    final support = data[CourseKeys.support] as Map<String, dynamic>? ?? {};
    final marketing = data[CourseKeys.marketing] as Map<String, dynamic>? ?? {};
    final config = data[CourseKeys.config] as Map<String, dynamic>? ?? {};
    final stats = data[CourseKeys.stats] as Map<String, dynamic>? ?? {};

    return CourseModel(
      id: id,
      title: data[CourseKeys.title] ?? '',
      category: data[CourseKeys.category] ?? '',
      price: _toInt(data[CourseKeys.price], 0),
      discountPrice: _toInt(data[CourseKeys.discountPrice] ?? data[CourseKeys.price], 0),
      description: data[CourseKeys.description] ?? '',
      difficulty: data[CourseKeys.difficulty] ?? 'Beginner',
      isPublished: data[CourseKeys.isPublished] ?? false,
      createdAt: (data[CourseKeys.createdAt] is Timestamp)
          ? (data[CourseKeys.createdAt] as Timestamp).toDate()
          : (data[CourseKeys.createdAt] is String)
              ? DateTime.tryParse(data[CourseKeys.createdAt] as String)
              : null,

      thumbnailUrl: media[CourseKeys.thumbnailUrl] ?? data['thumbnailUrl'] ?? '',
      bunnyCollectionId:
          media[CourseKeys.bunnyCollectionId]?.toString() ??
          data['bunnyCollectionId']?.toString(),

      contents: data[CourseKeys.curriculum] ?? data['contents'] ?? [],

      hasCertificate: cert[CourseKeys.hasCertificate] ?? data['hasCertificate'] ?? false,
      certificateUrl1:
          cert[CourseKeys.certUrl1]?.toString() ??
          data['certificateUrl1']?.toString(),
      certificateUrl2:
          cert[CourseKeys.certUrl2]?.toString() ??
          data['certificateUrl2']?.toString(),
      selectedCertificateSlot: _toInt(
        cert[CourseKeys.selectedSlot] ?? data['selectedCertificateSlot'],
        1,
      ),

      supportType: support[CourseKeys.supportType] ?? data['supportType'] ?? 'WhatsApp Group',
      whatsappNumber: support[CourseKeys.whatsappNumber] ?? data['whatsappNumber'] ?? '',
      websiteUrl: support[CourseKeys.websiteUrl] ?? data['websiteUrl'] ?? '',

      specialTag: marketing[CourseKeys.specialTag] ?? data['specialTag'] ?? '',
      specialTagColor:
          marketing[CourseKeys.specialTagColor] ?? data['specialTagColor'] ?? 'Blue',
      isSpecialTagVisible:
          marketing[CourseKeys.isTagVisible] ?? data['isSpecialTagVisible'] ?? true,
      specialTagDurationDays: _toInt(
        marketing['tagDurationDays'] ?? data['specialTagDurationDays'],
        0,
      ),
      highlights: List<String>.from(
        marketing[CourseKeys.highlights] ?? data['highlights'] ?? [],
      ),
      faqs:
          (marketing[CourseKeys.faqs] as List<dynamic>? ??
                  data[CourseKeys.faqs] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],

      courseValidityDays: _toInt(
        config[CourseKeys.validityDays] ?? data['courseValidityDays'],
        0,
      ),
      isOfflineDownloadEnabled:
          config[CourseKeys.offlineEnabled] ??
          data['isOfflineDownloadEnabled'] ??
          true,
      isBigScreenEnabled:
          config[CourseKeys.bigScreenEnabled] ?? data['isBigScreenEnabled'] ?? false,

      enrolledStudents: _toInt(
        stats['enrolledStudents'] ?? data['enrolledStudents'],
        0,
      ),
      rating: (stats['rating'] ?? data['rating'] ?? 0.0).toDouble(),
      totalVideos: _toInt(stats['totalVideos'] ?? data['totalVideos'], 0),
      duration: stats['durationText'] ?? data['duration'] ?? '0 hours',

      language: data[CourseKeys.language] ?? 'Hindi',
      courseMode: data[CourseKeys.courseMode] ?? 'Recorded',
    );
  }

  static int _toInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  // Local DTO from plain map
  factory CourseModel.fromMap(Map<String, dynamic> map, String id) {
    final bool isNested = map.containsKey(CourseKeys.mediaAssets);
    if (isNested) return CourseModel._fromData(map, id);

    return CourseModel(
      id: id,
      title: map[CourseKeys.title] ?? '',
      category: map[CourseKeys.category] ?? '',
      price: map[CourseKeys.price] ?? 0,
      discountPrice: map[CourseKeys.discountPrice] ?? map[CourseKeys.price] ?? 0,
      description: map[CourseKeys.description] ?? '',
      thumbnailUrl: map[CourseKeys.thumbnailUrl] ?? '',
      duration: map['duration'] ?? '0 hours',
      difficulty: map[CourseKeys.difficulty] ?? 'Beginner',
      enrolledStudents: map['enrolledStudents'] ?? 0,
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalVideos: map['totalVideos'] ?? 0,
      isPublished: map[CourseKeys.isPublished] ?? false,
      createdAt: map[CourseKeys.createdAt] is Timestamp
          ? (map[CourseKeys.createdAt] as Timestamp).toDate()
          : (map[CourseKeys.createdAt] is String
                ? DateTime.tryParse(map[CourseKeys.createdAt])
                : DateTime.now()),
      courseValidityDays: map['courseValidityDays'] ?? 0,
      hasCertificate: map['hasCertificate'] ?? false,
      certificateUrl1: map['certificateUrl1'],
      certificateUrl2: map['certificateUrl2'],
      selectedCertificateSlot: map['selectedCertificateSlot'] ?? 1,
      highlights: List<String>.from(map['highlights'] ?? []),
      faqs:
          (map[CourseKeys.faqs] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      isOfflineDownloadEnabled: map['isOfflineDownloadEnabled'] ?? true,
      contents: map['contents'] ?? [],
      language: map[CourseKeys.language] ?? 'Hindi',
      courseMode: map[CourseKeys.courseMode] ?? 'Recorded',
      supportType: map['supportType'] ?? 'WhatsApp Group',
      whatsappNumber: map['whatsappNumber'] ?? '',
      isBigScreenEnabled: map['isBigScreenEnabled'] ?? false,
      websiteUrl: map['websiteUrl'] ?? '',
      specialTag: map[CourseKeys.specialTag] ?? '',
      specialTagColor: map[CourseKeys.specialTagColor] ?? 'Blue',
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
