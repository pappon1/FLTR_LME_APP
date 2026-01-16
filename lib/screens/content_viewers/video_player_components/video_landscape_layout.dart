import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'video_gesture_overlay.dart';
import 'video_center_controls.dart';
import 'video_seekbar.dart';
import 'video_bottom_controls.dart';
import 'video_tray.dart';
import 'video_lock_overlay.dart';
import 'video_error_overlay.dart';

class VideoPlayerLandscapeLayout extends StatelessWidget {
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
  final Function(int) onSeekRelative;
  final VoidCallback onPlayPause;
  
  // Seekbar
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<Duration> durationNotifier;
  final bool isDraggingSeekbar;
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
  final VoidCallback onDoubleLockTap;

  const VideoPlayerLandscapeLayout({
    super.key,
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
    required this.onSeekRelative,
    required this.onPlayPause,
    required this.positionNotifier,
    required this.durationNotifier,
    required this.isDraggingSeekbar,
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
    required this.onDoubleLockTap,
    this.errorMessage,
    this.onRetry,
  });

  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Layer
        Container(
          color: Colors.black,
          child: Center(
            child: Video(
              controller: controller,
              controls: (state) => const SizedBox(),
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Gesture Detector
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onToggleControls,
            onVerticalDragUpdate: isLocked ? null : onVerticalDragUpdate,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Gesture Overlay
        Positioned.fill(
          child: VideoGestureOverlay(
            showBrightness: showBrightnessLabel,
            showVolume: showVolumeLabel,
            brightness: brightness,
            volume: volume,
          ),
        ),

        // Error Overlay
        if (errorMessage != null)
          Positioned.fill(
            child: VideoErrorOverlay(
              message: errorMessage!,
              onRetry: onRetry ?? () {},
            ),
          ),

        // Controls
        Stack(
          children: [
            if (isLocked)
              VideoLockOverlay(
                isVisible: isUnlockControlsVisible,
                title: currentTitle,
                onUnlock: onToggleLock,
                onInteraction: onLockedTap,
              )
            else ...[
              // Center Controls
              if (!isDraggingSeekbar)
                VideoCenterControls(
                  isPlaying: isPlaying,
                  isVisible: showControls,
                  onPlayPause: onPlayPause,
                  onSeek: onSeekRelative,
                  iconSize: 48,
                ),

              // Visual Scrims
              _buildScrim(isTop: true),
              _buildScrim(isTop: false),

              // Top Bar
              Positioned(
                top: 0, left: 0, right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: showControls ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !showControls,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: onToggleOrientation,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Bar
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: showControls ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !showControls,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(32, 20, 32, 30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<Duration>(
                            valueListenable: positionNotifier,
                            builder: (context, pos, _) {
                              return ValueListenableBuilder<Duration>(
                                valueListenable: durationNotifier,
                                builder: (context, dur, _) {
                                  return VideoSeekbar(
                                    position: pos,
                                    duration: dur,
                                    isLocked: false,
                                    onChangeStart: onSeekbarChangeStart,
                                    onChanged: onSeekbarChanged,
                                    onChangeEnd: onSeekbarChangeEnd,
                                  );
                                },
                              );
                            },
                          ),

                          // Icons Row + Tray Overlay
                          Stack(
                            alignment: Alignment.bottomCenter,
                            clipBehavior: Clip.none,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: VideoBottomControls(
                                  isLocked: isLocked,
                                  isLandscape: true,
                                  isUnlockControlsVisible: isUnlockControlsVisible,
                                  playbackSpeed: playbackSpeed,
                                  currentSubtitle: currentSubtitle,
                                  currentQuality: currentQuality,
                                  activeTray: activeTray,
                                  onToggleTraySpeed: () => onToggleTray('speed'),
                                  onToggleTraySubtitle: () => onToggleTray('subtitle'),
                                  onToggleTrayQuality: () => onToggleTray('quality'),
                                  onLockTap: onToggleLock,
                                  onDoubleLockTap: onDoubleLockTap,
                                  onOrientationTap: onToggleOrientation,
                                  onResetSpeed: onResetSpeed,
                                  onResetSubtitle: onResetSubtitle,
                                  onResetQuality: onResetQuality,
                                ),
                              ),

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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildScrim({required bool isTop}) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: 0,
      right: 0,
      height: isTop ? 140 : 200,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: showControls ? 1.0 : 0.0,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
                end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
