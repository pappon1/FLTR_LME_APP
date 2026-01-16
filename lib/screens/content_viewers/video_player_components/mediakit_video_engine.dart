import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'video_engine_interface.dart';

class MediaKitVideoEngine implements BaseVideoEngine {
  late final Player player;
  late final VideoController controller;

  @override
  Future<void> init() async {
    player = Player();
    controller = VideoController(player);
  }

  @override
  Future<void> open(String path, {bool play = true}) async {
    await player.open(Media(path), play: play);
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
