import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class ImageViewerScreen extends StatefulWidget {
  final String filePath;
  final bool isNetwork;
  final String? title;

  const ImageViewerScreen({
    super.key,
    required this.filePath,
    this.isNetwork = false,
    this.title,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  final PhotoViewScaleStateController _scaleStateController = PhotoViewScaleStateController();
  int _retryKey = 0;

  @override
  void dispose() {
    _scaleStateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Image Viewer Layer (Starts below header)
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60),
            child: PhotoView.customChild(
              scaleStateController: _scaleStateController,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4.0,
              initialScale: PhotoViewComputedScale.contained,
              basePosition: Alignment.center, // Ensures center alignment in the available space
              heroAttributes: PhotoViewHeroAttributes(tag: widget.filePath),
              child: widget.isNetwork
                  ? CachedNetworkImage(
                      key: ValueKey("network_$_retryKey"),
                      imageUrl: widget.filePath,
                      fit: BoxFit.contain,
                      memCacheWidth: 2048, // Memory optimization
                      // maxWidthDiskCache: 2048, // Optional: Cache on disk resized
                      placeholder: (context, url) => _buildShimmerLoader(),
                      errorWidget: (context, url, error) => _buildErrorWidget(),
                    )
                  : Image.file(
                      File(widget.filePath),
                      key: ValueKey("file_$_retryKey"),
                      fit: BoxFit.contain,
                      cacheWidth: 2048, // Memory optimization
                      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
                    ),
            ),
          ),

          // Top Control Bar (Fixed & Opaque)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top + 60,
              color: Colors.black,
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    _buildSimpleButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    if (widget.title != null)
                      Expanded(
                        child: Text(
                          widget.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),


        ],
      ),
    );
  }

  Widget _buildSimpleButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 24),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[800]!,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.white24, size: 80),
          const SizedBox(height: 16),
          const Text(
            "Failed to load image",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                label: const Text("Back", style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _retryKey++;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          )
        ],
      ),
    );
  }
}

