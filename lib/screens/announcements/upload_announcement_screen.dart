import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/bunny_cdn_service.dart';
import '../../utils/app_theme.dart';
import '../../services/config_service.dart';
import '../../models/announcement_model.dart';

class UploadAnnouncementScreen extends StatefulWidget {
  final AnnouncementModel? announcement;
  const UploadAnnouncementScreen({super.key, this.announcement});

  @override
  State<UploadAnnouncementScreen> createState() =>
      _UploadAnnouncementScreenState();
}

class _UploadAnnouncementScreenState extends State<UploadAnnouncementScreen> {
  static const double targetAspectRatio = 1280 / 720;
  static const double tolerance = 0.05;

  File? _selectedImage;
  String? _errorMessage;
  String? _successMessage;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  String? _existingImageUrl;
  String _selectedExpiryLabel = "No Expiry";
  DateTime? _expiryDate;

  final List<String> _expiryOptions = [
    "No Expiry",
    "1 Month",
    "2 Months",
    "3 Months",
    "4 Months",
    "1 Year",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.announcement != null) {
      _existingImageUrl = widget.announcement!.imageUrl;
      _expiryDate = widget.announcement!.expiryDate;
      // Try to match existing expiry to label (approximate or just keep as custom if needed)
    }
  }

  void _calculateExpiry(String label) {
    final now = DateTime.now();
    setState(() {
      _selectedExpiryLabel = label;
      switch (label) {
        case "1 Month":
          _expiryDate = DateTime(now.year, now.month + 1, now.day);
          break;
        case "2 Months":
          _expiryDate = DateTime(now.year, now.month + 2, now.day);
          break;
        case "3 Months":
          _expiryDate = DateTime(now.year, now.month + 3, now.day);
          break;
        case "4 Months":
          _expiryDate = DateTime(now.year, now.month + 4, now.day);
          break;
        case "1 Year":
          _expiryDate = DateTime(now.year + 1, now.month, now.day);
          break;
        default:
          _expiryDate = null;
      }
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final file = File(image.path);
      final decodedImage = await decodeImageFromList(await file.readAsBytes());
      final aspectRatio = decodedImage.width / decodedImage.height;
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
          _errorMessage = "⚠️ Aspect ratio must be 16:9 (1280x720px)";
        });
      }
    }
  }

  Future<void> _saveAnnouncement() async {
    if (_selectedImage == null && _existingImageUrl == null) {
      setState(() => _errorMessage = "⚠️ Please select an image");
      return;
    }

    setState(() => _isUploading = true);

    try {
      String finalImageUrl = _existingImageUrl ?? '';

      if (_selectedImage != null) {
        finalImageUrl = await BunnyCDNService().uploadImage(
          filePath: _selectedImage!.path,
          folder: 'announcements',
          onProgress: (sent, total) =>
              setState(() => _uploadProgress = sent / total),
        );
      }

      final data = AnnouncementModel(
        id: widget.announcement?.id ?? '',
        title: '', // Removed from UI
        message: '', // Removed from UI
        imageUrl: finalImageUrl,
        actionType: AnnouncementActionType.none, // Removed from UI
        actionValue: '', // Removed from UI
        createdAt: widget.announcement?.createdAt ?? DateTime.now(),
        expiryDate: _expiryDate,
        isActive: widget.announcement?.isActive ?? true,
        createdBy: 'admin',
      ).toMap();

      if (widget.announcement == null) {
        await FirebaseFirestore.instance.collection('announcements').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('announcements')
            .doc(widget.announcement!.id)
            .update(data);
      }

      setState(() {
        _successMessage = "✅ Success!";
        _isUploading = false;
      });

      Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context));
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Box
            Center(
              child: GestureDetector(
                onTap: _isUploading ? null : _pickImage,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _isUploading
                        ? Center(
                            child: CircularProgressIndicator(value: _uploadProgress))
                        : _buildPosterPreview(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Expiry Dropdown
            _buildLabel("Valid Until (Expiry)"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedExpiryLabel,
                  isExpanded: true,
                  items: _expiryOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (v) => _calculateExpiry(v!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_expiryDate != null)
              Text(
                "Expires on: ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}",
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
              ),

            const SizedBox(height: 40),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_successMessage!, style: const TextStyle(color: Colors.green)),
              ),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _saveAnnouncement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  elevation: 0,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isUploading)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.3)),
                          ),
                        ),
                      ),
                    Text(
                      _isUploading
                          ? "Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%"
                          : "Publish Announcement",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterPreview() {
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.file(_selectedImage!, fit: BoxFit.cover),
      );
    } else if (_existingImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CachedNetworkImage(
          imageUrl: BunnyCDNService().getAuthenticatedUrl(_existingImageUrl!),
          httpHeaders: {
            'AccessKey': BunnyCDNService.apiKey,
          },
          fit: BoxFit.cover,
        ),
      );
    } else {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.blue),
          SizedBox(height: 12),
          Text(
            "Select 16:9 Banner Image",
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      );
    }
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}
