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

  VideoGestureHandler({
    required this.volumeNotifier,
    required this.brightnessNotifier,
    required this.showVolumeLabelNotifier,
    required this.showBrightnessLabelNotifier,
  });

  void handleVerticalDrag(DragUpdateDetails details, double screenWidth) {
    final dx = details.localPosition.dx;
    final delta = details.primaryDelta ?? 0;
    if (delta.abs() < 0.5) return;

    final double sensitivity = VideoPlayerConstants.gestureSensitivity;
    if (dx > screenWidth / 2) {
      _updateVolume(delta, sensitivity);
    } else {
      _updateBrightness(delta, sensitivity);
    }
  }

  void _updateVolume(double delta, double sensitivity) {
    double newVolume = volumeNotifier.value - (delta * sensitivity);
    newVolume = newVolume.clamp(0.0, 1.0);
    
    if ((newVolume - volumeNotifier.value).abs() > 0.01 || newVolume == 0 || newVolume == 1) {
      volumeNotifier.value = newVolume;
      isChangingVolumeViaGesture = true;
      FlutterVolumeController.setVolume(newVolume);
      showVolumeLabelNotifier.value = true;
      showBrightnessLabelNotifier.value = false;
      
      _volumeTimer?.cancel();
      _volumeTimer = Timer(VideoPlayerConstants.labelHideDuration, () {
        isChangingVolumeViaGesture = false;
        showVolumeLabelNotifier.value = false;
      });
    }
  }

  void _updateBrightness(double delta, double sensitivity) {
    double newBrightness = brightnessNotifier.value - (delta * sensitivity);
    newBrightness = newBrightness.clamp(0.0, 1.0);
    
    if ((newBrightness - brightnessNotifier.value).abs() > 0.01 || newBrightness == 0 || newBrightness == 1) {
      brightnessNotifier.value = newBrightness;
      ScreenBrightness().setScreenBrightness(newBrightness);
      showBrightnessLabelNotifier.value = true;
      showVolumeLabelNotifier.value = false;
      
      _brightnessTimer?.cancel();
      _brightnessTimer = Timer(VideoPlayerConstants.labelHideDuration, () {
        showBrightnessLabelNotifier.value = false;
      });
    }
  }

  void dispose() {
    _volumeTimer?.cancel();
    _brightnessTimer?.cancel();
  }
}
