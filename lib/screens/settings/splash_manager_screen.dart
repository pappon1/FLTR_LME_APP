import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../widgets/shimmer_loading.dart';

class SplashManagerScreen extends StatefulWidget {
  const SplashManagerScreen({super.key});

  @override
  State<SplashManagerScreen> createState() => _SplashManagerScreenState();
}

class _SplashManagerScreenState extends State<SplashManagerScreen> {
  String? _currentSplashUrl;
  bool _isActive = true;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  Future<void> _fetchConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('splash_config').get();
      if (doc.exists) {
        setState(() {
          _currentSplashUrl = doc.data()?['imageUrl'];
          _isActive = doc.data()?['isActive'] ?? true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      final File imageFile = File(pickedFile.path);

      try {
        // Upload to Storage
        final ref = FirebaseStorage.instance.ref().child('app_assets/splash_banner_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(imageFile);
        final url = await ref.getDownloadURL();

        // Update Firestore
        await FirebaseFirestore.instance.collection('settings').doc('splash_config').set({
          'imageUrl': url,
          'isActive': _isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        setState(() {
          _currentSplashUrl = url;
          _isUploading = false;
        });
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New Splash Screen Uploaded!")));

      } catch (e) {
        setState(() => _isUploading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _toggleActive(bool val) async {
    setState(() => _isActive = val);
    await FirebaseFirestore.instance.collection('settings').doc('splash_config').set({
      'isActive': val
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text("Splash Screen Manager", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Preview Card
            Container(
              height: 400,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))],
                image: _currentSplashUrl != null 
                  ? DecorationImage(image: NetworkImage(_currentSplashUrl!), fit: BoxFit.cover, opacity: _isActive ? 1.0 : 0.4)
                  : null,
              ),
              child: _isLoading 
                ? const ShimmerLoading.rectangular(height: 400)
                : _currentSplashUrl == null 
                  ? Center(child: Text("No Custom Splash Set", style: GoogleFonts.inter(color: Colors.white54)))
                  : Stack(
                      children: [
                        if (!_isActive)
                           Center(child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             color: Colors.black54,
                             child: Text("DISABLED", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 2)),
                           )),
                         // Fake App UI Overlay to show how it looks
                         Positioned(
                           bottom: 40, left: 0, right: 0,
                           child: Column(
                             children: [
                               const CircularProgressIndicator(color: Colors.white),
                               const SizedBox(height: 16),
                               Text("Loading...", style: GoogleFonts.inter(color: Colors.white70)),
                             ],
                           ),
                         )
                      ],
                    ),
            ),
            
            const SizedBox(height: 32),
            
            // Controls
            SwitchListTile(
              title: Text("Enable Custom Splash", style: GoogleFonts.inter(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text("If disabled, default app logo will be shown", style: GoogleFonts.inter(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              value: _isActive,
              onChanged: _toggleActive,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadImage,
                icon: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_file),
                label: Text(_isUploading ? "Uploading..." : "Upload New Image"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            Text(
              "Recommended Size: 1080x1920 (Portrait). Supports JPG/PNG.",
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
