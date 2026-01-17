import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/settings/error_logs_screen.dart';

class TechManagementCard extends StatefulWidget {
  const TechManagementCard({super.key});

  @override
  State<TechManagementCard> createState() => _TechManagementCardState();
}

class _TechManagementCardState extends State<TechManagementCard> {
  bool _isCleaning = false;
  double _cacheDurationHours = 1.0; 

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
      if (doc.exists && doc.data()!.containsKey('cache_duration_hours')) {
        setState(() {
          _cacheDurationHours = (doc.data()!['cache_duration_hours'] as num).toDouble();
        });
      }
    } catch (e) {
      // debugPrint("Error loading config: $e");
    }
  }

  Future<void> _triggerCacheClean() async {
    setState(() => _isCleaning = true);
    try {
      // Logic: Update a timestamp. The user app listens to this. 
      // If user_app_last_clean < server_last_clean, it clears cache.
      await FirebaseFirestore.instance.collection('settings').doc('commands').set({
        'force_cache_clean_timestamp': FieldValue.serverTimestamp(),
        'triggered_by': 'Admin Panel',
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache Clean Command Sent to All Users! 🧹')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _updateCacheDuration(double value) async {
    setState(() => _cacheDurationHours = value);
    // Debounce saving could be added here, but direct save is fine for admin
    await FirebaseFirestore.instance.collection('settings').doc('app_config').set({
      'cache_duration_hours': value,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Tech-style styling
    final cardBg = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6); // Grey-800 or Grey-100
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal, color: Colors.purpleAccent, size: 20),
              const SizedBox(width: 10),
              Text(
                'Adv. Technical Controls',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Row 1: Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  label: "Error Logs",
                  icon: Icons.bug_report_outlined,
                  color: Colors.redAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ErrorLogsScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  label: _isCleaning ? "Cleaning..." : "Clear Cache",
                  icon: Icons.cleaning_services_outlined,
                  color: Colors.orangeAccent,
                  onTap: _isCleaning ? null : _triggerCacheClean,
                  isLoading: _isCleaning,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Row 2: API Optimizer
          Text(
            "API Call Optimizer (Bill Saver)",
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
               color: theme.scaffoldBackgroundColor,
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Refresh Rate:", style: GoogleFonts.inter(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                    Text(
                      _cacheDurationHours >= 24 
                          ? "Every 24 Hours (Best Savings)" 
                          : _cacheDurationHours < 1 
                              ? "Every 30 Mins (High Cost)" 
                              : "Every ${_cacheDurationHours.toStringAsFixed(0)} Hours",
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: Colors.blueAccent,
                    inactiveTrackColor: Colors.blueAccent.withValues(alpha: 0.2),
                    thumbColor: Colors.blueAccent,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _cacheDurationHours,
                    min: 0.5, // 30 mins
                    max: 24.0,
                    divisions: 5, // 0.5, 4, 8, 12, 16, 20, 24 roughly
                    label: "${_cacheDurationHours.toStringAsFixed(1)}h",
                    onChanged: (val) {
                      _updateCacheDuration(val);
                    },
                  ),
                ),
                Text(
                  "Controls how often user apps fetch fresh data from server. Higher duration = Lower Bills.",
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback? onTap, bool isLoading = false}) {
    final theme = Theme.of(context);


    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isLoading 
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
          ],
        ),
      ),
    );
  }
}
