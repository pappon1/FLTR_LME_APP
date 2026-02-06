class CourseUploadTask {
  final String id;
  final String label;
  double progress;
  String status;

  CourseUploadTask({
    required this.id,
    required this.label,
    this.progress = 0.0,
    this.status = 'pending',
  });

  factory CourseUploadTask.fromMap(Map<String, dynamic> map) {
    return CourseUploadTask(
      id: map['id'] ?? '',
      label: map['remotePath']?.toString().split('/').last ?? 'File',
      progress: (map['progress'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'pending',
    );
  }
}
