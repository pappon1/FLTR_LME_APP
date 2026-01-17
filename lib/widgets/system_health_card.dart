import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import '../services/razorpay_service.dart';
import '../services/bunny_cdn_service.dart';

class SystemHealthCard extends StatefulWidget {
  const SystemHealthCard({super.key});

  @override
  State<SystemHealthCard> createState() => _SystemHealthCardState();
}

class _SystemHealthCardState extends State<SystemHealthCard> {
  // Statuses: 0 = Checking, 1 = Online, 2 = Issues/Offline
  int _dbStatus = 0;
  int _cdnStatus = 0;
  int _gateStatus = 0;
  int _netStatus = 0;
  String _lastChecked = "Never";

  @override
  void initState() {
    super.initState();
    _performChecks();
  }

  Future<void> _performChecks() async {
    if (!mounted) return;
    setState(() {
      _dbStatus = 0;
      _cdnStatus = 0;
      _gateStatus = 0;
      _netStatus = 0;
    });

    // 1. Check Network & Internet

    try {
      await http.get(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 2));
      _netStatus = 1;
    } catch (e) {
      _netStatus = 2;
    }

    // 2. Check Database (Firestore)
    try {
      await FirebaseFirestore.instance.collection('settings').limit(1).get().timeout(const Duration(seconds: 3));
      _dbStatus = 1;
    } catch (e) {
      _dbStatus = 2;
    }

    // 3. Check Payment Gateway Config
    try {
      final keys = await RazorpayService().getKeys();
      if (keys['key_id'] != null && keys['key_id']!.isNotEmpty) {
        _gateStatus = 1;
      } else {
        _gateStatus = 2; // Config missing
      }
    } catch (e) {
      _gateStatus = 2;
    }

    // 4. Check CDN Config
    if (BunnyCDNService.apiKey.isNotEmpty) {
       _cdnStatus = 1;
    } else {
       _cdnStatus = 2;
    }

    if (mounted) {
      setState(() {
        _lastChecked = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Tech Colors
    final techBg = isDark ? const Color(0xFF111827) : const Color(0xFF1F2937);


    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: techBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.monitor_heart_outlined, color: Colors.blueAccent[100], size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'System Health',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              InkWell(
                onTap: _performChecks,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, color: Colors.white70, size: 12),
                      const SizedBox(width: 6),
                      Text("Run Diagnostics", style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildStatusItem("Database", "Firestore", _dbStatus, FontAwesomeIcons.database),
              _buildStatusItem("Video Server", "BunnyCDN", _cdnStatus, FontAwesomeIcons.server),
              _buildStatusItem("Payments", "Razorpay", _gateStatus, FontAwesomeIcons.creditCard),
              _buildStatusItem("Network", "Connectivity", _netStatus, FontAwesomeIcons.wifi),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          
          // Footer
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Text("Last Checked: $_lastChecked", style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                const Spacer(),
                Text("v1.0.0 (Stable)", style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String subLabel, int status, IconData icon) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status == 1) {
      statusColor = const Color(0xFF10B981); // Emerald Green
      statusText = "Operational";
      statusIcon = Icons.check_circle;
    } else if (status == 2) {
      statusColor = const Color(0xFFEF4444); // Red
      statusText = "Issue / Config";
      statusIcon = Icons.error;
    } else {
      statusColor = const Color(0xFFF59E0B); // Amber
      statusText = "Checking...";
      statusIcon = Icons.sync;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status == 1 ? Colors.transparent : statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(icon, color: statusColor, size: 14),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (status == 0) 
                     SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1, color: statusColor))
                  else
                     Icon(statusIcon, color: statusColor, size: 10),
                  const SizedBox(width: 4),
                  Text(statusText, style: GoogleFonts.inter(color: statusColor, fontSize: 10)),
                ],
              )
            ],
          ),
        ],
      ),
    ).animate(target: status == 0 ? 0 : 1).shimmer(duration: 1.seconds, color: Colors.white10);
  }
}
