import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'video_gesture_overlay.dart';
import 'video_center_controls.dart';
import 'video_seekbar.dart';
import 'video_bottom_controls.dart';
import 'video_playlist_widget.dart';
import 'video_tray.dart';
import 'video_top_bar.dart';
import 'video_error_overlay.dart';

class VideoPlayerPortraitLayout extends StatelessWidget {
  final Size size;
  final double videoHeight;
  final bool isLocked;
  final bool isUnlockControlsVisible;
  final bool showControls;
  final VideoController controller;
  final String currentTitle;
  
  // Gestures
  final VoidCallback onLockedTap;
  final VoidCallback onToggleControls;
  final Function(DragUpdateDetails) onVerticalDragUpdate;
  
  // Overlay
  final bool showBrightnessLabel;
  final bool showVolumeLabel;
  final double brightness;
  final double volume;
  
  // Center Controls
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final Function(int) onSeekRelative;
  
  // Seekbar
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<Duration> durationNotifier;
  final Function(double) onSeekbarChangeStart;
  final Function(double) onSeekbarChanged;
  final Function(double) onSeekbarChangeEnd;
  
  // Bottom Controls
  final double playbackSpeed;
  final String currentSubtitle;
  final String currentQuality;
  final String? activeTray;
  final Function(String) onToggleTray;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleOrientation;
  final VoidCallback onResetSpeed;
  final VoidCallback onResetSubtitle;
  final VoidCallback onResetQuality;
  
  // Tray
  final List<String> trayItems;
  final String trayCurrentSelection;
  final bool isDraggingSpeedSlider;
  final Function(String) onTrayItemSelected;
  final Function(double) onTraySpeedChanged;
  final VoidCallback onTrayClose;
  final VoidCallback onTrayInteraction;

  // Playlist
  final List<Map<String, dynamic>> playlist;
  final int currentIndex;
  final Map<String, double> videoProgress;
  final Function(int) onVideoTap;
  
  final VoidCallback onBack;
  final VoidCallback onDoubleLockTap;

  const VideoPlayerPortraitLayout({
    super.key,
    required this.size,
    required this.videoHeight,
    required this.isLocked,
    required this.isUnlockControlsVisible,
    required this.showControls,
    required this.controller,
    required this.currentTitle,
    required this.onLockedTap,
    required this.onToggleControls,
    required this.onVerticalDragUpdate,
    required this.showBrightnessLabel,
    required this.showVolumeLabel,
    required this.brightness,
    required this.volume,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeekRelative,
    required this.positionNotifier,
    required this.durationNotifier,
    required this.onSeekbarChangeStart,
    required this.onSeekbarChanged,
    required this.onSeekbarChangeEnd,
    required this.playbackSpeed,
    required this.currentSubtitle,
    required this.currentQuality,
    this.activeTray,
    required this.onToggleTray,
    required this.onToggleLock,
    required this.onToggleOrientation,
    required this.onResetSpeed,
    required this.onResetSubtitle,
    required this.onResetQuality,
    required this.trayItems,
    required this.trayCurrentSelection,
    required this.isDraggingSpeedSlider,
    required this.onTrayItemSelected,
    required this.onTraySpeedChanged,
    required this.onTrayClose,
    required this.onTrayInteraction,
    required this.playlist,
    required this.currentIndex,
    required this.videoProgress,
    required this.onVideoTap,
    required this.onBack,
    required this.onDoubleLockTap,
    this.errorMessage,
    this.onRetry,
  });

  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isInterfaceVisible = isLocked ? isUnlockControlsVisible : showControls;

    return Column(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              VideoPlayerTopBar(
                title: currentTitle,
                isLocked: isLocked,
                isVisible: true, // Always visible logic in portrait? (Code said: opacity: _isLocked ? 0.5 : 1.0)
                onBack: onBack,
              ),

              // Video Player Area
              SizedBox(
                width: size.width,
                height: videoHeight,
                child: Stack(
                  children: [
                    Video(controller: controller, controls: (state) => const SizedBox()),

                    // Locked Dark Overlay
                    if (isLocked)
                      Positioned.fill(
                        child: Container(color: Colors.black54),
                      ),

                    // Gesture Detector
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (isLocked) {
                            onLockedTap();
                          } else {
                            onToggleControls();
                          }
                        },
                        onVerticalDragUpdate: isLocked ? null : onVerticalDragUpdate,
                        onHorizontalDragUpdate: (details) {},
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // Volume/Brightness Overlay
                    Positioned.fill(
                      child: VideoGestureOverlay(
                        showBrightness: showBrightnessLabel,
                        showVolume: showVolumeLabel,
                        brightness: brightness,
                        volume: volume,
                      ),
                    ),

                    // Play/Pause Controls
                    if (!isLocked)
                      VideoCenterControls(
                        isPlaying: isPlaying,
                        isVisible: isInterfaceVisible,
                        onPlayPause: onPlayPause,
                        onSeek: onSeekRelative,
                      ),

                    // Error Overlay
                    if (errorMessage != null)
                      Positioned.fill(
                        child: VideoErrorOverlay(
                          message: errorMessage!,
                          onRetry: onRetry ?? () {},
                        ),
                      ),
                  ],
                ),
              ),

              // Subtitle Safe Area
              if (currentSubtitle != "Off")
                Container(height: 40, color: Colors.black),

              // Controls Area
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seekbar
                  Container(
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: positionNotifier,
                      builder: (context, pos, _) {
                        return ValueListenableBuilder<Duration>(
                          valueListenable: durationNotifier,
                          builder: (context, dur, _) {
                            return VideoSeekbar(
                              position: pos,
                              duration: dur,
                              isLocked: isLocked,
                              onChangeStart: onSeekbarChangeStart,
                              onChanged: onSeekbarChanged,
                              onChangeEnd: onSeekbarChangeEnd,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Icons Row + Floating Tray
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // The Icons Row
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                        child: VideoBottomControls(
                          isLocked: isLocked,
                          isLandscape: false,
                          isUnlockControlsVisible: isUnlockControlsVisible,
                          playbackSpeed: playbackSpeed,
                          currentSubtitle: currentSubtitle,
                          currentQuality: currentQuality,
                          activeTray: activeTray,
                          onToggleTraySpeed: () => onToggleTray('speed'),
                          onToggleTraySubtitle: () => onToggleTray('subtitle'),
                          onToggleTrayQuality: () => onToggleTray('quality'),
                          onLockTap: () {
                            if (!isLocked) {
                              onToggleLock();
                            } else {
                              onLockedTap();
                            }
                          },
                          onDoubleLockTap: onDoubleLockTap,
                          onOrientationTap: onToggleOrientation,
                          onResetSpeed: onResetSpeed,
                          onResetSubtitle: onResetSubtitle,
                          onResetQuality: onResetQuality,
                        ),
                      ),

                      // Tray Overlay
                      if (activeTray != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: VideoTray(
                              activeTray: activeTray!,
                              items: trayItems,
                              currentSelection: trayCurrentSelection,
                              playbackSpeed: playbackSpeed,
                              isDraggingSpeedSlider: isDraggingSpeedSlider,
                              onItemSelected: onTrayItemSelected,
                              onSpeedChanged: onTraySpeedChanged,
                              onClose: onTrayClose,
                              onInteraction: onTrayInteraction,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Light separator
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: (isLocked ? 0.0 : (showControls ? 1.0 : 0.0)),
                    child: const Divider(height: 1, color: Colors.white10),
                  ),
                ],
              ),

              // Playlist
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (isLocked) onLockedTap();
                  },
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    child: isLocked
                        ? const SizedBox()
                        : VideoPlaylistWidget(
                            playlist: playlist,
                            currentIndex: currentIndex,
                            videoProgress: videoProgress,
                            onVideoTap: onVideoTap,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
