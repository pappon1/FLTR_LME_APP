import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/course_model.dart';
import '../services/bunny_cdn_service.dart';
import '../screens/courses/course_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/app_theme.dart';

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

  // Final Fixed Offsets for Badges
  static const Map<String, double> finalOffsets = {
    'videos': -9.4,
    'category': 7.5,
    'difficulty': 6.4,
    'language': 4.7,
    'mode': 4.5,
    'certificate': -9.5,
    'validity': 12.1,
    'offline': 13.8,
    'web': -6.2,
    'whatsapp': 8.4,
    'demo': 9.0,
  };

  static const Map<String, List<Color>> _handleColorPresets = {
    'Red': [
      Color(0xFF5C0002), // Darkest
      Color(0xFFB71C1C), // Dark
      Color(0xFFFF5252), // Light (Highlight)
      Color(0xFFB71C1C), // Dark
      Color(0xFF3F0000), // Darkest
    ],
    'Green': [
      Color(0xFF003300),
      Color(0xFF1B5E20),
      Color(0xFF66BB6A),
      Color(0xFF1B5E20),
      Color(0xFF001B00),
    ],
    'Pink': [
      Color(0xFF4A0030),
      Color(0xFF880E4F),
      Color(0xFFFF4081),
      Color(0xFF880E4F),
      Color(0xFF300020),
    ],
    'Blue': [
      Color(0xFF001429),
      Color(0xFF004C99),
      Color(0xFF42A5F5),
      Color(0xFF004C99),
      Color(0xFF000814),
    ],
  };

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
        RepaintBoundary(
          child: Card(
            margin: EdgeInsets.only(
              top: (course.isSpecialTagVisible && course.specialTag.isNotEmpty)
                  ? 15
                  : 0,
              bottom: bottomMargin ?? 20,
              left: customHorizontalMargin ?? (isEdgeToEdge ? 0 : 16),
              right: customHorizontalMargin ?? (isEdgeToEdge ? 0 : 16),
            ),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: isDark
                ? const Color(0xFF000000)
                : Colors.white, // Deep Black
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
              onTap:
                  onTap ??
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CourseDetailScreen(course: course),
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
                        color: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade200,
                      ),
                      child: _CourseThumbnail(thumbnailUrl: course.thumbnailUrl, isDark: isDark),
                    ),
                  ),

                  // 📝 Content
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 0,
                      top: 12,
                      bottom: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✨ Badges Row (Sequential Zoom Animation)
                        RepaintBoundary(
                          child: _BadgeRow(course: course),
                        ),

                        // Add 15px right padding back for subsequent elements (Title, Price, etc.)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              ),
                            ],
                          ),
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
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
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
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationColor: const Color(
                                            0xFFFF5252,
                                          ),
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
                                  onPressed:
                                      onTap ??
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CourseDetailScreen(
                                            course: course,
                                          ),
                                        ),
                                      ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF536DFE),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
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
        ),
        // 🛠️ Ultra-Realistic 3D Screwdriver & Screw Animation (Full Sweep)
        if (course.isSpecialTagVisible &&
            course.specialTag.isNotEmpty &&
            (course.specialTagDurationDays == 0 ||
                (course.createdAt != null &&
                    DateTime.now().difference(course.createdAt!).inDays <
                        course.specialTagDurationDays)))
          Positioned(
            top: -12,
            right: 0,
            child: _ScrewdriverTagAnimation(
              label: course.specialTag,
              colorName: course.specialTagColor,
            ),
          ),
      ],
    );
  }
}

/// 🖼️ Optimized Thumbnail Widget
class _CourseThumbnail extends StatelessWidget {
  final String thumbnailUrl;
  final bool isDark;

  const _CourseThumbnail({required this.thumbnailUrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final signedUrl = BunnyCDNService.signUrl(thumbnailUrl);
    final isStorageUrl = signedUrl.contains('storage.bunnycdn.com');

    return CachedNetworkImage(
      imageUrl: signedUrl,
      httpHeaders: isStorageUrl ? const {'AccessKey': BunnyCDNService.apiKey} : null,
      fit: BoxFit.cover,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Container(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 48,
        ),
      ),
    );
  }
}

/// ✨ Optimized Badge Row Widget
class _BadgeRow extends StatelessWidget {
  final CourseModel course;

  const _BadgeRow({required this.course});

  @override
  Widget build(BuildContext context) {
    final List<_BadgeData> badgeData = _generateBadgeData();

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(badgeData.length, (index) {
        final data = badgeData[index];
        final double offset = CourseCard.finalOffsets[data.id] ?? 0.0;

        return _CourseBadge(
          icon: data.icon,
          label: data.label,
          color: data.color,
          index: index,
          totalCount: badgeData.length,
          extraPadding: data.extraPadding.add(EdgeInsets.only(left: offset)),
        );
      }),
    );
  }

  List<_BadgeData> _generateBadgeData() {
    final List<_BadgeData> data = [];

    // 🎥 Videos First
    data.add(_BadgeData(
      id: 'videos',
      icon: Icons.video_library,
      label: '${course.totalVideos} Videos',
      color: const Color(0xFF536DFE),
    ));

    if (course.category.isNotEmpty) {
      data.add(_BadgeData(
        id: 'category',
        icon: Icons.category,
        label: course.category,
        color: course.category.toLowerCase() == 'hardware' ? Colors.white : const Color(0xFF3F51B5),
      ));
    }

    if (course.difficulty.isNotEmpty) {
      data.add(_BadgeData(
        id: 'difficulty',
        icon: Icons.signal_cellular_alt,
        label: course.difficulty,
        color: course.difficulty.toLowerCase() == 'advanced' ? Colors.amberAccent : const Color(0xFF795548),
      ));
    }

    data.add(_BadgeData(
      id: 'language',
      icon: Icons.language,
      label: course.language,
      color: const Color(0xFF9C27B0),
    ));

    data.add(_BadgeData(
      id: 'mode',
      icon: course.courseMode.toLowerCase().contains('live') ? Icons.sensors : Icons.play_circle_outline,
      label: course.courseMode,
      color: const Color(0xFFFF5722),
    ));

    if (course.hasCertificate) {
      data.add(_BadgeData(
        id: 'certificate',
        icon: Icons.workspace_premium,
        label: 'Certificate',
        color: const Color(0xFFFF5252),
      ));
    }

    data.add(_BadgeData(
      id: 'validity',
      icon: Icons.history_toggle_off,
      label: _getValidityText(course.courseValidityDays),
      color: const Color(0xFF00BCD4),
    ));

    if (course.isOfflineDownloadEnabled) {
      data.add(_BadgeData(
        id: 'offline',
        icon: Icons.download_for_offline,
        label: 'Offline Access',
        color: const Color(0xFF009688),
      ));
    }

    if (course.isBigScreenEnabled) {
      data.add(_BadgeData(
        id: 'web',
        icon: Icons.devices,
        label: 'Web/PC Access',
        color: const Color(0xFF03A9F4),
      ));
    }

    if (course.supportType == 'WhatsApp Group') {
      data.add(_BadgeData(
        id: 'whatsapp',
        icon: FontAwesomeIcons.whatsapp,
        label: 'WhatsApp Support Group',
        color: const Color(0xFF25D366),
        extraPadding: const EdgeInsets.only(left: 11),
      ));
    }

    data.add(_BadgeData(
      id: 'demo',
      icon: Icons.play_lesson,
      label: 'Demo',
      color: const Color(0xFFE91E63),
      extraPadding: const EdgeInsets.only(left: 5),
    ));

    return data;
  }

  String _getValidityText(int days) {
    if (days == 0) return 'Lifetime Access';
    if (days == 184) return '6 Months';
    if (days == 365) return '1 Year';
    if (days == 730) return '2 Years';
    if (days == 1095) return '3 Years';
    return '$days Days';
  }
}

class _BadgeData {
  final String id;
  final IconData icon;
  final String label;
  final Color color;
  final EdgeInsets extraPadding;

  const _BadgeData({
    required this.id,
    required this.icon,
    required this.label,
    required this.color,
    this.extraPadding = EdgeInsets.zero,
  });
}

/// 🏅 Optimized Individual Badge Widget
class _CourseBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int index;
  final int totalCount;
  final EdgeInsetsGeometry extraPadding;

  const _CourseBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.index,
    required this.totalCount,
    required this.extraPadding,
  });

  @override
  Widget build(BuildContext context) {
    const singleZoomDuration = 300;
    const totalBadgeTime = singleZoomDuration * 2;
    const postCycleIdle = 1000;
    final totalCycleDuration = (totalCount * totalBadgeTime) + postCycleIdle;

    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2).add(extraPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 7.2, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 8.2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      )
      .animate(onPlay: (controller) => controller.repeat())
      .then(delay: (index * totalBadgeTime).ms)
      .scale(
        begin: const Offset(1, 1),
        end: const Offset(1.25, 1.25),
        duration: singleZoomDuration.ms,
        curve: Curves.easeInOut,
      )
      .then()
      .scale(
        begin: const Offset(1.25, 1.25),
        end: const Offset(1, 1),
        duration: singleZoomDuration.ms,
        curve: Curves.easeInOut,
      )
      .then(
        delay: (totalCycleDuration - (index * totalBadgeTime) - totalBadgeTime).ms,
      )
      .custom(
        duration: 1.ms,
        builder: (context, value, child) => child,
      ),
    );
  }
}

/// 🛠️ Optimized Screwdriver Tag Animation Wrapper
class _ScrewdriverTagAnimation extends StatelessWidget {
  final String label;
  final String colorName;

  const _ScrewdriverTagAnimation({required this.label, required this.colorName});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _ScrewdriverTag(label: label, colorName: colorName)
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveX(
            begin: 140,
            end: -260,
            duration: 4.seconds,
            curve: Curves.linear,
          ),
    );
  }
}

/// 🛠️ Optimized Screwdriver Tag Widget
class _ScrewdriverTag extends StatelessWidget {
  final String label;
  final String colorName;

  const _ScrewdriverTag({required this.label, required this.colorName});

  @override
  Widget build(BuildContext context) {
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
          const RepaintBoundary(child: _RotatingScrewAnimation()),
          const RepaintBoundary(child: _PrecisionGoldBit()),
          const _TaperedMetalChuck(),
          _PremiumHDHandle(label: label, colorName: colorName),
        ],
      ),
    );
  }
}

class _RotatingScrewAnimation extends StatelessWidget {
  const _RotatingScrewAnimation();

  @override
  Widget build(BuildContext context) {
    return const _RotatingScrew()
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 400.ms,
          color: Colors.white.withOpacity(0.8),
          angle: 3.14 / 2,
        )
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.1, 1.1),
          duration: 200.ms,
        );
  }
}

class _RotatingScrew extends StatelessWidget {
  const _RotatingScrew();

  @override
  Widget build(BuildContext context) {
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
                  const _SawToothThread(height: 2), // Acts as tip
                  const _SawToothThread(height: 3),
                  const _SawToothThread(height: 4),
                  const _SawToothThread(height: 6),
                  const _SawToothThread(height: 7),
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
                  colors: [
                    Colors.grey.shade400,
                    Colors.white,
                    Colors.grey.shade600,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              duration: 600.ms,
              angle: 3.14 / 2,
              color: Colors.white.withOpacity(0.5),
            ),

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
            .shimmer(
              duration: 600.ms,
              angle: 3.14 / 2,
              color: Colors.white.withOpacity(0.5),
            ),
      ],
    );
  }
}

class _SawToothThread extends StatelessWidget {
  final double height;
  const _SawToothThread({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 0.4),
      child: Transform.rotate(
        angle: 0.2,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade700, Colors.white, Colors.grey.shade500, Colors.grey.shade800],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

class _ScrewNeck extends StatelessWidget {
  const _ScrewNeck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade400, Colors.white, Colors.grey.shade600],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _ChromeFlatHead extends StatelessWidget {
  const _ChromeFlatHead();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 12,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 0.8,
          colors: [Colors.white, Colors.white, Colors.grey.shade200, Colors.grey.shade400],
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
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(0.5)),
        ),
      ),
    );
  }
}

class _PrecisionGoldBit extends StatelessWidget {
  const _PrecisionGoldBit();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 5.0,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5D4037), Color(0xFFFFD700), Color(0xFFFFF176), Color(0xFFFFD700), Color(0xFF5D4037)],
          stops: [0.0, 0.3, 0.5, 0.7, 1.0],
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
    );
  }
}

class _TaperedMetalChuck extends StatelessWidget {
  const _TaperedMetalChuck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 12,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade400,
            Colors.white,
            Colors.grey.shade400,
            Colors.grey.shade800,
          ],
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
        border: Border.all(
          color: Colors.black.withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4,
          (i) => Container(width: 1, height: 10, color: Colors.black26),
        ),
      ),
    );
  }
}

class _PremiumHDHandle extends StatelessWidget {
  final String label;
  final String colorName;
  const _PremiumHDHandle({required this.label, required this.colorName});

  BoxDecoration _premiumHandleDecoration(List<Color> colors) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ),
      border: Border.symmetric(
        horizontal: BorderSide(
          color: Colors.black.withOpacity(0.4),
          width: 0.6,
        ),
      ),
    );
  }

  Widget _buildHDHandleSegment({
    required double width,
    required double height,
    required List<Color> colors,
    bool isFinned = false,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: _premiumHandleDecoration(
        colors,
      ).copyWith(borderRadius: borderRadius),
      child: isFinned
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (i) => Container(
                  width: 2.5,
                  height: height * 0.7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            )
          : null,
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

  @override
  Widget build(BuildContext context) {
    final colors = CourseCard._handleColorPresets[colorName] ?? CourseCard._handleColorPresets['Blue']!;

    return RepaintBoundary(
      child: Container(
        height: 36,
        child:
            Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHDHandleSegment(
                      width: 32,
                      height: 32,
                      isFinned: true,
                      colors: colors,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(9),
                        bottomLeft: Radius.circular(9),
                      ),
                    ),

                    // Laser-Engraved Branding Plate
                    Container(
                      height: 25, // Adjusted size
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: _premiumHandleDecoration(colors)
                          .copyWith(
                            border: Border.all(
                              color: Colors.white24,
                              width: 0.5,
                            ), // Restored thickness
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
                            const Shadow(
                              color: Colors.black87,
                              blurRadius: 3,
                              offset: Offset(1, 1),
                            ),
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
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(9),
                          bottomRight: Radius.circular(9),
                        ),
                        border: Border.all(
                          color: Colors.white30,
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade200,
                                blurRadius: 3,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(
                  duration: 3.seconds,
                  delay: 1.seconds,
                  color: Colors.white24,
                  angle: 1.0,
                ),
      ),
    );
  }
}

/// 📐 Triangle Clipper for Screw Tip
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
