import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'video_player_constants.dart';

class VideoGestureHandler {
  final ValueNotifier<double> volumeNotifier;
  final ValueNotifier<double> brightnessNotifier;
  final ValueNotifier<bool> showVolumeLabelNotifier;
  final ValueNotifier<bool> showBrightnessLabelNotifier;

  Timer? _volumeTimer;
  Timer? _brightnessTimer;
  bool isChangingVolumeViaGesture = false;

  // Point 6: Gesture Slop (Accidental touch protection)
  double _cumulativeDelta = 0;
  bool _hasPassedThreshold = false;
  static const double _dragThreshold = 15.0; // pixels

  VideoGestureHandler({
    required this.volumeNotifier,
    required this.brightnessNotifier,
    required this.showVolumeLabelNotifier,
    required this.showBrightnessLabelNotifier,
  });

  // Point 6: Gesture Locking
  bool? _isVolumeGesture;

  void handleVerticalDragStart(double x, double screenWidth) {
    _cumulativeDelta = 0;
    _hasPassedThreshold = false;
    // Lock the gesture type at the start: Right side = Volume, Left = Brightness
    _isVolumeGesture = x > screenWidth / 2;
  }

  void handleVerticalDrag(DragUpdateDetails details, double screenWidth) {
    if (!_hasPassedThreshold) {
      _cumulativeDelta += (details.primaryDelta ?? 0).abs();
      if (_cumulativeDelta > _dragThreshold) {
        _hasPassedThreshold = true;
      } else {
        return; // Ignore small movements
      }
    }

    final delta = details.primaryDelta ?? 0;
    if (delta.abs() < 0.2) return;

    const double sensitivity = VideoPlayerConstants.gestureSensitivity;
    
    // Strict Lock Check
    if (_isVolumeGesture == true) {
      _updateVolume(delta, sensitivity);
    } else {
      _updateBrightness(delta, sensitivity);
    }
  }

  // Platform Channel Throttling
  int _lastVolumeUpdateTimestamp = 0;
  int _lastBrightnessUpdateTimestamp = 0;
  static const int _updateIntervalMs = 40; // ~25 updates per second max (Human ear/eye limit)

  void _updateVolume(double delta, double sensitivity) {
    double newVolume = volumeNotifier.value - (delta * sensitivity);
    newVolume = newVolume.clamp(0.0, 1.0);
    
    // 1. Update UI Instantly (Zero Lags for User Eyes)
    volumeNotifier.value = newVolume;
    showVolumeLabelNotifier.value = true;
    showBrightnessLabelNotifier.value = false;
    isChangingVolumeViaGesture = true;

    // 2. Throttle System Calls (Save CPU for Video Rendering)
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastVolumeUpdateTimestamp > _updateIntervalMs || newVolume == 0.0 || newVolume == 1.0) {
       _lastVolumeUpdateTimestamp = now;
       FlutterVolumeController.setVolume(newVolume);
    }
      
    _volumeTimer?.cancel();
    _volumeTimer = Timer(VideoPlayerConstants.labelHideDuration, () {
      isChangingVolumeViaGesture = false;
      showVolumeLabelNotifier.value = false;
      // Ensure final sync
      FlutterVolumeController.setVolume(volumeNotifier.value);
    });
  }

  void _updateBrightness(double delta, double sensitivity) {
    double newBrightness = brightnessNotifier.value - (delta * sensitivity);
    newBrightness = newBrightness.clamp(0.0, 1.0);
    
    // 1. Update UI Instantly
    brightnessNotifier.value = newBrightness;
    showBrightnessLabelNotifier.value = true;
    showVolumeLabelNotifier.value = false;
    
    // 2. Throttle System Calls
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBrightnessUpdateTimestamp > _updateIntervalMs || newBrightness == 0.0 || newBrightness == 1.0) {
       _lastBrightnessUpdateTimestamp = now;
       ScreenBrightness().setApplicationScreenBrightness(newBrightness);
    }
      
    _brightnessTimer?.cancel();
    _brightnessTimer = Timer(VideoPlayerConstants.labelHideDuration, () {
      showBrightnessLabelNotifier.value = false;
      // Ensure final sync
      ScreenBrightness().setApplicationScreenBrightness(brightnessNotifier.value);
    });
  }

  void handleVerticalDragEnd() {
    // Reset flags if needed, or hide labels after a delay
    _isVolumeGesture = null;
  }

  void dispose() {
    _volumeTimer?.cancel();
    _brightnessTimer?.cancel();
  }
}

