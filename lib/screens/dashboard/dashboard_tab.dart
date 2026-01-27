import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/shimmer_loading.dart';
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
import '../../widgets/course_card.dart';
import '../../models/course_model.dart';
import '../notifications/notification_manager_screen.dart';
import '../students/students_tab.dart';
import '../../services/local_notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final ValueNotifier<bool> _showNotificationIcon = ValueNotifier(false);

  // Dummy Data for Popular Courses (Matches Courses Tab)
  final List<CourseModel> _popularCourses = [
    CourseModel(
      id: '101',
      title: 'Advanced Chip Level Repairing',
      category: 'Hardware',
      price: 25000,
      discountPrice: 19999,
      description: 'Master mobile hardware repairing from basics to advanced chip level.',
      thumbnailUrl: 'https://picsum.photos/id/1/800/450',
      duration: '3 Months',
      difficulty: 'Advanced',
      enrolledStudents: 1540,
      rating: 4.8,
      totalVideos: 120,
      isPublished: true,
      hasCertificate: true,
    ),
    CourseModel(
      id: '102',
      title: 'iPhone Schematic Diagrams Masterclass',
      category: 'Schematics',
      price: 8000,
      discountPrice: 4999,
      description: 'Learn to read and understand iPhone schematics layouts like a pro.',
      thumbnailUrl: 'https://picsum.photos/id/2/800/450',
      duration: '45 Days',
      difficulty: 'Intermediate',
      enrolledStudents: 850,
      rating: 4.6,
      totalVideos: 45,
      isPublished: true,
    ),
    CourseModel(
      id: '103',
      title: 'Android Software Flashing & Unlocking',
      category: 'Software',
      price: 12000,
      discountPrice: 6999,
      description: 'Complete guide to software flashing, FRP bypass, and unlocking tools.',
      thumbnailUrl: 'https://picsum.photos/id/3/800/450',
      duration: '2 Months',
      difficulty: 'Intermediate',
      enrolledStudents: 2100,
      rating: 4.7,
      totalVideos: 80,
      isPublished: true,
    ),
  ];

  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkDraftStatus());
    unawaited(_checkPermission());
  }

  Future<void> _checkPermission() async {
    final service = LocalNotificationService();
    final hasPermission = await service.checkPermission();
    
    if (!hasPermission && mounted) {
       // Wait a bit for UI to settle
       await Future.delayed(const Duration(seconds: 2));
       if (!mounted) return;

       unawaited(showDialog(
         context: context,
         builder: (context) => AlertDialog(
           title: const Text('Enable Notifications'),
           content: const Text('To receive alerts about new messages, payments, and downloads, please enable notifications.'),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
             ElevatedButton(
               onPressed: () async {
                 Navigator.pop(context);
                 final status = await service.requestPermission();
                 if ((status.isDenied || status.isPermanentlyDenied) && mounted) {
                    unawaited(openAppSettings());
                 }
               },
               child: const Text('Enable'),
             ),
           ],
         ),
       ));
    }
  }

  Future<void> _checkDraftStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('draft_title');
    final desc = prefs.getString('draft_description');
    final image = prefs.getString('draft_image_path');
    
    // If any significant field has data, we consider it a draft
    final bool hasData = (title != null && title.isNotEmpty) || 
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dashboard',
              style: AppTheme.heading2(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
              style: AppTheme.bodySmall(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                    unawaited(_checkDraftStatus());
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
          if (provider.isLoading && provider.courses.isEmpty) {
            return _buildShimmerDashboard(context);
          }
          
          final stats = provider.stats;
          
          return RefreshIndicator(
            onRefresh: () async {
               await provider.refreshData();
               unawaited(_checkDraftStatus());
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // Announcement Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3.0)),
                              child: const Text('📢', style: TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Announcements', 
                                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                         onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadAnnouncementScreen()));
                         },
                         borderRadius: BorderRadius.circular(3.0),
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           decoration: BoxDecoration(
                             color: AppTheme.primaryColor.withValues(alpha: 0.1), 
                             borderRadius: BorderRadius.circular(3.0),
                             border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3))
                           ),
                           child: FittedBox(
                             fit: BoxFit.scaleDown,
                             child: Text('Manage', style: GoogleFonts.inter(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600))
                           ),
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
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        
                        return GestureDetector(
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadAnnouncementScreen()));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: AspectRatio(
                              aspectRatio: 16/9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3.0),
                                child: CachedNetworkImage(
                                  imageUrl: (imageUrl != null) ? BunnyCDNService.signUrl(imageUrl) : "",
                                  httpHeaders: const {'AccessKey': BunnyCDNService.apiKey},
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => Container(color: Colors.grey[900], child: const Center(child: CircularProgressIndicator())),
                                  errorWidget: (c, u, e) => Container(color: Colors.grey[900], child: const Icon(Icons.broken_image)),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      
                      // Empty State - YouTube 16:9 Size
                      return GestureDetector(
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadAnnouncementScreen()));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                             color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade200,
                             borderRadius: BorderRadius.circular(3.0),
                             border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                                width: 1,
                             ),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3.0),
                              child: CachedNetworkImage(
                                imageUrl: "https://picsum.photos/id/4/800/450", // Dummy Laptop/Tech Image
                                fit: BoxFit.cover,
                                placeholder: (c, u) => const Center(child: CircularProgressIndicator()),
                                errorWidget: (c, u, e) => const Icon(Icons.error),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  

                  
                  // Popular Courses Section
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1), 
                          borderRadius: BorderRadius.circular(3.0)
                        ),
                        child: const Text('🔥', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Popular Courses', 
                          style: GoogleFonts.outfit(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold, 
                            color: Theme.of(context).textTheme.bodyLarge?.color
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Popular Courses Carousel (Swipeable)
                  SizedBox(
                    height: 385, // Height to fit the CourseCard
                    child: PageView.builder(
                      controller: PageController(viewportFraction: 0.95),
                      padEnds: false,
                      itemCount: _popularCourses.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0), // Gap between items
                          child: CourseCard(course: _popularCourses[index]),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Stats Cards Grid
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactLinksScreen()));
                          },
                          child: const StatCard(
                            title: 'Contact Links',
                            value: 'Socials', // Or just '4 Links'
                            icon: FontAwesomeIcons.shareNodes, // Represents sharing/socials
                            gradient: AppTheme.primaryGradient, // Use primary brand gradient
                            trend: 'Manage WhatsApp, YT...',
                            isPositive: true, // Neutral icon
                          ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideX(begin: -0.2, end: 0),
                        ),
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
          );
        },
      ),
    );
  }

  Widget _buildShimmerDashboard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Announcement Shimmer
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3.0),
              ),
            ),
            const SizedBox(height: 24),
            

            
            // Grid Shimmer
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
              children: List.generate(4, (index) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3.0),
                ),
              )),
            ),
            const SizedBox(height: 24),
            
            // Razorpay Card Shimmer
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

