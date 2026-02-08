import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/bunny_cdn_service.dart';
import '../../utils/app_theme.dart';

class UploadAnnouncementScreen extends StatefulWidget {
  const UploadAnnouncementScreen({super.key});

  @override
  State<UploadAnnouncementScreen> createState() =>
      _UploadAnnouncementScreenState();
}

class _UploadAnnouncementScreenState extends State<UploadAnnouncementScreen> {
  // Constants
  static const double targetAspectRatio = 1280 / 720;
  static const double tolerance = 0.05;

  File? _selectedImage;
  String? _errorMessage;
  String? _successMessage;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Existing Announcement (For Preview/Delete)
  String? _existingImageUrl;
  String? _existingId;

  @override
  void initState() {
    super.initState();
    _fetchExistingAnnouncement();
  }

  Future<void> _fetchExistingAnnouncement() async {
    // Assuming single active announcement config for now or getting the latest one.
    // As per requirement, we want "Announcement bhejne ke liye system".
    // For now, let's fetch the most recent one.
    final snapshot = await FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      setState(() {
        _existingId = snapshot.docs.first.id;
        _existingImageUrl = data['imageUrl'];
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Validate Aspect Ratio
      final file = File(image.path);
      final decodedImage = await decodeImageFromList(await file.readAsBytes());

      final width = decodedImage.width;
      final height = decodedImage.height;
      final aspectRatio = width / height;

      final diff = (aspectRatio - targetAspectRatio).abs() / targetAspectRatio;

      if (diff <= tolerance) {
        setState(() {
          _selectedImage = file;
          _errorMessage = null;
          _successMessage = null;
        });
      } else {
        setState(() {
          _selectedImage = null;
          _errorMessage =
              "⚠️ Invalid poster size! Required aspect ratio: 16:9 (e.g., 1280x720px)";
        });
      }
    }
  }

  Future<void> _uploadPoster() async {
    if (_selectedImage == null) return;

    setState(() => _isUploading = true);

    try {
      // 1. Upload to BunnyCDN
      final imageUrl = await BunnyCDNService().uploadImage(
        filePath: _selectedImage!.path,
        folder: 'announcements',
        onProgress: (sent, total) =>
            setState(() => _uploadProgress = sent / total),
      );

      // 2. Save to Firestore
      final data = {
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'admin', // Ideally current user ID
        'isActive': true,
      };

      await FirebaseFirestore.instance.collection('announcements').add(data);

      setState(() {
        _successMessage = "✅ Poster uploaded successfully!";
        _selectedImage = null;
        _isUploading = false;
        _errorMessage = null;
      });

      await _fetchExistingAnnouncement(); // Refresh preview
    } catch (e) {
      setState(() {
        _errorMessage = "Error uploading: $e";
        _isUploading = false;
      });
    }
  }

  Future<void> _deleteAnnouncement() async {
    if (_existingId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement?'),
        content: const Text(
          'This will remove the current active poster. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(_existingId)
          .delete();
      setState(() {
        _existingId = null;
        _existingImageUrl = null;

        _successMessage = "Announcement removed.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Upload Announcement'),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Header Text
            Text(
              "Upload Poster",
              style: AppTheme.heading2(context),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Info Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3.0),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Text(
                "Poster Size: 1280x720px (16:9 aspect ratio)",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 32),

            // Upload Area (Card)
            GestureDetector(
              onTap: _isUploading ? null : _pickImage,
              child: Container(
                width: 320,
                height: 180, // 16:9
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(3.0),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isUploading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(value: _uploadProgress),
                          const SizedBox(height: 16),
                          Text(
                            '${(_uploadProgress * 100).toInt()}%',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          // Main Image Display (New or Existing)
                          if (_selectedImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3.0),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            )
                          else if (_existingImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3.0),
                              child: CachedNetworkImage(
                                imageUrl: BunnyCDNService().getAuthenticatedUrl(
                                  _existingImageUrl!,
                                ),
                                httpHeaders: const {
                                  'AccessKey': BunnyCDNService.apiKey,
                                },
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (c, u) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (c, u, e) => const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const FaIcon(
                                    FontAwesomeIcons.image,
                                    size: 48,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Tap to select poster",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Delete Button (Only for Existing Image)
                          if (_existingImageUrl != null &&
                              _selectedImage == null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  // Prevent tap from triggering the parent image picker
                                  _deleteAnnouncement();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),

                          // Cancel Selection Button (For New Image)
                          if (_selectedImage != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Messages
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3.0),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            if (_successMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3.0),
                ),
                child: Text(
                  _successMessage!,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Upload Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_selectedImage != null && !_isUploading)
                    ? _uploadPoster
                    : null,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? "Uploading..." : "Upload Poster"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[500],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
