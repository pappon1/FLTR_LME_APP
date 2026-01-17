import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GhostHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userId;

  const GhostHomeScreen({super.key, required this.userId, required this.userData});

  @override
  State<GhostHomeScreen> createState() => _GhostHomeScreenState();
}

class _GhostHomeScreenState extends State<GhostHomeScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _myCourses = [];

  @override
  void initState() {
    super.initState();
    _fetchUserContent();
  }

  Future<void> _fetchUserContent() async {
    try {
      // Fetch enrollments
      final enrollments = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: widget.userId)
          .get();

      final List<Map<String, dynamic>> loadedCourses = [];

      for (var doc in enrollments.docs) {
        final courseId = doc.data()['courseId'];
        // Fetch course details
        final courseDoc = await FirebaseFirestore.instance.collection('courses').doc(courseId).get();
        if (courseDoc.exists) {
          loadedCourses.add({
            'id': courseDoc.id,
            ...courseDoc.data()!,
            'progress': 0.0, // Dummy progress for ghost view
          });
        }
      }

      setState(() {
        _myCourses = loadedCourses;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force Light Mode for Ghost View to match User App typical look
    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor: Colors.grey[50], 
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Viewing as: ${widget.userData['name']}", style: GoogleFonts.outfit(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              Text("Ghost Mode Active 👻", style: GoogleFonts.inter(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            const CircleAvatar(
              backgroundColor: Colors.red,
              radius: 4,
            ),
            const SizedBox(width: 8),
            Center(child: Text("LIVE POPULATION ", style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10))),
            const SizedBox(width: 16),
          ],
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Simulation
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(colors: [Colors.blue, Colors.purple])
                      ),
                      child: Center(
                        child: Text("User's Home Banner", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text("My Enrolled Courses (${_myCourses.length})", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 16),
                    
                    if (_myCourses.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            const Icon(Icons.sentiment_dissatisfied, color: Colors.grey, size: 40),
                            const SizedBox(height: 10),
                            Text("This user has no active courses.", style: GoogleFonts.inter(color: Colors.grey)),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _myCourses.length,
                        itemBuilder: (context, index) {
                          final course = _myCourses[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(10),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 60, height: 60,
                                  color: Colors.grey[200],
                                  child: course['thumbnailUrl'] != null 
                                    ? CachedNetworkImage(imageUrl: course['thumbnailUrl'], fit: BoxFit.cover, errorWidget: (context, url, error) => const Icon(Icons.image))
                                    : const Icon(Icons.movie, color: Colors.grey),
                                ),
                              ),
                              title: Text(course['title'] ?? 'Untitled', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(value: 0.0, backgroundColor: Colors.grey[100], color: Colors.blue, minHeight: 4),
                                  const SizedBox(height: 4),
                                  Text("Start Learning", style: GoogleFonts.inter(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              trailing: const Icon(Icons.play_circle_fill, color: Colors.blue, size: 30),
                            ),
                          );
                        },
                      )
                  ],
                ),
              ),
      ),
    );
  }
}
