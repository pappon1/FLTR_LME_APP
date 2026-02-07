import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CustomVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;

  const CustomVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
  });

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  late final Player player;
  late final VideoController controller;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    player = Player();
    controller = VideoController(player);

    try {
      await player.open(Media(widget.videoUrl));
      if (widget.autoPlay) {
        await player.play();
      }

      if (mounted) {
        setState(() {
          _isInit = true;
        });
      }
    } catch (e) {
      // debugPrint('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return Container(
        height: 200,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      color: Colors.black,
      height: 220,
      width: double.infinity,
      child: Video(
        controller: controller,
        controls: (state) {
          return MaterialVideoControls(state);
        },
      ),
    );
  }
}
