import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const UserProfileScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Parsing Data (Safe defaults)
    final String name = userData['userName'] ?? 'Unknown User';
    final String email = userData['userEmail'] ?? 'No Email';
    final String phone = userData['userPhone'] ?? 'No WhatsApp No';
    final String imageUrl = userData['userImage'] ?? '';
    final String device = userData['deviceModel'] ?? 'Unknown Device';
    final Timestamp? joinedAt = userData['timestamp'];
    final List<dynamic> courses = userData['purchasedCourses'] ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade400],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                        child: imageUrl.isEmpty ? const FaIcon(FontAwesomeIcons.user, size: 40, color: Colors.grey) : null,
                      ),
                      const SizedBox(height: 16),
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
                      Text(email, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  _buildSectionTitle('User Details'),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _buildInfoTile(Icons.phone, 'WhatsApp No', phone),
                         const Divider(height: 1),
                        _buildInfoTile(Icons.smartphone, 'Device', device),
                         const Divider(height: 1),
                        _buildInfoTile(Icons.calendar_today, 'Joined', joinedAt != null ? DateFormat('MMM d, yyyy').format(joinedAt.toDate()) : 'N/A'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Courses Section
                  _buildSectionTitle('Purchased Courses (${courses.length})'),
                  if (courses.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                      child: Column(children: [FaIcon(FontAwesomeIcons.boxOpen, size: 40, color: Colors.grey[400]), const SizedBox(height: 10), const Text('No courses purchased yet')])
                    )
                  else
                    ...courses.map((course) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const FaIcon(FontAwesomeIcons.video, color: Colors.orange, size: 16),
                        ),
                        title: Text(course['title'] ?? 'Course Title'),
                        subtitle: Text('Price: ₹${course['price'] ?? 0}'),
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }
}
