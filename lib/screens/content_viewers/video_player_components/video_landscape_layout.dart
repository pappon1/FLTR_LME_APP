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
import 'video_playlist_widget.dart';
import 'video_seek_indicator.dart';

class VideoPlayerLandscapeLayout extends StatelessWidget {
  final VideoPlayerLogicController logic;

  const VideoPlayerLandscapeLayout({super.key, required this.logic});

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
                // Base Video Layer
                _VideoBaseLayer(logic: logic),

                // Gesture layer (Double tap to seek, Volume/Brightness drag)
                _VideoGestureLayer(
                  logic: logic,
                  size: size,
                  isLocked: isLocked,
                ),

                // UI Overlays
                if (isLocked)
                  _VideoLockedOverlayLayer(logic: logic)
                else ...[
                  // Scrims & Controls
                  _VideoControlsLayer(logic: logic, showControls: showControls),

                  // Playlist Overlay (New Modern Feature)
                  _VideoPlaylistOverlay(logic: logic),
                ],

                // Global components (Errors, Seek Indicators)
                _VideoGlobalOverlays(logic: logic),
              ],
            );
          },
        );
      },
    );
  }
}

class _VideoBaseLayer extends StatelessWidget {
  final VideoPlayerLogicController logic;
  const _VideoBaseLayer({required this.logic});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(child: logic.engine.buildVideoWidget()),
          ValueListenableBuilder<bool>(
            valueListenable: logic.isBufferingNotifier,
            builder: (context, isBuffering, _) {
              if (!isBuffering) return const SizedBox();
              return const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VideoGestureLayer extends StatelessWidget {
  final VideoPlayerLogicController logic;
  final Size size;
  final bool isLocked;

  const _VideoGestureLayer({
    required this.logic,
    required this.size,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: logic.toggleControls,
      onDoubleTapDown: (details) =>
          logic.handleDoubleTap(details.localPosition.dx, size.width),
      onVerticalDragStart: (details) =>
          logic.handleVerticalDragStart(details, size.width),
      onVerticalDragUpdate: (details) =>
          logic.handleVerticalDrag(details, size.width),
      onVerticalDragEnd: (_) => logic.handleVerticalDragEnd(),
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Center(child: logic.engine.buildVideoWidget()),
            ValueListenableBuilder<bool>(
              valueListenable: logic.isBufferingNotifier,
              builder: (context, isBuffering, _) {
                if (!isBuffering) return const SizedBox();
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoLockedOverlayLayer extends StatelessWidget {
  final VideoPlayerLogicController logic;
  const _VideoLockedOverlayLayer({required this.logic});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: logic.isUnlockControlsVisibleNotifier,
      builder: (context, visible, _) {
        return VideoLockOverlay(
          isVisible: visible,
          title: logic.currentTitle,
          onUnlock: logic.toggleLock,
          onInteraction: logic.handleLockedTap,
        );
      },
    );
  }
}

class _VideoControlsLayer extends StatelessWidget {
  final VideoPlayerLogicController logic;
  final bool showControls;

  const _VideoControlsLayer({required this.logic, required this.showControls});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildScrim(isTop: true, isVisible: showControls),
        _buildScrim(isTop: false, isVisible: showControls),

        // Play/Pause Center
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
                      onNext: logic.playNextVideo,
                      onPrev: logic.playPreviousVideo,
                      hasNext: logic.playlistManager.hasNext,
                      hasPrev: logic.playlistManager.hasPrev,
                      iconSize: 32,
                    )
                  : const SizedBox(),
            );
          },
        ),

        // Top Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: showControls ? 1.0 : 0.0,
            child: !showControls
                ? const SizedBox()
                : ValueListenableBuilder<int>(
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
                    },
                  ),
          ),
        ),

        // Bottom Bar & Trays
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: showControls ? 1.0 : 0.0,
            child: !showControls
                ? const SizedBox()
                : Container(
                    padding: const EdgeInsets.fromLTRB(10, 20, 10, 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _VideoSeekbarLandscape(logic: logic),
                        const SizedBox(height: 8),
                        _VideoBottomControlsLandscape(logic: logic),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrim({required bool isTop, required bool isVisible}) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: 0,
      right: 0,
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

class _VideoSeekbarLandscape extends StatelessWidget {
  final VideoPlayerLogicController logic;
  const _VideoSeekbarLandscape({required this.logic});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
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
    );
  }
}

class _VideoBottomControlsLandscape extends StatelessWidget {
  final VideoPlayerLogicController logic;
  const _VideoBottomControlsLandscape({required this.logic});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: logic.playbackSpeedNotifier,
          builder: (context, speed, _) {
            return VideoBottomControls(
              isLocked: false,
              isLandscape: true,
              isUnlockControlsVisible: logic.isUnlockControlsVisible,
              playbackSpeed: speed,
              currentQuality: logic.currentQuality,
              activeTray: logic.activeTray,
              onToggleTraySpeed: () => logic.toggleTray('speed'),
              onToggleTrayQuality: () => logic.toggleTray('quality'),
              onTogglePlaylist: logic.togglePlaylist,
              onLockTap: logic.toggleLock,
              onDoubleLockTap: logic.toggleLock,
              onOrientationTap: () => logic.toggleOrientation(context),
              onResetSpeed: () => logic.setPlaybackSpeed(1.0),
              onResetQuality: () => logic.setTrayItem("Auto"),
            );
          },
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
                          isDraggingSpeedSlider: logic.isDraggingSpeedSlider,
                          onItemSelected: logic.setTrayItem,
                          onSpeedChanged: logic.updatePlaybackSpeed,
                          onSpeedChangeEnd: logic.onSpeedSliderEnd,
                          onClose: () => logic.toggleTray(activeTray),
                          onInteraction: () => logic.resetTrayHideTimer(),
                          isLandscape: true,
                        ),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _VideoGlobalOverlays extends StatelessWidget {
  final VideoPlayerLogicController logic;
  const _VideoGlobalOverlays({required this.logic});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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

        // Seek Indicators
        ValueListenableBuilder<int?>(
          valueListenable: logic.seekIndicatorNotifier,
          builder: (context, val, _) {
            if (val == null) return const SizedBox();
            return Positioned.fill(child: VideoSeekIndicator(value: val));
          },
        ),

        // Gesture overlays (Volume/Brightness)
        ValueListenableBuilder<bool>(
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
        ),
      ],
    );
  }
}

class _VideoPlaylistOverlay extends StatelessWidget {
  final VideoPlayerLogicController logic;
  const _VideoPlaylistOverlay({required this.logic});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: logic.showPlaylistNotifier,
      builder: (context, isVisible, _) {
        return Stack(
          children: [
            // Backdrop to close
            if (isVisible)
              Positioned.fill(
                child: GestureDetector(
                  onTap: logic.togglePlaylist,
                  child: Container(color: Colors.black54),
                ),
              ),

            // Sliding Side Drawer
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              right: isVisible ? 0 : -350,
              top: 0,
              bottom: 0,
              width: 350,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9), // Glassy Dark
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white10),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.playlist_play, color: Colors.white),
                          const SizedBox(width: 12),
                          const Text(
                            'Playlist',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: logic.togglePlaylist,
                          ),
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: logic.currentIndexNotifier,
                        builder: (context, currentIndex, _) {
                          return ValueListenableBuilder<Map<String, double>>(
                            valueListenable: logic.progressNotifier,
                            builder: (context, progress, _) {
                              return VideoPlaylistWidget(
                                playlist: logic.playlist,
                                currentIndex: currentIndex,
                                videoProgress: progress,
                                onVideoTap: (idx) {
                                  logic.playVideo(idx);
                                  logic
                                      .togglePlaylist(); // Auto-close on selection
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
