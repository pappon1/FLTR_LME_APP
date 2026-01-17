import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/admin_notification_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/popular_courses_carousel.dart';

import '../notifications/notification_manager_screen.dart';
import '../students/students_tab.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/bunny_cdn_service.dart';
import '../announcements/upload_announcement_screen.dart';
import '../revenue/revenue_detail_screen.dart';
import '../contact/contact_links_screen.dart';
import '../../widgets/razorpay_dashboard_card.dart';
import '../../widgets/developer_access_card.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    _checkDraftStatus();
  }

  Future<void> _checkDraftStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('draft_title');
    final desc = prefs.getString('draft_description');
    final image = prefs.getString('draft_image_path');
    
    // If any significant field has data, we consider it a draft
    bool hasData = (title != null && title.isNotEmpty) || 
                   (desc != null && desc.isNotEmpty) || 
                   (image != null && image.isNotEmpty);
    
    if (mounted && hasData != _hasDraft) {
      setState(() {
        _hasDraft = hasData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: AppTheme.heading2(context),
            ),
            Text(
              DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
              style: AppTheme.bodySmall(context),
            ),
          ],
        ),
        actions: [
          Consumer<AdminNotificationProvider>(
            builder: (context, notifProvider, _) {
              final hasUnread = notifProvider.totalUnread > 0;
              final shouldAnimate = _hasDraft; 
              
              // Badge Widget
              Widget? badgeWidget;
              if (hasUnread) {
                badgeWidget = Positioned(
                  top: -2, right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(child: Text('${notifProvider.totalUnread}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                  )
                );
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: SizedBox(
                    width: 32, height: 32, 
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Icon Layer
                        shouldAnimate
                          ? Animate(onPlay: (c) => c.repeat()).custom(
                              duration: 800.ms, 
                              builder: (context, value, child) {
                                final isPhase1 = value < 0.5;
                                final color = isPhase1 ? const Color(0xFFFF0000) : const Color(0xFFFFD700); 
                                final shadowColor = isPhase1 ? Colors.redAccent.withValues(alpha: 0.5) : Colors.yellowAccent.withValues(alpha: 0.5);
                                return Container(
                                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: shadowColor, blurRadius: 12 * (isPhase1 ? (value * 2) : (2 - value * 2)), spreadRadius: 2)]),
                                  child: Icon(Icons.notifications_active, color: color, size: 24),
                                );
                              },
                            )
                          : const FaIcon(FontAwesomeIcons.bell, size: 22),

                        // Badge Layer
                        if (badgeWidget != null) badgeWidget,
                      ],
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationManagerScreen()));
                    _checkDraftStatus();
                  },
                  tooltip: hasUnread ? '${notifProvider.totalUnread} New Notifications' : 'Notifications',
                ),
              );
            }
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          final stats = provider.stats;
          
          return RefreshIndicator(
            onRefresh: () async {
               await provider.refreshData();
               _checkDraftStatus();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Announcement Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Text('📢', style: TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          Text('Announcements', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        ],
                      ),
                      InkWell(
                         onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadAnnouncementScreen()));
                         },
                         borderRadius: BorderRadius.circular(20),
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           decoration: BoxDecoration(
                             color: AppTheme.primaryColor.withValues(alpha: 0.1), 
                             borderRadius: BorderRadius.circular(20),
                             border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3))
                           ),
                           child: Text('Manage', style: GoogleFonts.inter(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                         ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('announcements')
                        .orderBy('createdAt', descending: true)
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                        final imageUrl = data['imageUrl'];
                        
                        return GestureDetector(
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadAnnouncementScreen()));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))
                              ],
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 16/9,
                                child: Stack(
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: BunnyCDNService().getAuthenticatedUrl(imageUrl),
                                      httpHeaders: const {'AccessKey': BunnyCDNService.apiKey},
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      placeholder: (c, u) => Container(color: Colors.grey[900], child: const Center(child: CircularProgressIndicator())),
                                      errorWidget: (c, u, e) => Container(color: Colors.grey[900], child: const Icon(Icons.broken_image)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      
                      // Empty State Techy
                      return GestureDetector(
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadAnnouncementScreen()));
                        },
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 30),
                                const SizedBox(height: 8),
                                Text("Upload Banner", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                   // Popular Courses Carousel
                  PopularCoursesCarousel(courses: provider.courses),
                  
                  const SizedBox(height: 20),

                  // Stats Cards Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsTab(showOnlyBuyers: false)));
                        },
                        child: StatCard(
                          title: 'App Downloads',
                          value: stats.totalStudents.toString(),
                          icon: FontAwesomeIcons.download,
                          gradient: AppTheme.infoGradient,
                          trend: 'Total Installs', 
                          isPositive: true,
                        ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideX(begin: -0.2, end: 0),
                      ),
                      
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const StudentsTab(showOnlyBuyers: true)),
                          );
                        },
                        child: StatCard(
                          title: 'Course Buyers',
                          value: provider.students.where((s) => s.enrolledCourses > 0).length.toString(),
                          icon: FontAwesomeIcons.userCheck,
                          gradient: AppTheme.successGradient,
                          trend: 'Active Students',
                          isPositive: true,
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideX(begin: -0.2, end: 0),
                      ),
                      
                      GestureDetector(
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueDetailScreen()));
                        },
                        child: StatCard(
                          title: 'Revenue',
                          value: '₹${NumberFormat.compact().format(stats.totalRevenue)}',
                          icon: FontAwesomeIcons.indianRupeeSign,
                          gradient: AppTheme.warningGradient,
                          trend: '+${stats.revenueGrowth}% vs last month',
                          isPositive: true,
                        ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideX(begin: -0.2, end: 0),
                      ),

                      GestureDetector(
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactLinksScreen()));
                        },
                        child: StatCard(
                          title: 'Contact Links',
                          value: 'Socials', // Or just '4 Links'
                          icon: FontAwesomeIcons.shareNodes, // Represents sharing/socials
                          gradient: AppTheme.primaryGradient, // Use primary brand gradient
                          trend: 'Manage WhatsApp, YT...',
                          isPositive: true, // Neutral icon
                        ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideX(begin: -0.2, end: 0),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  // Razorpay Section
                  const RazorpayDashboardCard().animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 30),

                  // Developer Console Access
                  const DeveloperAccessCard().animate().fadeIn(duration: 500.ms, delay: 600.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
