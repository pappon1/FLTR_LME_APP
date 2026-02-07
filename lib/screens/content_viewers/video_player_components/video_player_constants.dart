import 'package:flutter/material.dart';

class VideoPlayerConstants {
  // Durations
  static const Duration autoHideDuration = Duration(seconds: 4);
  static const Duration trayAutoHideDuration = Duration(seconds: 4);
  static const Duration lockAutoHideDuration = Duration(seconds: 1);
  static const Duration labelHideDuration = Duration(seconds: 2);
  static const Duration seekAfterDragDelay = Duration(milliseconds: 700);
  static const Duration orientationChangeOverlayDelay = Duration(
    milliseconds: 50,
  );
  static const Duration orientationRotationDuration = Duration(
    milliseconds: 600,
  );
  static const Duration scrollAnimationDuration = Duration(milliseconds: 300);

  // Values & Thresholds
  static const double gestureSensitivity = 0.01;
  static const double sensorRotationThreshold = 5.0;
  static const double significantProgressChange = 0.005;
  static const double watchedThreshold = 0.90;
  static const double completionThreshold = 0.99;
  static const double defaultVolume = 0.5;
  static const double defaultBrightness = 0.5;

  // Colors
  static const Color primaryAccentColor = Color(0xFF22C55E); // Green
  static const Color overlayDimColor = Colors.black54;
  static const Color trayBackgroundColor = Color(0xF2000000); // Black 95%
  static const Color iconActiveColor = Color(0xFF22C55E);
  static const Color iconInactiveColor = Colors.white;
}
