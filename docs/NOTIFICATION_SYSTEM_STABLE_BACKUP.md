# Notification System - Stable State Backup
**Date:** January 10, 2026
**Status:** All bugs fixed (Keyboard, Images, History Sorting).

This document serves as a full code backup of the Notification System. If any future changes break the functionality, refer to the code below to restore the working state.

---

## 1. Key Fixes Implemented
1.  **Image Loading (403 Forbidden Fix):**
    *   Moved logic to `BunnyCDNService`.
    *   Added `AccessKey` header to all `CachedNetworkImage` widgets.
    *   Implemented `getAuthenticatedUrl` helper to convert public URLs to storage URLs.
2.  **Keyboard Logic:**
    *   Added `onTapOutside` to `TextFormField`s in Send and Edit screens.
    *   Added `FocusScope.of(context).unfocus()` on Date/Time pickers, Dropdowns, and Tab changes.
3.  **History Error:**
    *   Removed `.orderBy('sentAt')` from Firestore query to prevent Index errors.
    *   Implemented client-side sorting: `docs.sort((a, b) => ...`.

---

## 2. File: `lib/services/bunny_cdn_service.dart`
**Purpose:** Handles Image Uploads and URL Authentication.

```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

class BunnyCDNService {
  // Bunny.net Storage Zone Configuration
  static const String storageZoneName = 'lme-media-storage';
  static const String hostname = 'sg.storage.bunnycdn.com';
  static const String accessKey = 'eae59342-6952-4d56-bb2fb8745da1-adf7-402d';
  static const String cdnUrl = 'https://lme-media-storage.b-cdn.net';
  
  final Dio _dio = Dio();

  /// Get the Authenticated URL for Admin access (Direct Storage)
  String getAuthenticatedUrl(String publicUrl) {
    // If it's already a public CDN URL, convert to Storage URL
    if (publicUrl.startsWith(cdnUrl)) {
      return publicUrl.replaceFirst(cdnUrl, 'https://$hostname/$storageZoneName');
    }
    return publicUrl;
  }

  /// Upload file to Bunny.net CDN
  Future<String> uploadFile({
    required String filePath,
    required String remotePath,
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      final fileBytes = await file.readAsBytes();
      final fileName = path.basename(filePath);
      
      // Construct API endpoint
      final apiUrl = 'https://$hostname/$storageZoneName/$remotePath';
      
      print('🚀 Uploading to Bunny CDN: $apiUrl');
      
      final response = await _dio.put(
        apiUrl,
        data: Stream.fromIterable(fileBytes.map((e) => [e])),
        options: Options(
          headers: {
            'AccessKey': accessKey,
            'Content-Type': _getContentType(fileName),
            'Content-Length': fileBytes.length,
          },
        ),
        onSendProgress: onProgress,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final publicUrl = '$cdnUrl/$remotePath';
        print('✅ Upload successful: $publicUrl');
        return Uri.encodeFull(publicUrl);
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Bunny CDN upload error: $e');
      rethrow;
    }
  }

  // ... (Other upload helper methods omitted for brevity, logic is same)
  // uploadVideo, uploadImage, uploadPDF just call uploadFile
}
```

---

## 3. File: `lib/screens/notifications/sent_history_screen.dart`
**Purpose:** Displays Sent Notifications. Uses Client-Side Sorting.

```dart
// Key imports
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/bunny_cdn_service.dart';

// Inside build method -> StreamBuilder:
stream: FirebaseFirestore.instance
    .collection('notifications')
    .where('status', isEqualTo: 'sent')
    .snapshots(),
builder: (context, snapshot) {
  // ... Error handling ...

  // Client-Side Sorting Implementation
  final docs = List<DocumentSnapshot>.from(snapshot.data!.docs);
  docs.sort((a, b) {
     final t1 = (a.data() as Map)['sentAt'] as Timestamp?;
     final t2 = (b.data() as Map)['sentAt'] as Timestamp?;
     if (t1 == null) return 1;
     if (t2 == null) return -1;
     return t2.compareTo(t1); // Descending
  });

  // Image Display Logic
  return CachedNetworkImage(
    imageUrl: BunnyCDNService().getAuthenticatedUrl(data['imageUrl'] as String),
    httpHeaders: const {'AccessKey': BunnyCDNService.accessKey},
    // ...
  );
}
```

---

## 4. File: `lib/screens/notifications/edit_notification_screen.dart`
**Purpose:** Edit Scheduled Notifications. Handles Keyboard Dismissal.

```dart
// Validation of Keyboard logic in Form Fields
TextFormField(
  controller: _titleController,
  // ...
  onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(), // KEY FIX
  validator: (v) => v!.isEmpty ? 'Required' : null,
),

// Date Picker Keyboard Dismissal
onPressed: () async {
  FocusScope.of(context).unfocus(); // KEY FIX
  final d = await showDatePicker(...);
  // ...
},

// Image Preview Logic
CachedNetworkImage(
  imageUrl: BunnyCDNService().getAuthenticatedUrl(_existingImageUrl!),
  httpHeaders: const {'AccessKey': BunnyCDNService.accessKey},
  fit: BoxFit.cover,
  // ...
)
```

---

## 5. File: `lib/screens/notifications/tabs/send_notification_tab.dart`
**Purpose:** Create New Notifications.

```dart
// Parent GestureDetector to catch clicks
return GestureDetector(
  onTap: () {
    FocusScope.of(context).unfocus();
  },
  child: SingleChildScrollView(
    // ...
    // Form Fields with onTapOutside
    TextFormField(
      controller: _titleController,
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
      // ...
    ),
  ),
);

// Date Picker
Future<void> _selectDate() async {
  FocusScope.of(context).unfocus(); // KEY FIX
  final DateTime? picked = await showDatePicker(...);
  // ...
}
```

---

## 6. File: `lib/screens/notifications/tabs/scheduled_notifications_tab.dart`
**Purpose:** View Scheduled Items.

```dart
// Image Display using Service
CachedNetworkImage(
  imageUrl: BunnyCDNService().getAuthenticatedUrl(imageUrl!),
  httpHeaders: const {
    'AccessKey': BunnyCDNService.accessKey,
  },
  // ...
)
```
