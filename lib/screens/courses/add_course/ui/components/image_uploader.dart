import 'dart:io';
import 'package:flutter/material.dart';
import '../ui_constants.dart';

class ImageUploader extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final double aspectRatio;

  const ImageUploader({
    super.key,
    this.image,
    required this.onTap,
    required this.label,
    required this.icon,
    this.aspectRatio = 16 / 9,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(UIConstants.globalRadius),
            border: Border.all(
              color: Theme.of(
                context,
              ).dividerColor.withValues(alpha: UIConstants.borderOpacity),
              style: BorderStyle.solid,
            ),
            image: image != null
                ? DecorationImage(image: FileImage(image!), fit: BoxFit.contain)
                : null,
          ),
          child: image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.grey, size: 30),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}
