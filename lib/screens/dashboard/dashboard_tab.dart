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


class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with SingleTickerProviderStateMixin {
  final ValueNotifier<bool> _showNotificationIcon = ValueNotifier(false);

  bool _hasDraft = false;
  
  // Carousel Logic
  late PageController _pageController;
  int _currentPage = 10000;
  Timer? _autoScrollTimer;
  Timer? _pauseTimer;

  bool _isPausedByUser = false;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // We will use the controller value directly for custom logic in build
    _bounceAnimation = CurvedAnimation(parent: _bounceController, curve: Curves.linear);

    _pageController = PageController(viewportFraction: 1.0, initialPage: 10000);
    _startAutoScroll();
    unawaited(_checkDraftStatus());
    unawaited(_checkPermission());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bounceController.dispose();
    _autoScrollTimer?.cancel();
    _pauseTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isPausedByUser || !mounted) return;
      if (!_pageController.hasClients) return;
      
      int currentRealPage = (_pageController.page ?? 0).round();
      int nextPage = currentRealPage + 1;
      
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.fastOutSlowIn,
      );
    });
  }

  void _onUserInteraction() {
    setState(() {
      _isPausedByUser = true;
    });
    
    _autoScrollTimer?.cancel();
    _pauseTimer?.cancel();
    
    // Resume after 15 seconds (as requested)
    _pauseTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _isPausedByUser = false;
        });
        _startAutoScroll();
      }
    });
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
                                final shadowColor = isPhase1 ? Colors.redAccent.withAlpha(128) : Colors.yellowAccent.withAlpha(128);
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
              padding: EdgeInsets.zero, // Removed global padding for edge-to-edge content
              children: [
                const SizedBox(height: 16),
                // Announcement Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withAlpha(51),
                          Colors.orange.withAlpha(13),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.orange.withAlpha(102),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('📢', style: TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Announcements',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 16, 
                          width: 1, 
                          color: Colors.orange.withAlpha(102)
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadAnnouncementScreen()));
                          },
                          child: Text(
                            'Manage',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('announcements')
                        .orderBy('createdAt', descending: true)
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                        final imageUrl = data['imageUrl'];
                        

                        return Container(
                            margin: const EdgeInsets.only(bottom: 24, left: 6, right: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(3.0),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                                width: 1.0,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: AspectRatio(
                              aspectRatio: 16/9,
                              child: CachedNetworkImage(
                                imageUrl: (imageUrl != null) ? BunnyCDNService.signUrl(imageUrl) : "",
                                httpHeaders: const {'AccessKey': BunnyCDNService.apiKey},
                                fit: BoxFit.cover,
                                placeholder: (c, u) => Container(color: Colors.grey[900], child: const Center(child: CircularProgressIndicator())),
                                errorWidget: (c, u, e) => Container(color: Colors.grey[900], child: const Icon(Icons.broken_image)),
                              ),
                            ),
                          );
                      }
                      
                      // Empty State - YouTube 16:9 Size
                      return Container(
                          margin: const EdgeInsets.only(bottom: 24, left: 6, right: 6),
                          decoration: BoxDecoration(
                             color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade200,
                             borderRadius: BorderRadius.circular(3.0),
                             border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                                width: 1.0,
                             ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: CachedNetworkImage(
                              imageUrl: "https://picsum.photos/id/4/800/450", // Dummy Laptop/Tech Image
                              fit: BoxFit.cover,
                              placeholder: (c, u) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (c, u, e) => const Icon(Icons.error),
                            ),
                          ),
                       );
                    },
                  ),
                  
                  // Popular Courses Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.withAlpha(51),
                            Colors.red.withAlpha(13),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.red.withAlpha(102),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withAlpha(25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              shape: BoxShape.circle,
                            ),
                            child: const Text('🔥', style: TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Popular Courses',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedBuilder(
                            animation: _bounceController,
                            builder: (context, child) {
                              double val = _bounceController.value;
                              // Fade in start, Fade out end
                              double opacity = 1.0;
                              if (val < 0.15) {
                                opacity = val / 0.15;
                              } else if (val > 0.85) {
                                opacity = (1.0 - val) / 0.15;
                              }
                              
                              return Opacity(
                                opacity: opacity,
                                child: Transform.translate(
                                  offset: Offset(0, -5 + (val * 12)), // Slide down 12 pixels
                                  child: child,
                                ),
                              );
                            },
                            child: Icon(
                               Icons.keyboard_double_arrow_down_rounded,
                               color: Colors.red.withAlpha(204),
                               size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                  ),
                  const SizedBox(height: 16),

                   // Popular Courses Carousel (Swipeable)
                   if (provider.popularCourses.isNotEmpty)
                     Column(
                       children: [
                         SizedBox(
                           height: 345,
                           child: NotificationListener<UserScrollNotification>(
                             onNotification: (notification) {
                               // Pause only when user actively swipes (drags) the carousel
                               _onUserInteraction();
                               return false;
                             },
                             child: PageView.builder(
                               controller: _pageController,
                               padEnds: false,
                               itemCount: provider.popularCourses.length,
                               onPageChanged: (index) {
                                 setState(() {
                                   _currentPage = index;
                                 });
                               },
                               itemBuilder: (context, index) {
                                 final courseIndex = index % provider.popularCourses.length;
                                 return CourseCard(
                                   course: provider.popularCourses[courseIndex],
                                   isEdgeToEdge: true,
                                   customHorizontalMargin: 6,
                                   bottomMargin: 14,
                                   cornerRadius: 3,
                                   showBorder: true,
                                 );
                               },
                             ),
                           ),
                         ),
                         
                         const SizedBox(height: 12),
                         
                         // Dots Indicator
                         Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: List.generate(provider.popularCourses.length, (index) {
                             final isSelected = (_currentPage % provider.popularCourses.length) == index;
                             return AnimatedContainer(
                               duration: const Duration(milliseconds: 300),
                               margin: const EdgeInsets.symmetric(horizontal: 5),
                               width: isSelected ? 16 : 10,
                               height: isSelected ? 16 : 10,
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 color: isSelected 
                                   ? const Color(0xFF00FF00) // Bright Neon Green
                                   : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300),
                                 boxShadow: isSelected 
                                   ? [
                                       BoxShadow(
                                         color: const Color(0xFF00FF00).withAlpha(153),
                                         blurRadius: 12,
                                         spreadRadius: 3,
                                       ),
                                     ]
                                   : null,
                               ),
                             );
                           }),
                         ),
                       ],
                     ),



                  const SizedBox(height: 24),

                  // Stats & Other Sections
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
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
                                child: StatCard(
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
                        RazorpayDashboardCard().animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 30),

// Developer Console Removed

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
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

