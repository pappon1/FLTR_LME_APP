import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const UserProfileScreen({super.key, required this.userData});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Parsing Data
    final String name = widget.userData['userName'] ?? 'Momi Chanda';
    final String email = widget.userData['userEmail'] ?? 'momichanda100@gmail.com';
    final String phone = widget.userData['userPhone'] ?? 'Not Provided';
    final String imageUrl = widget.userData['userImage'] ?? '';
    final String device = widget.userData['deviceModel'] ?? 'Samsung S23 Ultra';
    final Timestamp? joinedAt = widget.userData['timestamp'];
    final List<dynamic> courses = widget.userData['purchasedCourses'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF111422), // Dark Navy Background
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 380,
              pinned: true,
              backgroundColor: const Color(0xFF526BF4), // Fallback
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient Background
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF526BF4),
                            Color(0xFF6dd5ed),
                            Color(0xFF111422),
                          ],
                          stops: [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                    
                    // Profile content
                    SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            'USER PROFILE',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 2.0,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // Profile Image with Glow
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Colors.cyanAccent, Colors.blueAccent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF111422),
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: const Color(0xFF1F2940),
                                backgroundImage: imageUrl.isNotEmpty 
                                    ? CachedNetworkImageProvider(imageUrl) 
                                    : null,
                                child: imageUrl.isEmpty 
                                    ? const FaIcon(FontAwesomeIcons.user, size: 40, color: Colors.white54)
                                    : null,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Name
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                              color: Colors.white,
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Active Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'ACTIVE ACCOUNT',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    letterSpacing: 1.0,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 50), // Added padding to lift content above TabBar
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFF111422),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF526BF4),
                    indicatorWeight: 3,
                    indicatorPadding: const EdgeInsets.symmetric(horizontal: 20),
                    labelColor: const Color(0xFF526BF4),
                    unselectedLabelColor: Colors.grey,
                    labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
                    tabs: const [
                       Tab(text: 'User Info'),
                       Tab(text: 'Courses'),
                       Tab(text: 'Device Info'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildUserInfoTab(name, email, phone, joinedAt, courses.length),
            _buildCoursesTab(courses),
            _buildDeviceInfoTab(), // Using dummy data for now
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoTab(String name, String email, String phone, Timestamp? joinedAt, int courseCount) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'PERSONAL DETAILS',
          style: GoogleFonts.outfit(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildDetailCard(
          icon: FontAwesomeIcons.user,
          iconColor: Colors.blue,
          title: 'Full Name',
          value: name,
        ),
        const SizedBox(height: 12),
        
        _buildDetailCard(
          icon: FontAwesomeIcons.envelope,
          iconColor: Colors.orange,
          title: 'Email Address',
          value: email,
        ),
        const SizedBox(height: 12),
        
        _buildDetailCard(
          icon: FontAwesomeIcons.whatsapp,
          iconColor: Colors.green,
          title: 'WhatsApp No',
          value: phone,
        ),
        
        const SizedBox(height: 30),
        
        Text(
          'ACCOUNT STATISTICS',
          style: GoogleFonts.outfit(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: FontAwesomeIcons.calendar,
                iconColor: Colors.purple,
                title: 'Joined On',
                value: joinedAt != null ? DateFormat('d MMM yy').format(joinedAt.toDate()) : 'N/A',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: FontAwesomeIcons.bookOpen,
                iconColor: Colors.teal,
                title: 'Courses',
                value: '$courseCount',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCoursesTab(List<dynamic> courses) {
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No Active Enrollments',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 50), // Adjust for center alignment visually
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF252A40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.play,
                    color: Color(0xFF526BF4),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title'] ?? 'Course Title',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enrolled',
                      style: GoogleFonts.outfit(
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceInfoTab() {
    // Mock Data for Timeline
    final List<Map<String, String>> loginHistory = [
      {
        'device': 'Samsung Galaxy S23 Ultra',
        'location': 'New Delhi, India',
        'ip': '192.168.1.45',
        'time': 'Jan 31, 2026 • 04:22 PM',
        'color': '0xFF526BF4'
      },
      {
        'device': 'Chrome Browser (Windows)',
        'location': 'New Delhi, India',
        'ip': '192.168.1.45',
        'time': 'Jan 31, 2026 • 12:37 PM',
        'color': '0xFF526BF4'
      },
      {
        'device': 'Samsung Galaxy S23 Ultra',
        'location': 'Mumbai, India',
        'ip': '10.0.0.12',
        'time': 'Jan 29, 2026 • 04:37 PM',
        'color': '0xFF526BF4'
      },
      {
        'device': 'OnePlus 11R',
        'location': 'Pune, India',
        'ip': '172.16.0.5',
        'time': 'Jan 26, 2026 • 04:37 PM',
        'color': '0xFF526BF4'
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'LOGIN TIMELINE',
          style: GoogleFonts.outfit(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        
        Stack(
          children: [
            // Vertical Line
            Positioned(
              left: 7,
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            
            // Items
            Column(
              children: loginHistory.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dot
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF526BF4),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF111422), width: 3),
                          boxShadow: [
                             BoxShadow(color: const Color(0xFF526BF4).withValues(alpha: 0.5), blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['device']!,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item['location']} • ${item['ip']}',
                              style: GoogleFonts.outfit(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                             const SizedBox(height: 4),
                            Text(
                              item['time']!,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF526BF4),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Logout Action
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.copy, color: Colors.grey, size: 18),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
