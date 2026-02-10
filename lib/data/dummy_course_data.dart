import '../models/course_model.dart';
import 'dart:async';

class DummyCourseData {
  static final CourseModel sampleCourse = CourseModel(
    id: 'dummy_101',
    title: 'Professional Smartphone Micro-Soldering',
    category: 'Hardware',
    price: 15000,
    discountPrice: 12499,
    description:
        'This is a comprehensive masterclass on micro-soldering. Learn how to fix dead motherboards, replace ICs, and reball CPUs like a professional engineer. We cover everything from basic soldering iron tips to advanced hot air station techniques.\n\nKey Learings:\n• Component Identification\n• IC Reballing\n• Jumper Wire Techniques\n• Schematic Analysis',
    thumbnailUrl: 'https://picsum.photos/id/1/800/450',
    duration: '4 Months',
    difficulty: 'Advanced',
    enrolledStudents: 3240,
    rating: 4.9,
    totalVideos: 145,
    isPublished: true,
    hasCertificate: true,
    websiteUrl:
        'https://localmobileengineer.com/course/dummy-smartphone-repair',
    createdAt: DateTime.now(),
    highlights: [
      'Hands-on Practical Training',
      'Life-time Support Access',
      'Advanced Schematic Diagrams',
      'Certification of Completion',
    ],
    faqs: [
      {
        'question': 'Is this course suitable for beginners?',
        'answer':
            'While we start from basics, having some knowledge of electronics will help you progress faster.',
      },
      {
        'question': 'Will I get tools with the course?',
        'answer':
            'No, tools are not included, but we provide a list of recommended tools and where to buy them.',
      },
    ],
    contents: [
      {
        'name': 'Professional Mobile Repairing Masterclas',
        'type': 'folder',
        'contents': [
          // 1. Nested Folder (Copy)
          {
            'name': 'Professional Mobile Repairing Masterclas (Sub)',
            'type': 'folder',
            'contents': [],
          },
          // 2. Image (Copy)
          {
            'name': 'Schematic Diagram for Advanced Chip Lvl.',
            'type': 'image',
            'path': 'https://picsum.photos/id/2/800/600',
            'thumbnail': 'https://picsum.photos/id/2/200/200',
          },
          // 3. PDF (Copy)
          {
            'name': 'Complete Mobile Repairing Guide Book PDF',
            'type': 'pdf',
            'path':
                'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
          },
          // 4. Video (Copy)
          {
            'name': 'Introduction to Advanced Tools & Gadgets',
            'type': 'video',
            'duration': 600,
            'path':
                'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            'thumbnail':
                'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg',
          },
        ],
      },
      {
        'name': 'Schematic Diagram for Advanced Chip Lvl.',
        'type': 'image',
        'path': 'https://picsum.photos/id/2/800/600',
        'thumbnail': 'https://picsum.photos/id/2/200/200',
      },
      {
        'name': 'Complete Mobile Repairing Guide Book PDF',
        'type': 'pdf',
        'url':
            'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      },
      {
        'name': 'Introduction to Advanced Tools & Gadgets',
        'type': 'video',
        'duration': 600,
        'path':
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        'thumbnail':
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg',
      },
    ],
  );

  /// Mock stream for UI testing - Mimics Firestore/Network behavior
  static Stream<CourseModel> fetchCourseDetails() async* {
    // Simulate a slight network delay
    await Future.delayed(const Duration(milliseconds: 600));
    yield sampleCourse;
  }
}
