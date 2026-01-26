import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final ShapeBorder? shapeBorder;

  const ShimmerLoading.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
  }) : shapeBorder = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(3.0)));

  const ShimmerLoading.circular({
    super.key,
    required this.width,
    required this.height,
  }) : shapeBorder = const CircleBorder();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[300]!,
      highlightColor: isDark ? const Color(0xFF3D3D3D) : Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[300]!,
          shape: shapeBorder!,
        ),
      ),
    );
  }

}

class NotificationShimmerItem extends StatelessWidget {
  const NotificationShimmerItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(3.0),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLoading.circular(width: 48, height: 48),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading.rectangular(height: 14, width: 120),
                    SizedBox(height: 8),
                    ShimmerLoading.rectangular(height: 12),
                    SizedBox(height: 4),
                    ShimmerLoading.rectangular(height: 12, width: 200),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentShimmerItem extends StatelessWidget {
  const StudentShimmerItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(3.0),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              ShimmerLoading.circular(width: 48, height: 48),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShimmerLoading.rectangular(height: 14, width: 150),
                    SizedBox(height: 8),
                    ShimmerLoading.rectangular(height: 12, width: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final Widget itemBuilder;
  final EdgeInsetsGeometry padding;

  const ShimmerList({
    super.key,
    this.itemCount = 6,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return itemBuilder;
      },
    );
  }
}

class SimpleShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SimpleShimmerList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 80,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ShimmerLoading.rectangular(height: itemHeight),
        );
      },
    );
  }
}
class UploadShimmerItem extends StatelessWidget {
  const UploadShimmerItem({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        height: 106, // Matches real card height better
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(3.0),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  // Leading Thumbnail placeholder
                  ShimmerLoading.rectangular(width: 60, height: 34), 
                  SizedBox(width: 12),
                  // Content area
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerLoading.rectangular(height: 14, width: 180),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ShimmerLoading.rectangular(height: 10, width: 50),
                            ShimmerLoading.rectangular(height: 10, width: 80),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  // Action button placeholder
                  ShimmerLoading.circular(width: 24, height: 24),
                ],
              ),
              Spacer(),
              // Progress Bar placeholder
              ShimmerLoading.rectangular(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}


