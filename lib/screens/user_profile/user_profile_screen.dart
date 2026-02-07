import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/student_model.dart';

class UserProfileScreen extends StatefulWidget {
  final StudentModel student;

  const UserProfileScreen({super.key, required this.student});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final double _profileCardHeight = 84.0;
  final double _profileCardOffset = -10.0;
  final double _profileCardWidthMargin = 20.0;
  final double _profileCardRadius = 100.0;

  // Final Tab Indicator Values
  final double _tabIndHeight = 35.0;
  final double _tabIndWidthPadding = 19.0;
  final double _tabIndRadius = 50.0;
  final double _tabIndOffsetY = 0.0;

  // Tabs & Divider Shift
  final double _tabsLift = -7.0;
  final double _dividerShift = -9.0;
  final double _contentLift = -15.0; // Lifting the content inside tabs
  final double _infoCardPadding = 9.0; // Vertical padding for info cards
  final double _borderOpacity = 0.22; // Fixed Border Opacity
  final double _dividerOpacity = 0.22; // Fixed Divider Opacity

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
    const Color bgDark = Colors.black;
    const Color cardDark = Color(0xFF000000);
    const Color textBlue = Color(0xFF5E81FF);
    const Color greenAccent = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Compact Profile Card (Pill Shape)
            Transform.translate(
              offset: Offset(0, _profileCardOffset),
              child: Container(
                height: _profileCardHeight,
                margin: EdgeInsets.symmetric(
                  horizontal: _profileCardWidthMargin,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(_profileCardRadius),
                  border: Border.all(
                    color: Colors.white.withOpacity(_borderOpacity),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: textBlue.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: _profileCardHeight * 0.3,
                        backgroundColor: Colors.black26,
                        backgroundImage: widget.student.avatarUrl.isNotEmpty
                            ? NetworkImage(widget.student.avatarUrl)
                            : null,
                        child: widget.student.avatarUrl.isEmpty
                            ? Text(
                                widget.student.name[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: _profileCardHeight * 0.2,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.student.name,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: _profileCardHeight * 0.18 > 18
                                  ? 18
                                  : _profileCardHeight * 0.18,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ACTIVE ACCOUNT',
                                style: GoogleFonts.manrope(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 5),

            // Tabbed Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: bgDark,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 0,
                      ),
                      child: Column(
                        children: [
                          Transform.translate(
                            offset: Offset(0, _tabsLift),
                            child: TabBar(
                              controller: _tabController,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey,
                              indicatorSize: TabBarIndicatorSize.label,
                              indicator: PillIndicator(
                                height: _tabIndHeight,
                                radius: _tabIndRadius,
                                verticalOffset: _tabIndOffsetY,
                                widthPadding: _tabIndWidthPadding,
                                color: textBlue.withOpacity(0.2),
                                borderColor: textBlue.withOpacity(0.5),
                              ),
                              dividerColor: Colors.transparent,
                              tabs: const [
                                Tab(text: "User Info"),
                                Tab(text: "Courses"),
                                Tab(text: "Device Info"),
                              ],
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(0, _dividerShift),
                            child: Container(
                              height: 1,
                              width: double.infinity,
                              color: Colors.white.withOpacity(_dividerOpacity),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildUserInfoTab(cardDark),
                          _buildCoursesTab(cardDark),
                          _buildDeviceInfoTab(cardDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoTab(Color cardColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Transform.translate(
        offset: Offset(0, _contentLift),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PERSONAL DETAILS',
              style: GoogleFonts.manrope(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              Icons.person_outline,
              'Full Name',
              widget.student.name,
              cardColor,
              showCopy: true,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              Icons.email_outlined,
              'Email Address',
              widget.student.email,
              cardColor,
              showCopy: true,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              FontAwesomeIcons.whatsapp,
              'WhatsApp No',
              widget.student.phone.isNotEmpty
                  ? widget.student.phone
                  : 'Not Provided',
              cardColor,
              showCopy: widget.student.phone.isNotEmpty,
              onTap: widget.student.phone.isNotEmpty
                  ? () async {
                      String cleanPhone = widget.student.phone.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );

                      if (cleanPhone.length == 10) {
                        cleanPhone = '91$cleanPhone';
                      }

                      // Using simple wa.me link as requested
                      final url = Uri.parse("https://wa.me/$cleanPhone");

                      try {
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          throw 'Could not launch WhatsApp';
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 30),
            Text(
              'ACCOUNT STATISTICS',
              style: GoogleFonts.manrope(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    Icons.calendar_today,
                    'Joined',
                    '11 Jan 26',
                    Colors.purpleAccent,
                    cardColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    Icons.menu_book,
                    'Courses',
                    '0',
                    Colors.tealAccent,
                    cardColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDeleteConfirmation(context),
                icon: const Icon(Icons.delete_forever, size: 20),
                label: Text(
                  'DELETE ACCOUNT PERMANENTLY',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.redAccent.withOpacity(0.02),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActionConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
    IconData icon = Icons.warning_amber_rounded,
    Color iconColor = Colors.redAccent,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: Colors.grey,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.manrope(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iconColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    _showActionConfirmation(
      context: context,
      title: 'Delete user account?',
      message:
          'This action is permanent and cannot be undone. All data associated with this user will be wiped from our servers.',
      confirmLabel: 'DELETE NOW',
      onConfirm: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      },
    );
  }

  void _showRevokeAccessConfirmation(BuildContext context, String courseTitle) {
    _showActionConfirmation(
      context: context,
      title: 'Revoke enrollment?',
      message:
          'Are you sure you want to cancel access for "$courseTitle"? The user will no longer be able to watch any lessons from this course.',
      confirmLabel: 'REVOKE NOW',
      onConfirm: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access revoked for $courseTitle')),
        );
      },
      icon: Icons.cancel_outlined,
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value,
    Color bgColor, {
    bool showCopy = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _infoCardPadding,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(_borderOpacity)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.open_in_new,
                  color: Colors.blue.withOpacity(0.5),
                  size: 16,
                ),
              ),
            if (showCopy)
              IconButton(
                icon: const Icon(
                  Icons.content_copy,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value)).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color iconColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(_borderOpacity)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.manrope(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesTab(Color cardColor) {
    final List<Map<String, dynamic>> courses = [
      {
        'title': 'Advanced Mobile Hardware Repair',
        'progress': 0.75,
        'lessons': '24/32',
        'instructor': 'Imtiyaz Sir',
        'icon': Icons.build_circle_outlined,
        'color': const Color(0xFF5E81FF),
        'thumbnail':
            'https://images.unsplash.com/photo-1597740985671-2a8a3b80502e?q=80&w=1000',
        'price': 4999,
        'originalPrice': 9999,
        'totalVideos': 45,
      },
      {
        'title': 'Master iPhone Logic Board Repair',
        'progress': 0.30,
        'lessons': '12/40',
        'instructor': 'Professional Team',
        'icon': Icons.apple,
        'color': Colors.amberAccent,
        'thumbnail':
            'https://images.unsplash.com/photo-1621330396173-e41b1cafd17f?q=80&w=1000',
        'price': 7999,
        'originalPrice': 15999,
        'totalVideos': 62,
      },
      {
        'title': 'Android Software & Flashing Guide',
        'progress': 1.0,
        'lessons': '15/15',
        'instructor': 'Imtiyaz Sir',
        'icon': Icons.android,
        'color': const Color(0xFF00E676),
        'thumbnail':
            'https://images.unsplash.com/photo-1601784551446-20c9e07cdbdb?q=80&w=1000',
        'price': 2999,
        'originalPrice': 5999,
        'totalVideos': 28,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENROLLED COURSES',
            style: GoogleFonts.manrope(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          ...courses.map((course) {
            final double sellingPrice = course['price'].toDouble();
            final double originalPrice = course['originalPrice'].toDouble();
            final int discountPercent =
                ((originalPrice - sellingPrice) / originalPrice * 100).round();

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Colors.white.withOpacity(_borderOpacity),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🖼️ Thumbnail Section
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                        ),
                        image: DecorationImage(
                          image: NetworkImage(course['thumbnail']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  // 📝 Content Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✨ Badges Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCardBadge(
                                Icons.menu_book,
                                '${course['totalVideos']} Videos',
                                const Color(0xFF536DFE),
                              ),
                              const SizedBox(width: 12),
                              _buildCardBadge(
                                Icons.play_arrow,
                                'Demo',
                                const Color(0xFF00E676),
                              ),
                              const SizedBox(width: 12),
                              _buildCardBadge(
                                Icons.workspace_premium,
                                'Cert',
                                const Color(0xFFFF5252),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 🏷️ Title & Instructor
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course['title'],
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (course['progress'] == 1.0)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF00E676),
                                size: 22,
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Divider(
                          color: Colors.white.withOpacity(_dividerOpacity),
                          height: 1,
                        ),
                        const SizedBox(height: 16),

                        // 💰 Pricing Section
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${course['price']}',
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${course['originalPrice']}',
                                    style: GoogleFonts.manrope(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$discountPercent% OFF',
                                    style: GoogleFonts.manrope(
                                      color: const Color(0xFF00E676),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 📈 Progress & Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Learning Progress',
                              style: GoogleFonts.manrope(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${(course['progress'] * 100).toInt()}%',
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: course['progress'],
                            backgroundColor: Colors.white.withOpacity(0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              course['color'],
                            ),
                            minHeight: 6,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 🛑 Action Button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () => _showRevokeAccessConfirmation(
                              context,
                              course['title'],
                            ),
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            label: Text(
                              'REVOKE ACCESS FOR THIS USER',
                              style: GoogleFonts.manrope(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(
                                0.05,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCardBadge(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceInfoTab(Color cardColor) {
    final List<Map<String, String>> sessions = [
      {
        'device': 'Samsung Galaxy S23 Ultra',
        'location': 'New Delhi, India',
        'ip': '192.168.1.45',
        'time': 'Jan 31, 2026 • 04:22 PM',
        'network': 'Wi-Fi • Jio Fiber',
      },
      {
        'device': 'Chrome Browser (Windows)',
        'location': 'New Delhi, India',
        'ip': '192.168.1.45',
        'time': 'Jan 31, 2026 • 12:37 PM',
        'network': 'Ethernet • Spectranet',
      },
      {
        'device': 'Samsung Galaxy S23 Ultra',
        'location': 'Mumbai, India',
        'ip': '10.0.0.12',
        'time': 'Jan 29, 2026 • 04:37 PM',
        'network': '4G • Airtel',
      },
      {
        'device': 'OnePlus 11R',
        'location': 'Pune, India',
        'ip': '172.16.0.5',
        'time': 'Jan 26, 2026 • 04:37 PM',
        'network': '5G • Jio',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Device Card
          Text(
            'CURRENTLY ACTIVE',
            style: GoogleFonts.manrope(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(_borderOpacity),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5E81FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.smartphone,
                        color: Color(0xFF5E81FF),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Samsung Galaxy S23 Ultra',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'App Version: v2.4.1 (Stable)',
                            style: GoogleFonts.manrope(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeviceSpec('OS Version', 'Android 14'),
                    _buildDeviceSpec('Model', 'SM-S918B'),
                    _buildDeviceSpec(
                      'Status',
                      'ONLINE',
                      valueColor: Colors.greenAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Security Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _showActionConfirmation(
                  context: context,
                  title: 'Logout all devices?',
                  message:
                      'This will terminate all active sessions for this user across all mobile and web devices. They will need to login again.',
                  confirmLabel: 'LOGOUT ALL',
                  onConfirm: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All sessions terminated')),
                    );
                  },
                  icon: Icons.phonelink_erase_rounded,
                );
              },
              icon: const Icon(Icons.logout, size: 18),
              label: Text(
                'LOGOUT FROM ALL DEVICES',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'LOGIN TIMELINE',
            style: GoogleFonts.manrope(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5E81FF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF5E81FF).withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                          ),
                          if (index != sessions.length - 1)
                            Expanded(
                              child: Container(width: 2, color: Colors.white24),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session['device']!,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session['location']!,
                            style: GoogleFonts.manrope(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'IP: ${session['ip']!} • ${session['network']!}',
                            style: GoogleFonts.manrope(
                              color: Colors.grey.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session['time']!,
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF5E81FF).withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSpec(
    String label,
    String value, {
    Color valueColor = Colors.white,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(color: Colors.grey, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.manrope(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class PillIndicator extends Decoration {
  final double height;
  final double radius;
  final double verticalOffset;
  final double widthPadding;
  final Color color;
  final Color borderColor;

  const PillIndicator({
    required this.height,
    required this.radius,
    required this.verticalOffset,
    required this.widthPadding,
    required this.color,
    required this.borderColor,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _PillPainter(this, onChanged);
  }
}

class _PillPainter extends BoxPainter {
  final PillIndicator decoration;

  _PillPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;
    final Paint paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.fill;

    // Use absolute width + padding
    final double pillWidth =
        configuration.size!.width + decoration.widthPadding;
    final double pillHeight = decoration.height;

    final double centerX = rect.center.dx;
    // verticalOffset negative moves it UP
    final double centerY = rect.center.dy + decoration.verticalOffset;

    final Rect pillRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: pillWidth,
      height: pillHeight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, Radius.circular(decoration.radius)),
      paint,
    );

    final Paint borderPaint = Paint()
      ..color = decoration.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, Radius.circular(decoration.radius)),
      borderPaint,
    );
  }
}
