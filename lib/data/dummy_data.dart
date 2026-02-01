import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';

class DummyData {
  // 1. Mock Course List
  static final List<CourseModel> courses = [
    CourseModel(
      id: 'course_1',
      title: 'iPhone 15 Pro Max Masterclass',
      category: 'Hardware',
      price: 15000,
      discountPrice: 12000,
      description: 'Advanced chip-level repair expert course.',
      thumbnailUrl: 'https://picsum.photos/id/1/200/200',
      duration: '3 Months',
      difficulty: 'Advanced',
      enrolledStudents: 150,
      rating: 4.8,
      totalVideos: 45,
      isPublished: true,
    ),
    CourseModel(
      id: 'course_2',
      title: 'Android Software & Flashing',
      category: 'Software',
      price: 8000,
      discountPrice: 6500,
      description: 'Unlock and Flash any Android device.',
      thumbnailUrl: 'https://picsum.photos/id/2/200/200',
      duration: '2 Months',
      difficulty: 'Intermediate',
      enrolledStudents: 230,
      rating: 4.7,
      totalVideos: 30,
      isPublished: true,
    ),
    CourseModel(
      id: 'course_3',
      title: 'Micro-Soldering Basics',
      category: 'Hardware',
      price: 5000,
      discountPrice: 4500,
      description: 'Learn basics of soldering.',
      thumbnailUrl: 'https://picsum.photos/id/3/200/200',
      duration: '1 Month',
      difficulty: 'Beginner',
      enrolledStudents: 500,
      rating: 4.9,
      totalVideos: 20,
      isPublished: true,
    ),
  ];

  // 2. Mock User List (Simulating Firestore Document Snapshots)
  // Note: Since we can't easily create a real DocumentSnapshot, 
  // we'll return List<Map<String, dynamic>> or handle it in the screen.
  static final List<Map<String, dynamic>> users = [
    {
      'id': 'user_1',
      'name': 'Rahul Sharma',
      'email': 'rahul.sharma@gmail.com',
      'phone': '9876543210',
      'role': 'user',
    },
    {
      'id': 'user_2',
      'name': 'Amit Kumar',
      'email': 'amit.k@gmail.com',
      'phone': '9988776655',
      'role': 'user',
    },
    {
      'id': 'user_3',
      'name': 'Priya Singh',
      'email': 'priya.singh@gmail.com',
      'phone': '8877665544',
      'role': 'user',
    },
  ];
}
