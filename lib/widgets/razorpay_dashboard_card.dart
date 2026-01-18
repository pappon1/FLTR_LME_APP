import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../screens/razorpay/razorpay_config_screen.dart';
import '../screens/razorpay/razorpay_settlements_screen.dart';
import '../screens/razorpay/razorpay_reports_screen.dart';

class RazorpayDashboardCard extends StatelessWidget {
  const RazorpayDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Razorpay Brand Colors
    const rzpBlue = Color(0xFF3395FF);
    const rzpDark = Color(0xFF0F264A);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? rzpDark : const Color(0xFF1E293B), // Dark Navy for Techy feel
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: rzpBlue.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: rzpBlue.withValues(alpha: 0.3), width: 1),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B), 
            Color(0xFF0F172A)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: const FaIcon(FontAwesomeIcons.registered, color: Color(0xFF0C2444), size: 16), // Fake R logo
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Razorpay Gateway',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.5))
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('LIVE', style: GoogleFonts.inter(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.5, end: 1.0, duration: 1.seconds),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Main Stats Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Settlement',
                      style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹ 12,450.00', // Dummy dynamic look
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due by Tomorrow, 10 AM',
                      style: GoogleFonts.inter(color: rzpBlue, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        'Today\'s Collection',
                        style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹ 4,200',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.trending_up, color: Colors.greenAccent, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '12 Successful Payments',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white10),
          const SizedBox(height: 16),
          
          // Actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildAction(context, Icons.history, 'Settlements', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RazorpaySettlementsScreen()))),
                const SizedBox(width: 8),
                _buildAction(context, Icons.receipt_long, 'Reports', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RazorpayReportsScreen()))),
                const SizedBox(width: 8),
                _buildAction(context, Icons.settings, 'Settings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RazorpayConfigScreen()))),
              ],
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10)
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 13),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
