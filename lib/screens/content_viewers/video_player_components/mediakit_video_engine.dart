import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../services/config_service.dart';
import 'video_engine_interface.dart';

class MediaKitVideoEngine implements BaseVideoEngine {
  late final Player player;
  late final VideoController controller;

  @override
  Future<void> init() async {
    player = Player(
      configuration: const PlayerConfiguration(
        title: 'Mobile Engineer Player',
        ready: null,
        pitch:
            true, // Explicitly enable pitch correction for smooth audio at all speeds
      ),
    );
    controller = VideoController(player);
  }

  @override
  Future<void> open(String path, {bool play = true, Map<String, String>? headers}) async {
    final Map<String, String> finalHeaders = Map<String, String>.from(headers ?? {});
    
    // Standard headers for all requests - Using a consistent Desktop User-Agent
    finalHeaders['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    
    // Use exact Referer/Origin (Most reliable across all Bunny.net zones)
    finalHeaders['Referer'] = ConfigService.allowedReferer;
    finalHeaders['Origin'] = ConfigService.allowedReferer;
    
    // Auto-inject AccessKey for direct Bunny Storage access
    if (path.contains('storage.bunnycdn.com')) {
      finalHeaders['AccessKey'] = ConfigService().bunnyStorageKey;
    }

    debugPrint('🎬 [ENGINE] Opening Path: $path');
    debugPrint('🎬 [ENGINE] Headers: $finalHeaders');
    
    await player.open(Media(path, httpHeaders: finalHeaders), play: play);
  }

  @override
  Future<void> play() async => await player.play();

  @override
  Future<void> pause() async => await player.pause();

  @override
  Future<void> playOrPause() async => await player.playOrPause();

  @override
  Future<void> seek(Duration duration) async => await player.seek(duration);

  @override
  Future<void> setRate(double rate) async => await player.setRate(rate);

  @override
  Future<void> setVideoTrack(String quality) async {
    final tracks = player.state.tracks.video;
    if (quality.toLowerCase() == "auto") {
      await player.setVideoTrack(
        tracks.first,
      ); // Usually the first is auto/default
      return;
    }

    final int targetHeight =
        int.tryParse(quality.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (targetHeight == 0) return;

    VideoTrack? bestMatch;
    int minDiff = 10000;

    for (final track in tracks) {
      if (track.h == null) continue;
      final diff = (track.h! - targetHeight).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestMatch = track;
      }
    }

    if (bestMatch != null) {
      await player.setVideoTrack(bestMatch);
    }
  }

  @override
  Future<void> dispose() async {
    await player.dispose();
  }

  @override
  Stream<Duration> get positionStream => player.stream.position;

  @override
  Stream<Duration> get durationStream => player.stream.duration;

  @override
  Stream<bool> get playingStream => player.stream.playing;

  @override
  Stream<bool> get completedStream => player.stream.completed;

  @override
  Stream<bool> get bufferingStream => player.stream.buffering;

  @override
  Stream<dynamic> get errorStream => player.stream.error;

  @override
  Duration get position => player.state.position;

  @override
  Duration get duration => player.state.duration;

  @override
  bool get isPlaying => player.state.playing;

  @override
  bool get isBuffering => player.state.buffering;

  @override
  Widget buildVideoWidget() {
    return Video(controller: controller, controls: (state) => const SizedBox());
  }
}
