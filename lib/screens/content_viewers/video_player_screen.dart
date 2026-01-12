import 'dart:io';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import '../../utils/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final bool isNetwork;

  const VideoPlayerScreen({super.key, required this.videoPath, this.isNetwork = false});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late FlickManager flickManager;
  bool _isLoading = true;
  double _volumeValue = 0.5;
  double _brightnessValue = 0.5;
  bool _showOverlay = false;
  String? _overlayLabel;
  IconData? _overlayIcon;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _initSettings();
  }

  Future<void> _initSettings() async {
    try {
      _brightnessValue = await ScreenBrightness().current;
      double? volume = await FlutterVolumeController.getVolume();
      if (volume != null) _volumeValue = volume;
    } catch (e) {
      debugPrint("Error getting initial settings: $e");
    }
  }

  void _initializePlayer() {
    VideoPlayerController controller;
    if (widget.isNetwork) {
      controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath));
    } else {
      controller = VideoPlayerController.file(File(widget.videoPath));
    }

    flickManager = FlickManager(
      videoPlayerController: controller,
      autoPlay: true,
    );
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    flickManager.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, Size size) {
    double delta = -details.primaryDelta! / size.height;
    if (details.localPosition.dx < size.width / 2) {
      // Brightness (Left side)
      _brightnessValue = (_brightnessValue + delta).clamp(0.0, 1.0);
      ScreenBrightness().setScreenBrightness(_brightnessValue);
      _showTempOverlay("Brightness", Icons.wb_sunny_rounded, _brightnessValue);
    } else {
      // Volume (Right side)
      _volumeValue = (_volumeValue + delta).clamp(0.0, 1.0);
      FlutterVolumeController.setVolume(_volumeValue);
      _showTempOverlay("Volume", Icons.volume_up_rounded, _volumeValue);
    }
  }

  void _showTempOverlay(String label, IconData icon, double value) {
    setState(() {
      _showOverlay = true;
      _overlayLabel = "${(value * 100).toInt()}%";
      _overlayIcon = icon;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  GestureDetector(
                    onVerticalDragUpdate: (details) => _onVerticalDragUpdate(details, constraints.biggest),
                    onDoubleTapDown: (details) {
                        final dx = details.localPosition.dx;
                        final width = constraints.biggest.width;
                        if (dx < width / 3) {
                          // Rewind
                          flickManager.flickControlManager?.seekBackward(const Duration(seconds: 10));
                          _showTempOverlay("Rewind", Icons.fast_rewind, 0);
                        } else if (dx > width * 2/3) {
                          // Fast forward
                          flickManager.flickControlManager?.seekForward(const Duration(seconds: 10));
                          _showTempOverlay("Forward", Icons.fast_forward, 0);
                        }
                    },
                    child: FlickVideoPlayer(
                      flickManager: flickManager,
                      flickVideoWithControls: FlickVideoWithControls(
                        controls: FlickPortraitControls(
                          progressBarSettings: FlickProgressBarSettings(
                            playedColor: AppTheme.primaryColor,
                            handleColor: AppTheme.primaryColor,
                            height: 4,
                          ),
                        ),
                        videoFit: BoxFit.contain,
                      ),
                      flickVideoWithControlsFullscreen: const FlickVideoWithControls(
                        controls: FlickLandscapeControls(),
                        videoFit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Center Overlay for Gestures
                  if (_showOverlay)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_overlayIcon, color: Colors.white, size: 40),
                          const SizedBox(height: 8),
                          Text(_overlayLabel ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  
                  // Top Controls
                  Positioned(
                    top: 40,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.black45,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const Spacer(),
                        _buildSpeedButton(),
                      ],
                    ),
                  ),
                ],
              );
            }
          ),
    );
  }

  Widget _buildSpeedButton() {
     return PopupMenuButton<double>(
        icon: const CircleAvatar(
          backgroundColor: Colors.black45,
          child: Icon(Icons.speed, color: Colors.white),
        ),
        onSelected: (speed) {
          flickManager.flickVideoManager?.videoPlayerController?.setPlaybackSpeed(speed);
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 0.5, child: Text('0.5x')),
          const PopupMenuItem(value: 1.0, child: Text('Normal')),
          const PopupMenuItem(value: 1.5, child: Text('1.5x')),
          const PopupMenuItem(value: 2.0, child: Text('2.0x')),
        ],
     );
  }
}
