import 'package:flutter/material.dart';
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
                },
              ),

              // Video Player Area
              _VideoPlayerStack(
                logic: logic,
                size: size,
                videoHeight: videoHeight,
              ),

              // Controls Area (Seekbar, Bottom Buttons, Trays)
              _VideoControlsSection(logic: logic),

              // Playlist Area
              _VideoPlaylistSection(logic: logic),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoPlayerStack extends StatelessWidget {
  final VideoPlayerLogicController logic;
  final Size size;
  final double videoHeight;

  const _VideoPlayerStack({
    required this.logic,
    required this.size,
    required this.videoHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                  final isInterfaceVisible = isLocked
                      ? isUnlockVisible
                      : showControls;

                  return Stack(
                    children: [
                      // 1. Video Display (Base)
                      logic.engine.buildVideoWidget(),

                      // Buffering Spinner
                      ValueListenableBuilder<bool>(
                        valueListenable: logic.isBufferingNotifier,
                        builder: (context, isBuffering, _) {
                          if (!isBuffering) return const SizedBox();
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                            ),
                          );
                        },
                      ),

                      if (isLocked)
                        Positioned.fill(
                          child: Container(color: Colors.black54),
                        ),

                      // 2. Control Gestures (Volume, Brightness, Seek, Toggle)
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: logic.toggleControls,
                        onDoubleTapDown: (details) => logic.handleDoubleTap(
                          details.localPosition.dx,
                          size.width,
                        ),
                        onVerticalDragStart: (details) =>
                            logic.handleVerticalDragStart(details, size.width),
                        onVerticalDragUpdate: (details) =>
                            logic.handleVerticalDrag(details, size.width),
                        onVerticalDragEnd: (_) => logic.handleVerticalDragEnd(),
                        child: Container(color: Colors.transparent),
                      ),

                      // Seek Indicator Overlay
                      ValueListenableBuilder<int?>(
                        valueListenable: logic.seekIndicatorNotifier,
                        builder: (context, val, _) {
                          if (val == null) return const SizedBox();
                          return Positioned.fill(
                            child: VideoSeekIndicator(value: val),
                          );
                        },
                      ),

                      // Gesture Overlays (Volume/Brightness)
                      _GestureOverlays(logic: logic),

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
                          },
                        ),

                      // Error Overlay
                      ValueListenableBuilder<String?>(
                        valueListenable: logic.errorMessageNotifier,
                        builder: (context, error, _) {
                          if (error == null) return const SizedBox();
                          return Positioned.fill(
                            child: VideoErrorOverlay(
                              message: error,
                              onRetry: logic.retryCurrentVideo,
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _GestureOverlays extends StatelessWidget {
  final VideoPlayerLogicController logic;
  const _GestureOverlays({required this.logic});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: logic.showVolumeLabelNotifier,
      builder: (context, showVolume, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: logic.showBrightnessLabelNotifier,
          builder: (context, showBrightness, _) {
            if (!showVolume && !showBrightness) return const SizedBox();
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
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _VideoControlsSection extends StatelessWidget {
  final VideoPlayerLogicController logic;
  const _VideoControlsSection({required this.logic});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: logic.isLockedNotifier,
      builder: (context, isLocked, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: logic.showControlsNotifier,
          builder: (context, showControls, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seekbar
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
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

                // Bottom Buttons & Tray
                Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.only(
                        left: 10,
                        right: 10,
                        bottom: 8,
                      ),
                      child: ValueListenableBuilder<double>(
                        valueListenable: logic.playbackSpeedNotifier,
                        builder: (context, speed, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable:
                                logic.isUnlockControlsVisibleNotifier,
                            builder: (context, isUnlockVisible, _) {
                              return VideoBottomControls(
                                isLocked: isLocked,
                                isLandscape: false,
                                isUnlockControlsVisible: isUnlockVisible,
                                playbackSpeed: speed,
                                currentQuality: logic.currentQuality,
                                activeTray: logic.activeTray,
                                onToggleTraySpeed: () =>
                                    logic.toggleTray('speed'),
                                onToggleTrayQuality: () =>
                                    logic.toggleTray('quality'),
                                onLockTap: isLocked
                                    ? logic.handleLockedTap
                                    : logic.toggleLock,
                                onDoubleLockTap: logic.toggleLock,
                                onOrientationTap: () =>
                                    logic.toggleOrientation(context),
                                onResetSpeed: () => logic.setPlaybackSpeed(1.0),
                                onResetQuality: () => logic.setTrayItem("Auto"),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Animated Tray
                    ValueListenableBuilder<String?>(
                      valueListenable: logic.activeTrayNotifier,
                      builder: (context, activeTray, _) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0.0, 1.0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  ),
                              child: child,
                            );
                          },
                          child: activeTray == null
                              ? const SizedBox.shrink()
                              : Center(
                                  child: ListenableBuilder(
                                    listenable: logic,
                                    builder: (context, _) => VideoTray(
                                      activeTray: activeTray,
                                      items: logic.qualities,
                                      currentSelection: logic.currentQuality,
                                      playbackSpeed: logic.playbackSpeed,
                                      isDraggingSpeedSlider:
                                          logic.isDraggingSpeedSlider,
                                      onItemSelected: logic.setTrayItem,
                                      onSpeedChanged: logic.updatePlaybackSpeed,
                                      onSpeedChangeEnd: logic.onSpeedSliderEnd,
                                      onClose: () =>
                                          logic.toggleTray(activeTray),
                                      onInteraction: () =>
                                          logic.resetTrayHideTimer(),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ],
                ),

                // Divider Removed for cleaner UI
              ],
            );
          },
        );
      },
    );
  }
}

class _VideoPlaylistSection extends StatelessWidget {
  final VideoPlayerLogicController logic;
  const _VideoPlaylistSection({required this.logic});

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
              return ValueListenableBuilder<int>(
                valueListenable: logic.currentIndexNotifier,
                builder: (context, currentIndex, _) {
                  return ValueListenableBuilder<Map<String, double>>(
                    valueListenable: logic.progressNotifier,
                    builder: (context, progress, _) {
                      return VideoPlaylistWidget(
                        playlist: logic.playlist,
                        currentIndex: currentIndex,
                        videoProgress: progress,
                        onVideoTap: logic.playVideo,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
