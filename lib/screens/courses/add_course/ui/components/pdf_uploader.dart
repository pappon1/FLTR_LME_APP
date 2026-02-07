import 'dart:io';
import 'package:flutter/material.dart';
import '../ui_constants.dart';

class PdfUploader extends StatelessWidget {
  final File? file;
  final VoidCallback onTap;
  final String label;
  final VoidCallback? onRemove;
  final VoidCallback? onView;

  const PdfUploader({
    super.key,
    this.file,
    required this.onTap,
    required this.label,
    this.onRemove,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100, // Fixed height for PDF box
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(UIConstants.globalRadius),
          border: Border.all(
            color: Theme.of(
              context,
            ).dividerColor.withValues(alpha: UIConstants.borderOpacity),
            style: BorderStyle.solid,
          ),
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.grey,
                    size: 30,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            file!.path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '(Tap to Change)',
                          style: TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 18,
                        ),
                        onPressed: onRemove,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  if (onView != null)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: IconButton(
                        icon: const Icon(
                          Icons.visibility,
                          color: Colors.blue,
                          size: 18,
                        ),
                        onPressed: onView,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'View PDF details',
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
