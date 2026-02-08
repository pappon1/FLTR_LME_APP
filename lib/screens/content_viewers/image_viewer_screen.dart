import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final PhotoViewScaleStateController _scaleStateController =
      PhotoViewScaleStateController();
  int _retryKey = 0;

  @override
  void dispose() {
    _scaleStateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final iconColor = Theme.of(context).iconTheme.color ?? Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: Stack(
          children: [
            // Image Viewer Layer (Starts below header)
            Center(
              child: PhotoView.customChild(
                scaleStateController: _scaleStateController,
                backgroundDecoration: BoxDecoration(color: backgroundColor),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4.0,
                initialScale: PhotoViewComputedScale.contained,
                basePosition: Alignment.center,
                heroAttributes: PhotoViewHeroAttributes(tag: widget.filePath),
                child: widget.isNetwork
                    ? CachedNetworkImage(
                        key: ValueKey("network_$_retryKey"),
                        imageUrl: widget.filePath,
                        fit: BoxFit.contain,
                        memCacheWidth: 2048,
                        placeholder: (context, url) =>
                            _buildShimmerLoader(isDark),
                        errorWidget: (context, url, error) =>
                            _buildErrorWidget(textColor, iconColor),
                      )
                    : Image.file(
                        File(widget.filePath),
                        key: ValueKey("file_$_retryKey"),
                        fit: BoxFit.contain,
                        cacheWidth: 2048,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildErrorWidget(textColor, iconColor),
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
                color: backgroundColor, // Matches theme background
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      _buildSimpleButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                        color: iconColor,
                      ),
                      const SizedBox(width: 16),
                      if (widget.title != null)
                        Expanded(
                          child: Text(
                            widget.title!,
                            style: TextStyle(
                              color: textColor,
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
      ),
    );
  }

  Widget _buildSimpleButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 24),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildShimmerLoader(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[900]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: isDark ? Colors.black : Colors.white,
      ),
    );
  }

  Widget _buildErrorWidget(Color textColor, Color iconColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: iconColor.withValues(alpha: 0.5),
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            "Failed to load image",
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back,
                  color: textColor.withValues(alpha: 0.7),
                ),
                label: Text(
                  "Back",
                  style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
