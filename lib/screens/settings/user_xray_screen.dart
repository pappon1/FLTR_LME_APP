import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../widgets/shimmer_loading.dart';
import 'ghost_home_screen.dart';

class UserXRayScreen extends StatefulWidget {
  const UserXRayScreen({super.key});

  @override
  State<UserXRayScreen> createState() => _UserXRayScreenState();
}

class _UserXRayScreenState extends State<UserXRayScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  String? _error;

  Future<void> _scanUser() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _userData = null;
      _error = null;
    });

    try {
      final input = _searchController.text.trim();
      QuerySnapshot query;
      
      // Try finding by email
      query = await FirebaseFirestore.instance.collection('students').where('email', isEqualTo: input).get();
      
      if (query.docs.isEmpty) {
        // Try finding by phone
         query = await FirebaseFirestore.instance.collection('students').where('phoneNumber', isEqualTo: input).get();
      }

      if (query.docs.isNotEmpty) {
        // Found user
        final doc = query.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        // Fetch enrollments for this user
        final enrollments = await FirebaseFirestore.instance.collection('enrollments').where('studentId', isEqualTo: doc.id).get();
        final deviceLogs = await FirebaseFirestore.instance.collection('device_logs').where('studentId', isEqualTo: doc.id).limit(1).get();

        setState(() {
          _userData = {
            'id': doc.id,
            ...data,
            'enrollmentCount': enrollments.docs.length,
            'lastDevice': deviceLogs.docs.isNotEmpty ? deviceLogs.docs.first.data()['deviceName'] : 'Unknown',
            'appVersion': deviceLogs.docs.isNotEmpty ? deviceLogs.docs.first.data()['appVersion'] : 'Unknown',
          };
        });
      } else {
        setState(() => _error = "User not found with this Email/Phone.");
      }
    } catch (e) {
      setState(() => _error = "Error scanning: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);


    return Scaffold(
      appBar: AppBar(
        title: Text("User X-Ray Diagnostics", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textTheme.bodyLarge?.color),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             // Search Box
             Container(
               padding: const EdgeInsets.all(4),
               decoration: BoxDecoration(
                 color: theme.cardTheme.color,
                 borderRadius: BorderRadius.circular(3.0),
                 boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)]
               ),
               child: TextField(
                 controller: _searchController,
                 decoration: InputDecoration(
                   hintText: "Enter Email or Phone Number",
                   prefixIcon: const Icon(Icons.person_search),
                   border: InputBorder.none,
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                   suffixIcon: IconButton(onPressed: _scanUser, icon: const Icon(Icons.arrow_forward_ios, size: 18))
                 ),
                 onSubmitted: (_) => _scanUser(),
               ),
             ),
             
             const SizedBox(height: 30),

             if (_isLoading) 
               const ShimmerLoading.rectangular(height: 400),

             if (_error != null)
               Text(_error!, style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),

             if (_userData != null)
               _buildReportCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = (_userData!['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final lastActive = (_userData!['lastLogin'] as Timestamp?)?.toDate();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(3.0),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: _userData!['profileImageUrl'] != null ? NetworkImage(_userData!['profileImageUrl']) : null,
                child: _userData!['profileImageUrl'] == null ? const Icon(Icons.person, size: 30) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(_userData!['name'] ?? 'No Name', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      _userData!['email'] ?? '', 
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _userData!['isBlocked'] == true ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(3.0)
                ),
                child: Text(
                  _userData!['isBlocked'] == true ? "BLOCKED" : "ACTIVE",
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          Text("Diagnostics Report", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueAccent)),
          const SizedBox(height: 16),

          _buildRow("Account Created", DateFormat('MMM d, yyyy').format(createdAt), Icons.calendar_today, Colors.blue),
          _buildRow("Last Active", lastActive != null ? DateFormat('MMM d, h:mm a').format(lastActive) : "Never", Icons.history, Colors.orange),
          _buildRow("Enrolled Courses", "${_userData!['enrollmentCount']}", Icons.library_books, Colors.purple),
          _buildRow("Last Device", "${_userData!['lastDevice']}", Icons.phone_android, Colors.teal),
          _buildRow("App Version", "${_userData!['appVersion']}", Icons.info_outline, Colors.grey),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => GhostHomeScreen(userId: _userData!['id'], userData: _userData!)));
              },
              icon: const Icon(Icons.privacy_tip_outlined, color: Colors.white, size: 18),
              label: const Text("Ghost Login (View as User)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
              ),
            ),
          ),

          const SizedBox(height: 16),
          
          Text("Live Spy Tools 🕵️‍♂️", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.redAccent)),
          const SizedBox(height: 12),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ScreenshotSpyDialog(userId: _userData!['id']),
                );
              },
              icon: const Icon(Icons.camera, color: Colors.white, size: 18),
              label: const Text("Capture Live Screen"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(label, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Flexible(child: Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class ScreenshotSpyDialog extends StatefulWidget {
  final String userId;
  const ScreenshotSpyDialog({super.key, required this.userId});

  @override
  State<ScreenshotSpyDialog> createState() => _ScreenshotSpyDialogState();
}

class _ScreenshotSpyDialogState extends State<ScreenshotSpyDialog> {
  String _status = "Contacting Device...";
  String? _imageUrl;
  bool _isError = false;


  @override
  void initState() {
    super.initState();
    _sendCommand();
  }

  Future<void> _sendCommand() async {
    try {
      // 1. Create Command
      final docRef = await FirebaseFirestore.instance.collection('commands').add({
        'target_user_id': widget.userId,
        'type': 'screenshot',
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 30))),
      });

      setState(() {
        _status = "Waiting for User App...";
      });

      // 2. Listen for Response
      docRef.snapshots().listen((snapshot) {
        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data == null) return;

        final status = data['status'];
        
        if (status == 'completed' && data['image_url'] != null) {
          if (mounted) {
            setState(() {
              _status = "Capture Success!";
              _imageUrl = data['image_url'];
            });
          }
        } else if (status == 'failed') {
          if (mounted) {
            setState(() {
              _status = "Capture Failed: ${data['error'] ?? 'Unknown'}";
              _isError = true;
            });
          }
        }
      });
      
      // 3. Timeout Safety
      Future.delayed(const Duration(seconds: 15), () {
        if (_imageUrl == null && mounted) {
          setState(() {
            _status = "Timeout: User is likely Offline or App Closed.";
            _isError = true;
          });
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "Error: $e";
          _isError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               if (_imageUrl != null)
                 Column(
                   children: [
                     Text("Target Screen View", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                     const SizedBox(height: 16),
                     ClipRRect(
                       borderRadius: BorderRadius.circular(3.0),
                       child: Image.network(_imageUrl!, height: 400, fit: BoxFit.contain),
                     ),
                     const SizedBox(height: 16),
                     ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
                   ],
                 )
               else 
                 Column(
                   children: [
                     if (!_isError) const CircularProgressIndicator(color: Colors.redAccent),
                     if (_isError) const Icon(Icons.error_outline, color: Colors.red, size: 50),
                     const SizedBox(height: 20),
                     Text(_status, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                     const SizedBox(height: 20),
                     if (_imageUrl == null)
                       TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                   ],
                 )
            ],
          ),
        ),
      ),
    );
  }
}

