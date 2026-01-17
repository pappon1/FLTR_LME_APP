import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/student_model.dart';

class EnrollmentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> enrollment;
  final StudentModel student;

  const EnrollmentDetailScreen({super.key, required this.enrollment, required this.student});

  @override
  @override
  Widget build(BuildContext context) {
    // Tech Vibe Colors
    const Color techDark = Color(0xFF1A1A2E);
    const Color techBlue = Color(0xFF16213E);
    const Color techAccent = Color(0xFF0F3460);
    const Color neonGreen = Color(0xFF4ECCA3);
    const Color neonRed = Color(0xFFFF5959);

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Text('ENROLLMENT DETAILS', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [techDark, techBlue],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
          child: Column(
            children: [
              // 1. Status Badge (Floating)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: enrollment['isActive'] ? neonGreen.withValues(alpha: 0.1) : neonRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: enrollment['isActive'] ? neonGreen : neonRed, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: (enrollment['isActive'] ? neonGreen : neonRed).withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 1)
                  ]
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(enrollment['isActive'] ? Icons.check_circle : Icons.cancel, color: enrollment['isActive'] ? neonGreen : neonRed, size: 16),
                     const SizedBox(width: 8),
                    Text(
                      enrollment['isActive'] ? 'ACTIVE LICENSE' : 'LICENSE REVOKED/EXPIRED',
                      style: GoogleFonts.orbitron(
                        color: enrollment['isActive'] ? neonGreen : neonRed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Main Glass Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Column(
                      children: [
                        // A. User Header Section
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                          ),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: neonGreen.withValues(alpha: 0.5), width: 2),
                                  boxShadow: [BoxShadow(color: neonGreen.withValues(alpha: 0.2), blurRadius: 10)]
                                ),
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: techAccent,
                                  child: Text(
                                    student.name.isNotEmpty ? student.name[0].toUpperCase() : 'U',
                                    style: GoogleFonts.orbitron(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name.toUpperCase(),
                                      style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.message, size: 12, color: Colors.white.withValues(alpha: 0.6)),
                                        const SizedBox(width: 6),
                                        Text(
                                          student.phone.isNotEmpty ? student.phone : 'No WhatsApp No',
                                          style: GoogleFonts.sourceCodePro(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // B. Info Grid
                        Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('COURSE INFORMATION'),
                              const SizedBox(height: 16),
                              _buildTechRow(Icons.laptop_chromebook, 'COURSE NAME', enrollment['courseTitle'] ?? 'Unknown', isHighlighted: true),
                              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(color: Colors.white10)),
                              
                              _buildSectionHeader('SUBSCRIPTION DETAILS'),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: _buildTechBox('START DATE', _formatDate(enrollment['enrolledAt']))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildTechBox('EXPIRY DATE', enrollment['expiryDate'] != null ? _formatDate(enrollment['expiryDate']) : 'LIFETIME ACCESS', isAlert: enrollment['expiryDate'] != null)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildTechBox('PRICE PAID', enrollment['price'] ?? '₹0.00')),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildTechBox('PAYMENT MODE', enrollment['paymentDetail'] ?? 'Manual')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Footer / Actions (Optional placeholder)
              const SizedBox(height: 30),
              Text(
                "SECURE DATABASE RECORD • VERIFIED",
                style: GoogleFonts.robotoMono(color: Colors.white24, fontSize: 10, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    if (date is Timestamp) return DateFormat('dd MMM yyyy').format(date.toDate());
    if (date is DateTime) return DateFormat('dd MMM yyyy').format(date);
    return date.toString();
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        const Icon(Icons.data_usage, size: 14, color: Colors.cyanAccent),
        const SizedBox(width: 8),
        Text(
          title, 
          style: GoogleFonts.orbitron(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)
        ),
      ],
    );
  }

  Widget _buildTechRow(IconData icon, String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.rubik(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(
                  value, 
                  style: GoogleFonts.rubik(
                    color: isHighlighted ? Colors.white : Colors.white70, 
                    fontSize: isHighlighted ? 16 : 14, 
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechBox(String label, String value, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.rubik(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.rubik(
              color: isAlert ? Colors.orangeAccent : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
