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
  }) : shapeBorder = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)));

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
          borderRadius: BorderRadius.circular(12),
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
