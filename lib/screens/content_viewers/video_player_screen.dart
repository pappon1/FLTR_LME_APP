import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import 'video_player_components/video_player_logic_controller.dart';
import 'video_player_components/video_portrait_layout.dart';
import 'video_player_components/video_landscape_layout.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> playlist;
  final int initialIndex;

  const VideoPlayerScreen({
    super.key,
    required this.playlist,
    required this.initialIndex,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerLogicController _logic;

  @override
  void initState() {
    super.initState();
    _logic = VideoPlayerLogicController(
      playlist: widget.playlist,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _logic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final videoHeight = size.width * (9 / 16);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      },
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          // debugPrint("VideoPlayerScreen Rebuild: isDark=$isDark");
          return Scaffold(
            backgroundColor: isDark ? Colors.black : Colors.white,
            body: SafeArea(
              top: !_logic.isLandscape, 
              bottom: !_logic.isLandscape,
              child: ValueListenableBuilder<bool>(
                valueListenable: _logic.isReadyNotifier,
                builder: (context, isReady, child) {
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: isReady ? 1.0 : 0.0,
                    child: child,
                  );
                },
                child: ListenableBuilder(
                  listenable: _logic,
                  // We only listen for structural changes (orientation) here
                  builder: (context, _) {
                    if (_logic.isLandscape) {
                      return VideoPlayerLandscapeLayout(logic: _logic);
                    }

                    return VideoPlayerPortraitLayout(
                      logic: _logic,
                      size: size,
                      videoHeight: videoHeight,
                    );
                  },
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}
