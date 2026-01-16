import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'video_player_components/video_player_logic_controller.dart';
import 'video_player_components/video_portrait_layout.dart';
import 'video_player_components/video_landscape_layout.dart';

class VideoPlayerScreen extends StatelessWidget {
  final List<Map<String, dynamic>> playlist;
  final int initialIndex;

  const VideoPlayerScreen({
    super.key,
    required this.playlist,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoPlayerLogicController(
        playlist: playlist,
        initialIndex: initialIndex,
      ),
      child: const _VideoPlayerView(),
    );
  }
}

class _VideoPlayerView extends StatelessWidget {
  const _VideoPlayerView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoPlayerLogicController>();
    final isLandscape = controller.isLandscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (controller.isLocked && isLandscape) return;
        if (isLandscape) {
          controller.toggleOrientation(context);
          return;
        }
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: !isLandscape,
          bottom: !isLandscape,
          left: !isLandscape,
          right: !isLandscape,
          child: isLandscape ? _buildLandscape(context, controller) : _buildPortrait(context, controller),
        ),
      ),
    );
  }

  Widget _buildPortrait(BuildContext context, VideoPlayerLogicController logic) {
    return VideoPlayerPortraitLayout(
      size: MediaQuery.of(context).size,
      videoHeight: MediaQuery.of(context).size.width * 9 / 16,
      isLocked: logic.isLocked,
      isUnlockControlsVisible: logic.isUnlockControlsVisible,
      showControls: logic.showControls,
      controller: logic.controller,
      currentTitle: logic.currentTitle,
      onLockedTap: logic.handleLockedTap,
      onToggleControls: logic.toggleControls,
      onVerticalDragUpdate: (details) => logic.handleVerticalDrag(details, MediaQuery.of(context).size.width),
      showBrightnessLabel: logic.showBrightnessLabel,
      showVolumeLabel: logic.showVolumeLabel,
      brightness: logic.brightness,
      volume: logic.volume,
      isPlaying: logic.isPlaying,
      onPlayPause: logic.togglePlayPause,
      onSeekRelative: logic.seekRelative,
      positionNotifier: logic.positionNotifier,
      durationNotifier: logic.durationNotifier,
      onSeekbarChangeStart: logic.onSeekbarChangeStart,
      onSeekbarChanged: logic.onSeekbarChanged,
      onSeekbarChangeEnd: logic.onSeekbarChangeEnd,
      playbackSpeed: logic.playbackSpeed,
      currentSubtitle: logic.currentSubtitle,
      currentQuality: logic.currentQuality,
      activeTray: logic.activeTray,
      onToggleTray: logic.toggleTray,
      onToggleLock: logic.toggleLock,
      onToggleOrientation: () => logic.toggleOrientation(context),
      onResetSpeed: () => logic.setPlaybackSpeed(1.0),
      onResetSubtitle: () => logic.setTrayItem("Off"),
      onResetQuality: () => logic.setTrayItem("Auto"),
      trayItems: logic.activeTray == 'quality' ? logic.qualities : logic.subtitles,
      trayCurrentSelection: logic.activeTray == 'quality' ? logic.currentQuality : logic.currentSubtitle,
      isDraggingSpeedSlider: logic.isDraggingSpeedSlider,
      onTrayItemSelected: logic.setTrayItem,
      onTraySpeedChanged: logic.setPlaybackSpeed,
      onTrayClose: () => logic.toggleTray(logic.activeTray ?? ""),
      onTrayInteraction: () => logic.startHideTimer(),
      playlist: logic.playlist,
      currentIndex: logic.currentIndex,
      videoProgress: logic.videoProgress,
      onVideoTap: logic.playVideo,
      onBack: () => Navigator.pop(context),
      onDoubleLockTap: logic.toggleLock,
      errorMessage: logic.errorMessage,
      onRetry: () => logic.playVideo(logic.currentIndex),
    );
  }

  Widget _buildLandscape(BuildContext context, VideoPlayerLogicController logic) {
    return VideoPlayerLandscapeLayout(
      isLocked: logic.isLocked,
      isUnlockControlsVisible: logic.isUnlockControlsVisible,
      showControls: logic.showControls,
      controller: logic.controller,
      currentTitle: logic.currentTitle,
      onLockedTap: logic.handleLockedTap,
      onToggleControls: logic.toggleControls,
      onVerticalDragUpdate: (details) => logic.handleVerticalDrag(details, MediaQuery.of(context).size.width),
      showBrightnessLabel: logic.showBrightnessLabel,
      showVolumeLabel: logic.showVolumeLabel,
      brightness: logic.brightness,
      volume: logic.volume,
      isPlaying: logic.isPlaying,
      onSeekRelative: logic.seekRelative,
      onPlayPause: logic.togglePlayPause,
      positionNotifier: logic.positionNotifier,
      durationNotifier: logic.durationNotifier,
      isDraggingSeekbar: logic.isDraggingSeekbar,
      onSeekbarChangeStart: logic.onSeekbarChangeStart,
      onSeekbarChanged: logic.onSeekbarChanged,
      onSeekbarChangeEnd: logic.onSeekbarChangeEnd,
      playbackSpeed: logic.playbackSpeed,
      currentSubtitle: logic.currentSubtitle,
      currentQuality: logic.currentQuality,
      activeTray: logic.activeTray,
      onToggleTray: logic.toggleTray,
      onToggleLock: logic.toggleLock,
      onToggleOrientation: () => logic.toggleOrientation(context),
      onResetSpeed: () => logic.setPlaybackSpeed(1.0),
      onResetSubtitle: () => logic.setTrayItem("Off"),
      onResetQuality: () => logic.setTrayItem("Auto"),
      trayItems: logic.activeTray == 'quality' ? logic.qualities : logic.subtitles,
      trayCurrentSelection: logic.activeTray == 'quality' ? logic.currentQuality : logic.currentSubtitle,
      isDraggingSpeedSlider: logic.isDraggingSpeedSlider,
      onTrayItemSelected: logic.setTrayItem,
      onTraySpeedChanged: logic.setPlaybackSpeed,
      onTrayClose: () => logic.toggleTray(logic.activeTray ?? ""),
      onTrayInteraction: () => logic.startHideTimer(),
      onDoubleLockTap: logic.toggleLock,
      errorMessage: logic.errorMessage,
      onRetry: () => logic.playVideo(logic.currentIndex),
    );
  }
}
