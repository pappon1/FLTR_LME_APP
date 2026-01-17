import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../utils/app_theme.dart';
import '../screens/students/student_detail_screen.dart';
import '../services/security/student_deletion_service.dart';

class StudentListItem extends StatelessWidget {
  final StudentModel student;

  const StudentListItem({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: CachedNetworkImageProvider(student.avatarUrl),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: student.isActive ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).cardColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          student.name,
          style: AppTheme.bodyMedium(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.envelope,
                  size: 10,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    student.email,
                    style: AppTheme.bodySmall(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.graduationCap,
                  size: 10,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  '${student.enrolledCourses} courses',
                  style: AppTheme.bodySmall(context),
                ),
                const SizedBox(width: 12),
                const FaIcon(
                  FontAwesomeIcons.calendar,
                  size: 10,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Joined ${DateFormat('MMM d, y').format(student.joinedDate)}',
                    style: AppTheme.bodySmall(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const FaIcon(FontAwesomeIcons.trashCan, size: 16, color: Colors.red),
          ),
          onPressed: () {
            StudentDeletionService.initiateDeletion(context, student);
          },
          tooltip: 'Delete Student',
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)));
        },
      ),
    );
  }
}
