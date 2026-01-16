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
import 'video_player_logic_controller.dart';
import 'video_seek_indicator.dart';

class VideoPlayerPortraitLayout extends StatelessWidget {
  final VideoPlayerLogicController logic;
  final Size size;
  final double videoHeight;

  const VideoPlayerPortraitLayout({
    super.key,
    required this.logic,
    required this.size,
    required this.videoHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              ValueListenableBuilder<int>(
                valueListenable: logic.currentIndexNotifier,
                builder: (context, index, _) {
                  return VideoPlayerTopBar(
                    title: logic.currentTitle,
                    isLocked: logic.isLocked,
                    isVisible: true,
                    onBack: () => Navigator.pop(context),
                  );
                }
              ),

              // Video Player Area
              SizedBox(
                width: size.width,
                height: videoHeight,
                child: ValueListenableBuilder<bool>(
                  valueListenable: logic.isLockedNotifier,
                  builder: (context, isLocked, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: logic.showControlsNotifier,
                      builder: (context, showControls, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: logic.isUnlockControlsVisibleNotifier,
                          builder: (context, isUnlockVisible, _) {
                            final isInterfaceVisible = isLocked ? isUnlockVisible : showControls;
                            
                            return Stack(
                              children: [
                                logic.engine.buildVideoWidget(),

                                // Buffering Spinner
                                ValueListenableBuilder<bool>(
                                  valueListenable: logic.isBufferingNotifier,
                                  builder: (context, isBuffering, _) {
                                    if (!isBuffering) return const SizedBox();
                                    return const Center(child: CircularProgressIndicator(color: Colors.white70));
                                  },
                                ),

                                if (isLocked)
                                  Positioned.fill(child: Container(color: Colors.black54)),

                                // Gesture Detector
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: logic.toggleControls,
                                    onDoubleTapDown: (details) {
                                       if (isLocked) return;
                                       final x = details.localPosition.dx;
                                       if (x > size.width / 2) logic.seekRelative(10);
                                       else logic.seekRelative(-10);
                                    },
                                    onVerticalDragStart: isLocked ? null : (_) => logic.handleVerticalDragStart(),
                                    onVerticalDragUpdate: isLocked ? null : (details) => logic.handleVerticalDrag(details, size.width),
                                    child: Container(color: Colors.transparent),
                                  ),
                                ),

                                // Seek Indicator Overlay
                                ValueListenableBuilder<int?>(
                                  valueListenable: logic.seekIndicatorNotifier,
                                  builder: (context, val, _) {
                                    if (val == null) return const SizedBox();
                                    return Positioned.fill(child: VideoSeekIndicator(value: val));
                                  },
                                ),

                                // Gesture Overlays
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

                                // Play/Pause Controls
                                if (!isLocked)
                                  ValueListenableBuilder<bool>(
                                    valueListenable: logic.isPlayingNotifier,
                                    builder: (context, isPlaying, _) {
                                      return AnimatedOpacity(
                                        duration: const Duration(milliseconds: 300),
                                        opacity: isInterfaceVisible ? 1.0 : 0.0,
                                        child: isInterfaceVisible 
                                          ? VideoCenterControls(
                                            isPlaying: isPlaying,
                                            isVisible: isInterfaceVisible,
                                            onPlayPause: logic.togglePlayPause,
                                            onSeek: logic.seekRelative,
                                          )
                                          : const SizedBox(),
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
                              ],
                            );
                          }
                        );
                      }
                    );
                  }
                ),
              ),

              if (logic.currentSubtitle != "Off")
                Container(height: 40, color: Colors.black),

              // Bottom Area
              ValueListenableBuilder<bool>(
                valueListenable: logic.isLockedNotifier,
                builder: (context, isLocked, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: logic.showControlsNotifier,
                    builder: (context, showControls, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            color: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: ValueListenableBuilder<Duration>(
                              valueListenable: logic.positionNotifier,
                              builder: (context, pos, _) {
                                return ValueListenableBuilder<Duration>(
                                  valueListenable: logic.durationNotifier,
                                  builder: (context, dur, _) {
                                    return VideoSeekbar(
                                      position: pos,
                                      duration: dur,
                                      isLocked: isLocked,
                                      onChangeStart: logic.onSeekbarChangeStart,
                                      onChanged: logic.onSeekbarChanged,
                                      onChangeEnd: logic.onSeekbarChangeEnd,
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          Stack(
                            alignment: Alignment.bottomCenter,
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                color: Colors.black,
                                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                                child: ValueListenableBuilder<double>(
                                  valueListenable: logic.playbackSpeedNotifier,
                                  builder: (context, speed, _) {
                                    return VideoBottomControls(
                                      isLocked: isLocked,
                                      isLandscape: false,
                                      isUnlockControlsVisible: logic.isUnlockControlsVisible,
                                      playbackSpeed: speed,
                                      currentSubtitle: logic.currentSubtitle,
                                      currentQuality: logic.currentQuality,
                                      activeTray: logic.activeTray,
                                      onToggleTraySpeed: () => logic.toggleTray('speed'),
                                      onToggleTraySubtitle: () => logic.toggleTray('subtitle'),
                                      onToggleTrayQuality: () => logic.toggleTray('quality'),
                                      onLockTap: isLocked ? logic.handleLockedTap : logic.toggleLock,
                                      onDoubleLockTap: logic.toggleLock,
                                      onOrientationTap: () => logic.toggleOrientation(context),
                                      onResetSpeed: () => logic.setPlaybackSpeed(1.0),
                                      onResetSubtitle: () => logic.setTrayItem("Off"),
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
                                            items: activeTray == 'quality' ? logic.qualities : logic.subtitles,
                                            currentSelection: activeTray == 'quality' ? logic.currentQuality : logic.currentSubtitle,
                                            playbackSpeed: speed,
                                            isDraggingSpeedSlider: logic.isDraggingSpeedSlider,
                                            onItemSelected: logic.setTrayItem,
                                            onSpeedChanged: (s) => logic.updatePlaybackSpeed(s, isFinal: false),
                                            onClose: () => logic.toggleTray(activeTray),
                                            onInteraction: () => logic.startHideTimer(),
                                          );
                                        }
                                      ),
                                    ),
                                  );
                                }
                              ),
                            ],
                          ),

                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: (isLocked ? 0.0 : (showControls ? 1.0 : 0.0)),
                            child: const Divider(height: 1, color: Colors.white10),
                          ),
                        ],
                      );
                    }
                  );
                }
              ),

              // Playlist
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (logic.isLocked) logic.handleLockedTap();
                  },
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: logic.isLockedNotifier,
                      builder: (context, isLocked, _) {
                        if (isLocked) return const SizedBox();
                        return ListenableBuilder(
                          listenable: logic,
                          builder: (context, _) {
                            return VideoPlaylistWidget(
                              playlist: logic.playlist,
                              currentIndex: logic.currentIndex,
                              videoProgress: logic.videoProgress,
                              onVideoTap: logic.playVideo,
                            );
                          }
                        );
                      }
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
