import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'video_player_constants.dart';
import 'video_persistence_service.dart';

class VideoPlayerLogicController extends ChangeNotifier with WidgetsBindingObserver {
  final List<Map<String, dynamic>> playlist;
  late final Player player;
  late final VideoController controller;

  // Player State
  int _currentIndex;
  bool _isPlaying = false;
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  double _playbackSpeed = 1.0;

  // UI Visibility State
  bool _showControls = true;
  bool _isLandscape = false;
  bool _isDraggingSeekbar = false;
  bool _isLocked = false;
  bool _isUnlockControlsVisible = false;
  String? _activeTray;
  bool _isDraggingSpeedSlider = false;

  // Feature State
  String _currentQuality = "Auto";
  String _currentSubtitle = "Off";
  final List<String> subtitles = ["Off", "English", "Bengali", "Hindi"];
  final List<String> qualities = ["Auto", "480p", "720p", "1080p", "1920p"];

  // Gesture State
  double _volume = VideoPlayerConstants.defaultVolume;
  double _initialSystemVolume = VideoPlayerConstants.defaultVolume;
  bool _isChangingVolumeViaGesture = false;
  double _brightness = VideoPlayerConstants.defaultBrightness;
  bool _showVolumeLabel = false;
  bool _showBrightnessLabel = false;

  // Error State
  String? _errorMessage;

  // Timers
  Timer? _hideTimer;
  Timer? _unlockHideTimer;
  Timer? _trayHideTimer;
  Timer? _volumeTimer;
  Timer? _brightnessTimer;

  // Persistence & Sensors
  Map<String, double> _videoProgress = {};
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DeviceOrientation? _lastSensorOrientation;
  DateTime? _lastSaveTime;

  // Getters
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  double get playbackSpeed => _playbackSpeed;
  bool get showControls => _showControls;
  bool get isLandscape => _isLandscape;
  bool get isDraggingSeekbar => _isDraggingSeekbar;
  bool get isLocked => _isLocked;
  bool get isUnlockControlsVisible => _isUnlockControlsVisible;
  String? get activeTray => _activeTray;
  bool get isDraggingSpeedSlider => _isDraggingSpeedSlider;
  String get currentQuality => _currentQuality;
  String get currentSubtitle => _currentSubtitle;
  double get volume => _volume;
  double get brightness => _brightness;
  bool get showVolumeLabel => _showVolumeLabel;
  bool get showBrightnessLabel => _showBrightnessLabel;
  Map<String, double> get videoProgress => _videoProgress;
  String? get errorMessage => _errorMessage;

  String get currentTitle {
    if (playlist.isEmpty) return "No Video";
    return playlist[_currentIndex]['name'] ?? "Video";
  }

  VideoPlayerLogicController({
    required this.playlist,
    required int initialIndex,
  }) : _currentIndex = initialIndex {
    _init();
  }

  Future<void> _init() async {
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    player = Player();
    controller = VideoController(player);

    await _initVolumeBrightness();
    _setupPlayerListeners();
    _initSensor();
    await _initProgress();

    if (playlist.isNotEmpty && _currentIndex < playlist.length) {
      playVideo(_currentIndex);
    }

    _loadMissingDurations();
    startHideTimer();
  }

  void _setupPlayerListeners() {
    player.stream.position.listen((pos) {
      positionNotifier.value = pos;
      _handlePositionUpdate(pos);
    });

    player.stream.duration.listen((dur) {
      durationNotifier.value = dur;
      if (dur != Duration.zero) {
        final item = playlist[_currentIndex];
        if (item['duration'] == null || item['duration'] == "00:00") {
          item['duration'] = formatDurationString(dur);
          notifyListeners();
        }
      }
    });

    player.stream.playing.listen((p) {
      _isPlaying = p;
      if (p) _errorMessage = null; 
      notifyListeners();
    });

    player.stream.completed.listen((completed) {
      if (completed) {
        if (_currentIndex < playlist.length - 1) {
          playVideo(_currentIndex + 1);
        }
      }
    });

    player.stream.error.listen((error) {
      _errorMessage = error.toString();
      notifyListeners();
    });

    FlutterVolumeController.addListener((volume) {
      if (!_isChangingVolumeViaGesture) {
        _volume = volume;
        notifyListeners();
      }
    });
  }

  Future<void> _initVolumeBrightness() async {
    try {
      _initialSystemVolume = await FlutterVolumeController.getVolume() ?? VideoPlayerConstants.defaultVolume;
      _volume = _initialSystemVolume;
      _brightness = await ScreenBrightness().current;
      FlutterVolumeController.updateShowSystemUI(false);
      notifyListeners();
    } catch (e) {}
  }

  Future<void> _initProgress() async {
    await VideoPersistenceService.init();
    final paths = playlist.map((e) => e['path'] as String?).whereType<String>().toList();
    _videoProgress = await VideoPersistenceService.getAllProgress(paths);
    notifyListeners();
  }

  void _initSensor() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      if (!_isLandscape) return;
      const double threshold = VideoPlayerConstants.sensorRotationThreshold;
      if (event.x > threshold) {
        if (_lastSensorOrientation != DeviceOrientation.landscapeLeft) {
          SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
          _lastSensorOrientation = DeviceOrientation.landscapeLeft;
        }
      } else if (event.x < -threshold) {
        if (_lastSensorOrientation != DeviceOrientation.landscapeRight) {
          SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
          _lastSensorOrientation = DeviceOrientation.landscapeRight;
        }
      }
    });
  }

  Future<void> playVideo(int index) async {
    if (index < 0 || index >= playlist.length) return;
    _currentIndex = index;
    _showControls = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final item = playlist[index];
      final path = item['path'] as String?;
      if (path != null) {
        await player.open(Media(path), play: true);
        final progress = _videoProgress[path];
        if (progress != null && progress > 0 && progress < VideoPlayerConstants.watchedThreshold) {
          _resumeProgress(path, progress);
        }
      }
    } catch (e) {
      debugPrint('Error playing video: $e');
    }
  }

  void _resumeProgress(String path, double ratio) async {
    int attempts = 0;
    while (player.state.duration <= Duration.zero && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    if (player.state.duration > Duration.zero) {
      final targetMs = (player.state.duration.inMilliseconds * ratio).toInt();
      if (targetMs < player.state.duration.inMilliseconds - 5000) {
        await player.seek(Duration(milliseconds: targetMs));
      }
    }
  }

  void _handlePositionUpdate(Duration pos) {
    final dur = player.state.duration;
    if (dur <= Duration.zero) return;

    final ratio = pos.inMilliseconds / dur.inMilliseconds;
    final currentPath = playlist[_currentIndex]['path'] as String?;
    if (currentPath == null) return;

    double oldRatio = _videoProgress[currentPath] ?? 0.0;
    bool shouldNotify = false;

    if ((ratio - oldRatio).abs() > VideoPlayerConstants.significantProgressChange || 
        (oldRatio < VideoPlayerConstants.watchedThreshold && ratio >= VideoPlayerConstants.watchedThreshold)) {
      _videoProgress[currentPath] = ratio;
      shouldNotify = true;
    }
    if (ratio >= VideoPlayerConstants.completionThreshold && oldRatio < VideoPlayerConstants.completionThreshold) {
      _videoProgress[currentPath] = 1.0;
      VideoPersistenceService.saveProgress(currentPath, 1.0);
      shouldNotify = true;
    }
    if (shouldNotify) notifyListeners();

    final now = DateTime.now();
    if (_lastSaveTime == null || now.difference(_lastSaveTime!) > const Duration(seconds: 10)) {
      _lastSaveTime = now;
      VideoPersistenceService.saveProgress(currentPath, ratio);
    }
  }

  void handleVerticalDrag(DragUpdateDetails details, double screenWidth) {
    final dx = details.localPosition.dx;
    final delta = details.primaryDelta ?? 0;
    if (delta.abs() < 0.5) return;

    final double sensitivity = VideoPlayerConstants.gestureSensitivity;
    if (dx > screenWidth / 2) {
      double newVolume = _volume - (delta * sensitivity);
      if (newVolume <= 0) newVolume = 0;
      if (newVolume >= 1) newVolume = 1;
      if ((newVolume - _volume).abs() > 0.01 || newVolume == 0 || newVolume == 1) {
        _volume = newVolume;
        _isChangingVolumeViaGesture = true;
        FlutterVolumeController.setVolume(_volume);
        _showVolumeLabel = true;
        _showBrightnessLabel = false;
        notifyListeners();
        _volumeTimer?.cancel();
        _volumeTimer = Timer(VideoPlayerConstants.labelHideDuration, () {
          _isChangingVolumeViaGesture = false;
          _showVolumeLabel = false;
          notifyListeners();
        });
      }
    } else {
      double newBrightness = _brightness - (delta * sensitivity);
      if (newBrightness <= 0) newBrightness = 0;
      if (newBrightness >= 1) newBrightness = 1;
      if ((newBrightness - _brightness).abs() > 0.01 || newBrightness == 0 || newBrightness == 1) {
        _brightness = newBrightness;
        ScreenBrightness().setScreenBrightness(_brightness);
        _showBrightnessLabel = true;
        _showVolumeLabel = false;
        notifyListeners();
        _brightnessTimer?.cancel();
        _brightnessTimer = Timer(VideoPlayerConstants.labelHideDuration, () {
          _showBrightnessLabel = false;
          notifyListeners();
        });
      }
    }
  }

  void startHideTimer([Duration? duration, bool forcePlayCheck = false]) {
    _hideTimer?.cancel();
    _hideTimer = Timer(duration ?? VideoPlayerConstants.autoHideDuration, () {
      if ((player.state.playing || forcePlayCheck) && !_isLocked && _activeTray == null) {
        _showControls = false;
        _activeTray = null;
        if (_isLandscape) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
        notifyListeners();
      }
    });
  }

  void toggleControls() {
    if (_isLocked) {
      handleLockedTap();
      return;
    }
    _showControls = !_showControls;
    if (_showControls) {
      startHideTimer();
    } else {
      _activeTray = null;
      _showVolumeLabel = false;
      _showBrightnessLabel = false;
      if (_isLandscape) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
    notifyListeners();
  }

  void togglePlayPause() {
    player.playOrPause();
    startHideTimer();
  }

  void toggleLock() {
    _isLocked = !_isLocked;
    if (_isLocked) {
      _showControls = false;
      _isUnlockControlsVisible = true;
      _startUnlockHideTimer();
      if (_isLandscape) SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _unlockHideTimer?.cancel();
      _isUnlockControlsVisible = false;
      _showControls = true;
      startHideTimer();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    notifyListeners();
  }

  void _startUnlockHideTimer() {
    _unlockHideTimer?.cancel();
    _unlockHideTimer = Timer(VideoPlayerConstants.lockAutoHideDuration, () {
      if (_isLocked) {
        _isUnlockControlsVisible = false;
        notifyListeners();
      }
    });
  }

  void handleLockedTap() {
    _isUnlockControlsVisible = true;
    notifyListeners();
    _startUnlockHideTimer();
  }

  void toggleTray(String tray) {
    if (_activeTray == tray) {
      _activeTray = null;
      startHideTimer();
    } else {
      _activeTray = tray;
      _hideTimer?.cancel();
      _startTrayHideTimer();
    }
    notifyListeners();
  }

  void _startTrayHideTimer() {
    _trayHideTimer?.cancel();
    _trayHideTimer = Timer(VideoPlayerConstants.trayAutoHideDuration, () {
      _activeTray = null;
      startHideTimer();
      notifyListeners();
    });
  }

  void setTrayItem(String item) {
    if (_activeTray == 'quality') _currentQuality = item;
    else _currentSubtitle = item;
    _activeTray = null;
    startHideTimer();
    notifyListeners();
  }

  void setPlaybackSpeed(double s) {
    player.setRate(s);
    _playbackSpeed = s;
    _activeTray = null;
    startHideTimer();
    notifyListeners();
  }

  void seekRelative(int seconds) {
    if (_isLocked && _isLandscape) return;
    final current = player.state.position;
    final total = player.state.duration;
    var newPos = current + Duration(seconds: seconds);
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > total) newPos = total;
    player.seek(newPos);
    startHideTimer();
  }

  // Seekbar specific
  bool _wasPlayingBeforeDrag = false;
  double? _pendingSeekValue;
  bool _isSeeking = false;

  void onSeekbarChangeStart(double v) {
    _wasPlayingBeforeDrag = player.state.playing;
    player.pause();
    _isDraggingSeekbar = true;
    notifyListeners();
  }

  void onSeekbarChanged(double v) {
    _pendingSeekValue = v;
    if (!_isSeeking) _processSeekLoop();
  }

  void onSeekbarChangeEnd(double v) {
    _isDraggingSeekbar = false;
    _pendingSeekValue = null;
    player.seek(Duration(milliseconds: (v * 1000).toInt())).then((_) {
      if (_wasPlayingBeforeDrag) {
        player.play();
        startHideTimer(VideoPlayerConstants.seekAfterDragDelay, true);
      }
    });
    notifyListeners();
  }

  Future<void> _processSeekLoop() async {
    if (_isSeeking) return;
    _isSeeking = true;
    try {
      while (_pendingSeekValue != null) {
        final targetSeconds = _pendingSeekValue!;
        _pendingSeekValue = null;
        await player.seek(Duration(milliseconds: (targetSeconds * 1000).toInt()));
      }
    } catch (e) {
    } finally {
      _isSeeking = false;
      if (_pendingSeekValue != null) _processSeekLoop();
    }
  }

  Future<void> toggleOrientation(BuildContext context) async {
    if (_isLocked && _isLandscape) return;
    _activeTray = null;
    _showControls = false;
    notifyListeners();

    _showRotationOverlay(context);
    await Future.delayed(VideoPlayerConstants.orientationChangeOverlayDelay);

    if (_isLandscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      _isLandscape = false;
      _lastSensorOrientation = null;
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _isLandscape = true;
    }
    notifyListeners();

    await Future.delayed(VideoPlayerConstants.orientationRotationDuration);
    _removeRotationOverlay();
  }

  OverlayEntry? _overlayEntry;
  void _showRotationOverlay(BuildContext context) {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Container(color: Colors.black, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeRotationOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _loadMissingDurations() async {
    for (var item in playlist) {
      if (item['duration'] == null || item['duration'] == "00:00") {
        final path = item['path'] as String?;
        if (path != null) {
          final dur = await _getVideoDuration(path);
          if (dur != "00:00") {
            item['duration'] = dur;
            notifyListeners();
          }
        }
      }
    }
  }

  Future<String> _getVideoDuration(String path) async {
    final tempPlayer = Player();
    final completer = Completer<String>();
    tempPlayer.stream.duration.listen((dur) {
      if (dur != Duration.zero && !completer.isCompleted) completer.complete(formatDurationString(dur));
    });
    try {
      await tempPlayer.open(Media(path), play: false);
      final result = await completer.future.timeout(const Duration(seconds: 4), onTimeout: () => "00:00");
      await tempPlayer.dispose();
      return result;
    } catch (e) {
      await tempPlayer.dispose();
      return "00:00";
    }
  }

  String formatDurationString(Duration dur) {
    String two(int n) => n.toString().padLeft(2, "0");
    if (dur.inHours > 0) return "${dur.inHours}:${two(dur.inMinutes % 60)}:${two(dur.inSeconds % 60)}";
    return "${two(dur.inMinutes)}:${two(dur.inSeconds % 60)}";
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      FlutterVolumeController.setVolume(_initialSystemVolume);
      FlutterVolumeController.updateShowSystemUI(true);
    } else if (state == AppLifecycleState.resumed) {
      FlutterVolumeController.updateShowSystemUI(false);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _unlockHideTimer?.cancel();
    _trayHideTimer?.cancel();
    _volumeTimer?.cancel();
    _brightnessTimer?.cancel();
    _accelerometerSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    FlutterVolumeController.removeListener();
    WakelockPlus.disable();
    player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    positionNotifier.dispose();
    durationNotifier.dispose();
    super.dispose();
  }
}
