import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../utils/app_theme.dart';
import '../services/config_service.dart';
import '../screens/user_profile/user_profile_screen.dart';
import '../services/security/student_deletion_service.dart';

class StudentListItem extends StatelessWidget {
  final StudentModel student;

  const StudentListItem({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: student.avatarUrl,
                httpHeaders: {'Referer': ConfigService.allowedReferer},
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                memCacheWidth: 150, // Optimize memory: Decode small version
                memCacheHeight: 150,
                placeholder: (context, url) =>
                    Container(color: Colors.grey.withValues(alpha: 0.1)),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
              ),
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
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
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Contact Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: FaIcon(
                    FontAwesomeIcons.envelope,
                    size: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black54,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    student.email,
                    style: AppTheme.bodySmall(context).copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            if (student.phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: FaIcon(
                      FontAwesomeIcons.whatsapp,
                      size: 11,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.greenAccent
                          : Colors.green[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      student.phone.replaceAll(' ', ''),
                      style: AppTheme.bodySmall(context).copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Details Row (Wrapped)
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                // Courses Count
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.graduationCap,
                      size: 11,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white54
                          : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${student.enrolledCourses} courses',
                      style: AppTheme.bodySmall(context).copyWith(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
                // Joined Date
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.calendar,
                      size: 11,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white54
                          : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Joined ${DateFormat('MMM d, y').format(student.joinedDate)}',
                      style: AppTheme.bodySmall(context).copyWith(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54
                            : Colors.black54,
                      ),
                    ),
                  ],
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
              borderRadius: BorderRadius.circular(3.0),
            ),
            child: const FaIcon(
              FontAwesomeIcons.trashCan,
              size: 16,
              color: Colors.red,
            ),
          ),
          onPressed: () {
            StudentDeletionService.initiateDeletion(context, student);
          },
          tooltip: 'Delete Student',
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(student: student),
            ),
          );
        },
      ),
    );
  }
}
