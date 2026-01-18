import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'enrollment_detail_screen.dart'; // Add this
import '../../models/student_model.dart';
import '../../services/firestore_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final StudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> with SingleTickerProviderStateMixin {
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

    
    // Theme Colors

    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;


    return Scaffold(
      backgroundColor: scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 350.0,
              floating: false,
              pinned: true,
              backgroundColor: primaryColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: innerBoxIsScrolled ? 1.0 : 0.0,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.student.name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor,
                            const Color(0xFF4CA1AF), // Cyan-ish accent
                          ],
                        ),
                      ),
                    ),
                    // Pattern Overlay (Optional)
                    Opacity(
                      opacity: 0.1,
                      child: Container(
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage("https://www.transparenttextures.com/patterns/cubes.png"), // Subtle pattern
                            repeat: ImageRepeat.repeat,
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           const SizedBox(height: 20), // Offset for AppBar height
                           
                           // Header Title
                           Text(
                             "USER PROFILE",
                             style: GoogleFonts.poppins(
                               color: Colors.white70,
                               fontSize: 12,
                               fontWeight: FontWeight.bold,
                               letterSpacing: 2.0,
                             ),
                           ).animate().fadeIn(),

                           const SizedBox(height: 10),

                           // Avatar with Glow
                           Hero(
                            tag: 'student_avatar_${widget.student.id}',
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.student.isActive ? Colors.green.withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundImage: CachedNetworkImageProvider(widget.student.avatarUrl),
                              ),
                            ),
                           ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                           
                           const SizedBox(height: 16),
                           
                           // Name
                           FittedBox(
                             child: Text(
                               widget.student.name,
                               textAlign: TextAlign.center,
                               style: GoogleFonts.poppins(
                                 fontSize: 24, 
                                 fontWeight: FontWeight.bold, 
                                 color: Colors.white,
                                 shadows: [const Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)]
                               ),
                             ),
                           ).animate().fadeIn().moveY(begin: 10, end: 0),
                           
                           const SizedBox(height: 8),

                           // Status Pill
                           Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle, 
                                  color: widget.student.isActive ? const Color(0xFF4ECCA3) : Colors.redAccent, 
                                  size: 10
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.student.isActive ? "ACTIVE ACCOUNT" : "INACTIVE ACCOUNT",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white, 
                                        fontSize: 11, 
                                        fontWeight: FontWeight.w600, 
                                        letterSpacing: 1.2
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 200.ms),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: primaryColor,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
        body: Container(
          color: cardColor, // Matches the rounded header bottom
          child: TabBarView(
            controller: _tabController,
            children: [
              _UserInfoTab(student: widget.student),
              _StudentCoursesTab(student: widget.student),
              _DeviceHistoryTab(studentId: widget.student.id),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TAB 1: USER INFO
// ==========================================
class _UserInfoTab extends StatelessWidget {
  final StudentModel student;

  const _UserInfoTab({required this.student});

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('$label copied!'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 80),
      children: [
        _buildSectionTitle(context, 'Personal Details'),
        const SizedBox(height: 12),
        _buildModernInfoCard(context, FontAwesomeIcons.user, 'Full Name', student.name, Colors.blue),
        _buildModernInfoCard(context, FontAwesomeIcons.envelope, 'Email Address', student.email, Colors.orange),
        _buildModernInfoCard(context, FontAwesomeIcons.whatsapp, 'WhatsApp No', student.phone.isNotEmpty ? student.phone : 'Not Provided', Colors.green),
        
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Account Statistics'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(context, 'Joined On', DateFormat('dd MMM yy').format(student.joinedDate), FontAwesomeIcons.calendar, Colors.purple)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(context, 'Courses', '${student.enrolledCourses}', FontAwesomeIcons.bookOpen, Colors.teal)),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 12, 
        fontWeight: FontWeight.bold, 
        color: Theme.of(context).hintColor, 
        letterSpacing: 1.2
      ),
    );
  }

  Widget _buildModernInfoCard(BuildContext context, IconData icon, String label, String value, Color color) {
    final bg = Theme.of(context).cardColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: FaIcon(icon, color: color, size: 20),
        ),
        title: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).hintColor)),
        subtitle: Text(
          value, 
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(Icons.copy_rounded, color: Theme.of(context).hintColor, size: 20),
          onPressed: () => _copy(context, value, label),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    final bg = Theme.of(context).cardColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color))
          ),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).hintColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 2: COURSES
// ==========================================
// Add import at the top of the file if not exists (I can't add imports easily with replace_file_content if I don't target the top. 
// I will rely on the user or a separate step to fix imports if they are missing, 
// BUT this is an inner class. I should modify the Parent to pass specific data or context.
// Actually, I can just modify _StudentCoursesTab to accept 'student' object.

class _StudentCoursesTab extends StatelessWidget {
  final StudentModel student;

  const _StudentCoursesTab({required this.student});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService().getStudentEnrollmentDetails(student.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final enrollments = snapshot.data!;
        
        if (enrollments.isEmpty) {
           return Center(child: Text("No Active Enrollments", style: GoogleFonts.poppins(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 80),
          itemCount: enrollments.length,
          itemBuilder: (context, index) {
            final e = enrollments[index];
            final bool isActive = e['isActive'];
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: e['courseThumbnail'],
                        width: 120, height: 68, // 16:9 Ratio
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(color: Colors.grey[200], width: 120, height: 68, child: const Icon(Icons.image)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['courseTitle'],
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'ACTIVE' : 'REVOKED/PAUSED',
                              style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Theme.of(context).hintColor),
                      onSelected: (val) => _handleAction(context, e, val),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'details', child: Row(children: [Icon(Icons.info_outline, color: Colors.blue), SizedBox(width: 8), Text('Details')])),
                        PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Deactivate' : 'Reactivate')),
                        const PopupMenuItem(value: 'revoke', child: Text('Revoke Access', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().slideX(duration: 400.ms, delay: (100 * index).ms);
          },
        );
      },
    );
  }

  void _handleAction(BuildContext context, Map<String, dynamic> e, String action) {
     if (action == 'details') {
       Navigator.push(context, MaterialPageRoute(builder: (_) => EnrollmentDetailScreen(enrollment: e, student: student)));
       return;
     }

     final bool isActive = e['isActive'];
     showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text(action == 'revoke' ? 'Revoke Access?' : (isActive ? 'Deactivate?' : 'Activate?')),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () async {
             Navigator.pop(ctx);
             if (action == 'revoke') {
               await FirestoreService().revokeEnrollment(e['enrollmentId']);
             } else {
               await FirestoreService().toggleEnrollmentStatus(e['enrollmentId'], !isActive);
             }
          }, child: const Text('Confirm')),
        ],
     ));
  }
}


// ==========================================
// TAB 3: DEVICE INFO
// ==========================================
class _DeviceHistoryTab extends StatelessWidget {
  final String studentId;
  const _DeviceHistoryTab({required this.studentId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: FirestoreService().getLoginHistory(studentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        return ListView(
          padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 80),
          children: [
            Text('LOGIN TIMELINE', style: GoogleFonts.poppins(color: Theme.of(context).hintColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            ...snapshot.data!.map((log) => _buildLogItem(context, log)),
          ],
        );
      },
    );
  }

  Widget _buildLogItem(BuildContext context, Map<String, String> log) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Line
          Column(children: [
            Container(width: 2, height: 20, color: Theme.of(context).dividerColor),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle)),
            Expanded(child: Container(width: 2, color: Theme.of(context).dividerColor)),
          ]),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log['device'] ?? 'Unknown', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${log['location']} • ${log['ip']}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text(DateFormat('MMM d, y • hh:mm a').format(DateTime.parse(log['time']!)), style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Logout / Delete Access Button
                  IconButton(
                    onPressed: () => _confirmLogout(context, log),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout, color: Colors.red, size: 20),
                    ),
                    tooltip: 'Revoke Access (Logout)',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, Map<String, String> log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout Device?'),
        content: Text('Are you sure you want to revoke access for "${log['device']}"?\n\nThe user will be logged out from this device immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirestoreService().revokeDeviceSession(studentId, log['sessionId'] ?? '');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Access revoked for ${log['device']}')),
                );
                // Trigger rebuild if using a real stream, otherwise this just shows feedback for mock
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}


