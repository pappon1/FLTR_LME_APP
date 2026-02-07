import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../../utils/app_theme.dart';
import '../../backend_service/models/course_upload_task.dart';

class CourseUploadingOverlay extends StatelessWidget {
  final double totalProgress;
  final List<CourseUploadTask> uploadTasks;
  final String? preparationMessage;
  final double? preparationProgress;

  const CourseUploadingOverlay({
    super.key,
    required this.totalProgress,
    required this.uploadTasks,
    this.preparationMessage,
    this.preparationProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      width: double.infinity,
      height: double.infinity,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Lottie.network(
                'https://assets9.lottiefiles.com/packages/lf20_yzn8uNCX7t.json',
                width: 150,
                height: 150,
                animate: true,
                repeat: true,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.cloud_upload_outlined,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Uploading Course Materials',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                preparationMessage?.isNotEmpty == true
                    ? preparationMessage!
                    : 'Upload will continue even if you switch apps',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 40),

              // Overall Progress
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          uploadTasks.isEmpty
                              ? 'Preparing Materials...'
                              : 'Overall Progress',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${((uploadTasks.isEmpty ? (preparationProgress ?? 0) : totalProgress) * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3.0),
                      child: LinearProgressIndicator(
                        value: uploadTasks.isEmpty
                            ? (preparationProgress ?? 0.0)
                            : totalProgress,
                        minHeight: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'BATCH DETAILS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Individual Task List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: uploadTasks.length,
                  itemBuilder: (context, index) {
                    final task = uploadTasks[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                task.progress == 1.0
                                    ? Icons.check_circle
                                    : Icons.upload_file,
                                color: task.progress == 1.0
                                    ? Colors.green
                                    : Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  task.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                '${(task.progress * 100).toInt()}%',
                                style: TextStyle(
                                  color: task.progress == 1.0
                                      ? Colors.green
                                      : Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (task.progress < 1.0) ...[
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: task.progress,
                              minHeight: 4,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                task.progress == 1.0
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Warning Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please do not close or kill the app until the upload is complete.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
