import 'package:flutter/material.dart';

abstract class BaseVideoEngine {
  Future<void> init();
  Future<void> open(String path, {bool play = true});
  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration duration);
  Future<void> setRate(double rate);
  Future<void> dispose();

  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get completedStream;
  Stream<dynamic> get errorStream;

  Duration get position;
  Duration get duration;
  bool get isPlaying;
  
  Widget buildVideoWidget();
}
