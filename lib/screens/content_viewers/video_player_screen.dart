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
    // Rebuild only when orientation changes
    final isLandscape = context.select<VideoPlayerLogicController, bool>((c) => c.isLandscape);
    final logic = context.read<VideoPlayerLogicController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (logic.isLocked && isLandscape) return;
        if (isLandscape) {
          logic.toggleOrientation(context);
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
          child: ValueListenableBuilder<bool>(
            valueListenable: logic.isLockedNotifier,
            builder: (context, isLocked, child) {
              return ValueListenableBuilder<bool>(
                valueListenable: logic.showControlsNotifier,
                builder: (context, showControls, _) {
                  return ValueListenableBuilder<String?>(
                    valueListenable: logic.activeTrayNotifier,
                    builder: (context, activeTray, _) {
                      if (isLandscape) {
                        return VideoPlayerLandscapeLayout(
                          logic: logic,
                          isLocked: isLocked,
                          showControls: showControls,
                          activeTray: activeTray,
                        );
                      } else {
                        return VideoPlayerPortraitLayout(
                          logic: logic,
                          size: MediaQuery.of(context).size,
                          videoHeight: MediaQuery.of(context).size.width * 9 / 16,
                          isLocked: isLocked,
                          showControls: showControls,
                          activeTray: activeTray,
                        );
                      }
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
