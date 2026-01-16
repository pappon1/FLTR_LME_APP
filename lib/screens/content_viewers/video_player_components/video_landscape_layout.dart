import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'video_gesture_overlay.dart';
import 'video_center_controls.dart';
import 'video_seekbar.dart';
import 'video_bottom_controls.dart';
import 'video_tray.dart';
import 'video_lock_overlay.dart';
import 'video_error_overlay.dart';
import 'video_player_logic_controller.dart';

class VideoPlayerLandscapeLayout extends StatelessWidget {
  final VideoPlayerLogicController logic;
  final bool isLocked;
  final bool showControls;
  final String? activeTray;

  const VideoPlayerLandscapeLayout({
    super.key,
    required this.logic,
    required this.isLocked,
    required this.showControls,
    this.activeTray,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Layer
        Container(
          color: Colors.black,
          child: Center(
            child: logic.engine.buildVideoWidget(),
          ),
        ),

        // Gesture Detector
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: logic.toggleControls,
            onVerticalDragUpdate: isLocked ? null : (details) => logic.handleVerticalDrag(details, MediaQuery.of(context).size.width),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Gesture Overlay (Granular Update)
        ValueListenableBuilder<bool>(
          valueListenable: logic.showVolumeLabelNotifier,
          builder: (context, showVolume, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: logic.showBrightnessLabelNotifier,
              builder: (context, showBrightness, _) {
                return ValueListenableBuilder<double>(
                  valueListenable: logic.volumeNotifier,
                  builder: (context, vol, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: logic.brightnessNotifier,
                      builder: (context, bright, _) {
                        return Positioned.fill(
                          child: VideoGestureOverlay(
                            showBrightness: showBrightness,
                            showVolume: showVolume,
                            brightness: bright,
                            volume: vol,
                          ),
                        );
                      }
                    );
                  }
                );
              }
            );
          }
        ),

        // Error Overlay
        ValueListenableBuilder<String?>(
          valueListenable: logic.errorMessageNotifier,
          builder: (context, error, _) {
            if (error == null) return const SizedBox();
            return Positioned.fill(
              child: VideoErrorOverlay(
                message: error,
                onRetry: () => logic.playVideo(logic.currentIndex),
              ),
            );
          }
        ),

        // Controls
        Stack(
          children: [
            if (isLocked)
              ValueListenableBuilder<bool>(
                valueListenable: logic.isUnlockControlsVisibleNotifier,
                builder: (context, visible, _) {
                  return VideoLockOverlay(
                    isVisible: visible,
                    title: logic.currentTitle,
                    onUnlock: logic.toggleLock,
                    onInteraction: logic.handleLockedTap,
                  );
                }
              )
            else ...[
              // Center Controls
              ValueListenableBuilder<bool>(
                valueListenable: logic.isPlayingNotifier,
                builder: (context, isPlaying, _) {
                  return VideoCenterControls(
                    isPlaying: isPlaying,
                    isVisible: showControls,
                    onPlayPause: logic.togglePlayPause,
                    onSeek: logic.seekRelative,
                    iconSize: 48,
                  );
                }
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
                            onPressed: () => logic.toggleOrientation(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ValueListenableBuilder<int>(
                              valueListenable: logic.currentIndexNotifier,
                              builder: (context, index, _) {
                                return Text(
                                  logic.currentTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              }
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
                            valueListenable: logic.positionNotifier,
                            builder: (context, pos, _) {
                              return ValueListenableBuilder<Duration>(
                                valueListenable: logic.durationNotifier,
                                builder: (context, dur, _) {
                                  return VideoSeekbar(
                                    position: pos,
                                    duration: dur,
                                    isLocked: false,
                                    onChangeStart: logic.onSeekbarChangeStart,
                                    onChanged: logic.onSeekbarChanged,
                                    onChangeEnd: logic.onSeekbarChangeEnd,
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
                                child: ValueListenableBuilder<double>(
                                  valueListenable: logic.playbackSpeedNotifier,
                                  builder: (context, speed, _) {
                                    return VideoBottomControls(
                                      isLocked: isLocked,
                                      isLandscape: true,
                                      isUnlockControlsVisible: logic.isUnlockControlsVisible,
                                      playbackSpeed: speed,
                                      currentSubtitle: logic.currentSubtitle,
                                      currentQuality: logic.currentQuality,
                                      activeTray: activeTray,
                                      onToggleTraySpeed: () => logic.toggleTray('speed'),
                                      onToggleTraySubtitle: () => logic.toggleTray('subtitle'),
                                      onToggleTrayQuality: () => logic.toggleTray('quality'),
                                      onLockTap: logic.toggleLock,
                                      onDoubleLockTap: logic.toggleLock,
                                      onOrientationTap: () => logic.toggleOrientation(context),
                                      onResetSpeed: () => logic.setPlaybackSpeed(1.0),
                                      onResetSubtitle: () => logic.setTrayItem("Off"),
                                      onResetQuality: () => logic.setTrayItem("Auto"),
                                    );
                                  }
                                ),
                              ),

                              if (activeTray != null)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: ValueListenableBuilder<double>(
                                      valueListenable: logic.playbackSpeedNotifier,
                                      builder: (context, speed, _) {
                                        return VideoTray(
                                          activeTray: activeTray!,
                                          items: activeTray == 'quality' ? logic.qualities : logic.subtitles,
                                          currentSelection: activeTray == 'quality' ? logic.currentQuality : logic.currentSubtitle,
                                          playbackSpeed: speed,
                                          isDraggingSpeedSlider: logic.isDraggingSpeedSlider,
                                          onItemSelected: logic.setTrayItem,
                                          onSpeedChanged: logic.setPlaybackSpeed,
                                          onClose: () => logic.toggleTray(activeTray!),
                                          onInteraction: () => logic.startHideTimer(),
                                        );
                                      }
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
