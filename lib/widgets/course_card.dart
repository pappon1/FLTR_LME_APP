import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/course_model.dart';
import '../services/bunny_cdn_service.dart';
import '../screens/courses/course_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CourseCard extends StatelessWidget {
  final CourseModel course;
  final bool isEdgeToEdge;
  final double? customHorizontalMargin;
  final double? bottomMargin;
  final double? cornerRadius;
  final bool? showBorder;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    this.isEdgeToEdge = false,
    this.customHorizontalMargin,
    this.bottomMargin,
    this.cornerRadius,
    this.showBorder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Correct Pricing Logic: price = MRP, discountPrice = Selling Price
    final double sellingPrice = course.discountPrice.toDouble();
    final double originalPrice = course.price.toDouble();

    final int discountPercent =
        (originalPrice > sellingPrice && originalPrice > 0)
        ? ((originalPrice - sellingPrice) / originalPrice * 100).round()
        : 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          margin: EdgeInsets.only(
            top: (course.isSpecialTagVisible && course.specialTag.isNotEmpty) ? 15 : 0,
            bottom: bottomMargin ?? 20,
            left: customHorizontalMargin ?? (isEdgeToEdge ? 0 : 16),
            right: customHorizontalMargin ?? (isEdgeToEdge ? 0 : 16),
          ),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          color: isDark ? const Color(0xFF000000) : Colors.white, // Deep Black
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius ?? 0),
            side: (showBorder ?? !isEdgeToEdge)
                ? BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1),
                    width: 1,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onTap ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseDetailScreen(course: course),
                    ),
                  );
                },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🖼️ Thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: BunnyCDNService.signUrl(course.thumbnailUrl),
                      httpHeaders: BunnyCDNService.signUrl(course.thumbnailUrl)
                              .contains(
                        'storage.bunnycdn.com',
                      )
                          ? const {'AccessKey': BunnyCDNService.apiKey}
                          : null,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                        highlightColor: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade100,
                        child: Container(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
    
                // 📝 Content
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✨ Badges Row (Warped for better visibility)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // 📂 Category Badge
                          if (course.category.isNotEmpty) ...[
                            _buildBadge(
                              icon: Icons.category,
                              label: course.category,
                              color: const Color(0xFF3F51B5), // Indigo
                            ),
                          ],
                          // 📊 Difficulty Badge
                          if (course.difficulty.isNotEmpty) ...[
                            _buildBadge(
                              icon: Icons.signal_cellular_alt,
                              label: course.difficulty,
                              color: const Color(0xFF795548), // Brown
                            ),
                          ],
    
                          // ✨ New

    
                          // 🌐 Language
                          _buildBadge(
                            icon: Icons.language,
                            label: course.language,
                            color: const Color(0xFF9C27B0),
                          ),
    
                          // 🎥 Mode
                          _buildBadge(
                            icon: course.courseMode
                                    .toLowerCase()
                                    .contains('live')
                                ? Icons.sensors
                                : Icons.play_circle_outline,
                            label: course.courseMode,
                            color: const Color(0xFFFF5722),
                          ),
    
                          // 🎗️ Cert
                          if (course.hasCertificate) ...[
                            _buildBadge(
                              icon: Icons.workspace_premium,
                              label: 'Certificate',
                              color: const Color(0xFFFF5252),
                            ),
                          ],
    
                          // ⏳ Validity
                          _buildBadge(
                            icon: Icons.history_toggle_off,
                            label: course.duration,
                            color: const Color(0xFF00BCD4), // Cyan
                          ),
    
                          // ⬇️ Offline & Web Access
                          if (course.isOfflineDownloadEnabled) ...[
                            _buildBadge(
                              icon: Icons.download_for_offline,
                              label: 'Offline Access',
                              color: const Color(0xFF009688), // Teal
                            ),
                          ],
                          if (course.isBigScreenEnabled) ...[
                            _buildBadge(
                              icon: Icons.devices,
                              label: 'Web/PC Access',
                              color: const Color(0xFF03A9F4),
                            ),
                          ],
    
                          // 💬 WhatsApp Support Group
                          if (course.supportType == 'WhatsApp Group') ...[
                            _buildBadge(
                              icon: FontAwesomeIcons.whatsapp,
                              label: 'WhatsApp Support Group',
                              color: const Color(0xFF25D366),
                            ),
                          ],
    
                          // Videos is the last one now
                          _buildBadge(
                            icon: Icons.video_library,
                            label: '${course.totalVideos} Videos',
                            color: const Color(0xFF536DFE),
                          ),
                        ],
                      ),
    
                      const SizedBox(height: 12),
    
                      // 🏷️ Title
                      Text(
                        course.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                          letterSpacing: 0.1,
                          height: 1.0,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
    
                      const SizedBox(height: 6),
    
                      // ➖ Divider (Match Grey)
                      Divider(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                        thickness: 1,
                        height: 1,
                      ),
    
                      const SizedBox(height: 6),
    
                      // 💰 Pricing & Button
                      Row(
                        children: [
                          // Pricing Info (Auto-Fit)
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  // Bold Selling Price
                                  Text(
                                    '₹${sellingPrice.toInt()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  if (discountPercent > 0) ...[
                                    const SizedBox(width: 12),
                                    // Red Strikethrough (MRP)
                                    Text(
                                      '₹${originalPrice.toInt()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: const Color(0xFFFF5252),
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor:
                                            const Color(0xFFFF5252),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Neon Green Discount
                                    Text(
                                      '$discountPercent % Off',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: const Color(0xFF00E676),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
    
                          const SizedBox(width: 8),
    
                          // 💰 Pricing & Button/Status
                          if (course.isPublished)
                            SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: onTap ??
                                    () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CourseDetailScreen(
                                                course: course),
                                          ),
                                        ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF536DFE),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(3.0),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'See More',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 36,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              child: Text(
                                'DRAFT',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
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
        // 🛠️ Ultra-Realistic 3D Screwdriver & Screw Animation (Full Sweep)
        if (course.isSpecialTagVisible &&
            course.specialTag.isNotEmpty &&
            (course.specialTagDurationDays == 0 ||
                (course.createdAt != null &&
                    DateTime.now().difference(course.createdAt!).inDays <
                        course.specialTagDurationDays)))
          Positioned(
            top: 20,
            left: -8,
            child: _buildScrewdriverTag(
              course.specialTag,
              course.specialTagColor,
            ),
          ),
      ],
    );
  }

  Widget _buildScrewdriverTag(String label, String colorName) {
    final colors = _getHandleColors(colorName);
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(4, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🔩 Rotating Screw (Spinning Cylinder Effect)
          _buildRotatingScrew()
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
                duration: 600.ms,
                color: Colors.white.withOpacity(0.5),
                angle: 3.14 / 2, // Vertical sweep simulates cylinder spin
              ),

          // 🔧 Precision Gold Bit (Balanced Size)
          Container(
            width: 28,
            height: 5.0, 
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF5D4037), // Dark Bronze Edge
                  const Color(0xFFFFD700), // Gold
                  const Color(0xFFFFF176), // Bright Highlight
                  const Color(0xFFFFD700), // Gold
                  const Color(0xFF5D4037), // Dark Bronze Edge
                ],
                stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
                duration: 600.ms,
                color: Colors.white,
                angle: 3.14 / 2, // Vertical sweep simulates cylinder spin
                size: 0.3, 
              ),

          // 🔧 Tapered Metal Chuck (Medium Size)
          Container(
            width: 16,
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade400, Colors.white, Colors.grey.shade400, Colors.grey.shade800],
                stops: const [0.0, 0.3, 0.6, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                bottomLeft: Radius.circular(2),
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
              border: Border.all(color: Colors.black.withOpacity(0.4), width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (i) => Container(width: 1, height: 10, color: Colors.black26)),
            ),
          ),

          // 🔧 PREMIUM HD HANDLE (Medium Size)
          Container(
            height: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHDHandleSegment(
                  width: 32,
                  height: 32,
                  isFinned: true,
                  colors: colors,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(9), bottomLeft: Radius.circular(9)),
                ),
                
                // Laser-Engraved Branding Plate
                Container(
                  height: 25, // Adjusted size
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: _premiumHandleDecoration(colors).copyWith(
                    border: Border.all(color: Colors.white24, width: 0.5), // Restored thickness
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13.5, // Even Bigger
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 1.0, 
                      shadows: [
                        const Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(1, 1))
                      ],
                    ),
                  ),
                ),

                // Silver Neck Section
                Container(
                  width: 24,
                  height: 20,
                  decoration: _premiumHandleDecoration(colors),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSilverRing(height: 20),
                      _buildSilverRing(height: 20),
                    ],
                  ),
                ),

                // Cog Tail Cap
                Container(
                  width: 20,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                    ),
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(9), bottomRight: Radius.circular(9)),
                    border: Border.all(color: Colors.white30, width: 0.8),
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.8),
                        boxShadow: [
                          BoxShadow(color: Colors.blue.shade200, blurRadius: 3, spreadRadius: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ).animate(onPlay: (controller) => controller.repeat())
             .shimmer(duration: 3.seconds, delay: 1.seconds, color: Colors.white24, angle: 1.0),
          ),
        ],
      ),
    );
  }

  Widget _buildSilverRing({double height = 22}) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade400, Colors.white, Colors.grey.shade700],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildHDHandleSegment({required double width, required double height, required List<Color> colors, bool isFinned = false, BorderRadius? borderRadius}) {
    return Container(
      width: width,
      height: height,
      decoration: _premiumHandleDecoration(colors).copyWith(borderRadius: borderRadius),
      child: isFinned ? Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) => Container(
          width: 2.5,
          height: height * 0.7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.5), Colors.transparent, Colors.black.withOpacity(0.5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        )),
      ) : null,
    );
  }

  BoxDecoration _premiumHandleDecoration(List<Color> colors) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ),
      border: Border.symmetric(horizontal: BorderSide(color: Colors.black.withOpacity(0.4), width: 0.6)),
    );
  }

  List<Color> _getHandleColors(String colorName) {
    switch (colorName) {
      case 'Red':
        return [
          const Color(0xFF5C0002), // Darkest
          const Color(0xFFB71C1C), // Dark
          const Color(0xFFFF5252), // Light (Highlight)
          const Color(0xFFB71C1C), // Dark
          const Color(0xFF3F0000), // Darkest
        ];
      case 'Green':
        return [
          const Color(0xFF003300), 
          const Color(0xFF1B5E20), 
          const Color(0xFF66BB6A), 
          const Color(0xFF1B5E20), 
          const Color(0xFF001B00), 
        ];
      case 'Pink':
        return [
          const Color(0xFF4A0030), 
          const Color(0xFF880E4F), 
          const Color(0xFFFF4081), 
          const Color(0xFF880E4F), 
          const Color(0xFF300020), 
        ];
      case 'Blue':
      default:
        return [
          const Color(0xFF001429),
          const Color(0xFF004C99),
          const Color(0xFF42A5F5),
          const Color(0xFF004C99),
          const Color(0xFF000814),
        ];
    }
  }

  Widget _buildRotatingScrew() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 🔩 Tapered Saw-Tooth Threads (Thinner)
        Container(
          height: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSawToothThread(height: 2, width: 3), // Acts as tip
              _buildSawToothThread(height: 3, width: 3),
              _buildSawToothThread(height: 4, width: 3),
              _buildSawToothThread(height: 6, width: 3),
              _buildSawToothThread(height: 7, width: 3),
            ],
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 600.ms, 
          color: Colors.white.withOpacity(0.7), 
          angle: 1.0, 
        ),

        // 🔩 Screw Neck (Thinner)
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade400, Colors.white, Colors.grey.shade600],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 600.ms, angle: 3.14/2, color: Colors.white.withOpacity(0.5)),

        // 🔩 Realistic Chrome Flat Head (Thinner Profile)
        Container(
          width: 5, // Thinner head disk
          height: 12,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              radius: 0.8,
              colors: [
                Colors.white,
                Colors.white,
                Colors.grey.shade200, // Very light shading
                Colors.grey.shade400, // Subtle edge
              ],
            ),
            borderRadius: BorderRadius.circular(1.5),
            border: Border.all(color: Colors.black26, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 3,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 1.5,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(0.5),
              ),
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 600.ms, angle: 3.14/2, color: Colors.white.withOpacity(0.5)),
      ],
    );
  }

  Widget _buildSawToothThread({required double height, double width = 4}) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 0.4),
      child: Transform.rotate(
        angle: 0.2, // Tilted thread look
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade700,
                Colors.white,
                Colors.grey.shade500,
                Colors.grey.shade800,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  Widget _buildMachineThread() {
    return Container(
      width: 4,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 0.2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade600,
            Colors.white,
            Colors.grey.shade400,
            Colors.grey.shade700,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildGripGrooves() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        2,
        (i) => Container(
          width: 3,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10.2, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 11.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// 📐 Triangle Clipper for Screw Tip
class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(TriangleClipper oldClipper) => false;
}
