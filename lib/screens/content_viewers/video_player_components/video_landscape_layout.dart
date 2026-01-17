import 'package:flutter/material.dart';
import 'video_gesture_overlay.dart';
import 'video_center_controls.dart';
import 'video_seekbar.dart';
import 'video_bottom_controls.dart';
import 'video_tray.dart';
import 'package:local_mobile_engineer_official/screens/content_viewers/video_player_components/video_top_bar.dart';
import 'video_lock_overlay.dart';
import 'video_error_overlay.dart';
import 'video_player_logic_controller.dart';
import 'video_seek_indicator.dart';

class VideoPlayerLandscapeLayout extends StatelessWidget {
  final VideoPlayerLogicController logic;

  const VideoPlayerLandscapeLayout({
    super.key,
    required this.logic,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ValueListenableBuilder<bool>(
      valueListenable: logic.isLockedNotifier,
      builder: (context, isLocked, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: logic.showControlsNotifier,
          builder: (context, showControls, _) {
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

                // Buffering Spinner
                ValueListenableBuilder<bool>(
                  valueListenable: logic.isBufferingNotifier,
                  builder: (context, isBuffering, _) {
                    if (!isBuffering) return const SizedBox();
                    return const Center(child: CircularProgressIndicator(color: Colors.white70));
                  },
                ),

                // Main Gesture Detector
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: logic.toggleControls,
                    onDoubleTapDown: (details) {
                       if (isLocked) return;
                       final x = details.localPosition.dx;
                       if (x > size.width / 2) {
                         logic.seekRelative(10);
                       } else {
                         logic.seekRelative(-10);
                       }
                    },
                    onVerticalDragStart: isLocked ? null : (_) => logic.handleVerticalDragStart(),
                    onVerticalDragUpdate: isLocked ? null : (details) => logic.handleVerticalDrag(details, size.width),
                    child: Container(color: Colors.transparent),
                  ),
                ),

                // Seek Indicators
                ValueListenableBuilder<int?>(
                  valueListenable: logic.seekIndicatorNotifier,
                  builder: (context, val, _) {
                    if (val == null) return const SizedBox();
                    return Positioned.fill(child: VideoSeekIndicator(value: val));
                  },
                ),

                // Volume/Brightness Overlays
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
                                if (!showVolume && !showBrightness) return const SizedBox();
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

                // Interactive UI elements
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
                  // Scrims
                  _buildScrim(isTop: true, isVisible: showControls),
                  _buildScrim(isTop: false, isVisible: showControls),

                  // Center Play/Pause
                  ValueListenableBuilder<bool>(
                    valueListenable: logic.isPlayingNotifier,
                    builder: (context, isPlaying, _) {
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: showControls ? 1.0 : 0.0,
                        child: showControls 
                          ? VideoCenterControls(
                              isPlaying: isPlaying,
                              isVisible: showControls,
                              onPlayPause: logic.togglePlayPause,
                              onSeek: logic.seekRelative,
                              iconSize: 48,
                            )
                          : const SizedBox(),
                      );
                    }
                  ),

                  // Top Bar
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: showControls ? 1.0 : 0.0,
                      child: !showControls ? const SizedBox() : ValueListenableBuilder<int>(
                        valueListenable: logic.currentIndexNotifier,
                        builder: (context, index, _) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: VideoPlayerTopBar(
                              title: logic.currentTitle,
                              isLocked: false,
                              isVisible: showControls,
                              onBack: () => logic.toggleOrientation(context),
                              isLandscape: true,
                            ),
                          );
                        }
                      ),
                    ),
                  ),

                  // Bottom Bar
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: showControls ? 1.0 : 0.0,
                      child: !showControls ? const SizedBox() : Container(
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
                                      isLandscape: true,
                                    );
                                  },
                                );
                              },
                            ),

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
                                        currentQuality: logic.currentQuality,
                                        activeTray: logic.activeTray,
                                        onToggleTraySpeed: () => logic.toggleTray('speed'),
                                        onToggleTrayQuality: () => logic.toggleTray('quality'),
                                        onLockTap: logic.toggleLock,
                                        onDoubleLockTap: logic.toggleLock,
                                        onOrientationTap: () => logic.toggleOrientation(context),
                                        onResetSpeed: () => logic.setPlaybackSpeed(1.0),
                                        onResetQuality: () => logic.setTrayItem("Auto"),
                                      );
                                    }
                                  ),
                                ),

                                ValueListenableBuilder<String?>(
                                  valueListenable: logic.activeTrayNotifier,
                                  builder: (context, activeTray, _) {
                                    if (activeTray == null) return const SizedBox();
                                    return Positioned(
                                      bottom: 0, left: 0, right: 0,
                                      child: Center(
                                        child: ValueListenableBuilder<double>(
                                          valueListenable: logic.playbackSpeedNotifier,
                                          builder: (context, speed, _) {
                                            return VideoTray(
                                              activeTray: activeTray,
                                              items: logic.qualities,
                                              currentSelection: logic.currentQuality,
                                              playbackSpeed: speed,
                                              isDraggingSpeedSlider: logic.isDraggingSpeedSlider,
                                              onItemSelected: logic.setTrayItem,
                                              onSpeedChanged: (s) => logic.updatePlaybackSpeed(s, isFinal: false),
                                              onClose: () => logic.toggleTray(activeTray),
                                              onInteraction: () => logic.startHideTimer(),
                                              isLandscape: true,
                                            );
                                          }
                                        ),
                                      ),
                                    );
                                  }
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildScrim({required bool isTop, required bool isVisible}) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: 0, right: 0,
      height: isTop ? 120 : 180,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1.0 : 0.0,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
                end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
