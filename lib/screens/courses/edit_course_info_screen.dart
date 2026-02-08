import 'package:flutter/material.dart';
import '../../models/course_model.dart';
import 'add_course_screen.dart';

class EditCourseInfoScreen extends StatelessWidget {
  final CourseModel course;
  const EditCourseInfoScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return AddCourseScreen(course: course);
  }
}
