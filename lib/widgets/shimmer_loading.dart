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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF3A3A3A) : Colors.grey[300]!;
    final highlightColor = isDark ? const Color(0xFF5A5A5A) : Colors.grey[100]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1500),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          title: const Align(
            alignment: Alignment.centerLeft,
            child: _SkeletonBox(height: 16, width: 140),
          ),
          subtitle: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8), // Gap between title and subtitle
              // Email Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(height: 11, width: 11, borderRadius: 3),
                  SizedBox(width: 8),
                  Expanded(
                    child: _SkeletonBox(height: 12, width: double.infinity),
                  ),
                ],
              ),
              SizedBox(height: 6),
               // WhatsApp Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _SkeletonBox(height: 11, width: 11, borderRadius: 3),
                  SizedBox(width: 8),
                  Expanded(
                    child: _SkeletonBox(height: 12, width: 100),
                  ),
                ],
              ),
              SizedBox(height: 10),
              // Details Row (Wrapped)
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  // Courses Count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SkeletonBox(height: 11, width: 11, borderRadius: 3),
                      SizedBox(width: 6),
                      _SkeletonBox(height: 10, width: 50),
                    ],
                  ),
                  // Joined Date
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SkeletonBox(height: 11, width: 11, borderRadius: 3),
                      SizedBox(width: 6),
                      _SkeletonBox(height: 10, width: 70),
                    ],
                  ),
                ],
              ),
            ],
          ),
          trailing: const _SkeletonBox(height: 32, width: 32, borderRadius: 4),
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.height, 
    required this.width, 
    this.borderRadius = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
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
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
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
