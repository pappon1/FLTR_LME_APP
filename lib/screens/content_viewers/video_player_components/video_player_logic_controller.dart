import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:audio_session/audio_session.dart';
import 'video_player_constants.dart';
import 'video_persistence_service.dart';
import 'video_playlist_manager.dart';
import 'video_gesture_handler.dart';
import 'video_engine_interface.dart';
import 'mediakit_video_engine.dart';

class VideoPlayerLogicController extends ChangeNotifier with WidgetsBindingObserver {
  final VideoPlaylistManager playlistManager;
  late final VideoGestureHandler gestureHandler;
  late final BaseVideoEngine engine;

  // Granular State Notifiers
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isBufferingNotifier = ValueNotifier(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<double> playbackSpeedNotifier = ValueNotifier(1.0);
  final ValueNotifier<bool> isReadyNotifier = ValueNotifier(false);
  
  // UI Visibility Notifiers
  final ValueNotifier<bool> showControlsNotifier = ValueNotifier(true);
  final ValueNotifier<bool> isLockedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isUnlockControlsVisibleNotifier = ValueNotifier(false);
  final ValueNotifier<String?> activeTrayNotifier = ValueNotifier(null);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);
  
  // Gesture Notifiers
  final ValueNotifier<double> volumeNotifier = ValueNotifier(VideoPlayerConstants.defaultVolume);
  final ValueNotifier<double> brightnessNotifier = ValueNotifier(VideoPlayerConstants.defaultBrightness);
  final ValueNotifier<bool> showVolumeLabelNotifier = ValueNotifier(false);
  final ValueNotifier<bool> showBrightnessLabelNotifier = ValueNotifier(false);

  // Seek Animation State
  final ValueNotifier<int?> seekIndicatorNotifier = ValueNotifier(null); 
  Timer? _seekIndicatorTimer;

  // Structural State
  bool _isLandscape = false;
  bool _isDraggingSeekbar = false;
  bool _isDraggingSpeedSlider = false;

  // Feature State
  String _currentQuality = "Auto";
  final List<String> qualities = ["Auto", "480p", "720p", "1080p", "1920p"];

  // Internal Logic State
  double _initialSystemVolume = VideoPlayerConstants.defaultVolume;
  bool _wasPlayingBeforeDrag = false;
  double? _pendingSeekValue;
  bool _isSeeking = false;
  
  // Timers
  Timer? _hideTimer;
  Timer? _unlockHideTimer;
  Timer? _trayHideTimer;

  // Persistence & Sensors
  Map<String, double> _videoProgress = {};
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DeviceOrientation? _lastSensorOrientation;
  
  // Debounced Persistence
  Timer? _saveDebounceTimer;
  String? _lastSavedPath;
  double? _lastSavedRatio;

  // Audio Session
  AudioSession? _session;

  // Getters
  List<Map<String, dynamic>> get playlist => playlistManager.playlist;
  int get currentIndex => playlistManager.currentIndexNotifier.value;
  ValueNotifier<int> get currentIndexNotifier => playlistManager.currentIndexNotifier;
  String get currentTitle => playlistManager.currentTitle;
  
  bool get isPlaying => isPlayingNotifier.value;
  bool get isBuffering => isBufferingNotifier.value;
  double get playbackSpeed => playbackSpeedNotifier.value;
  bool get showControls => showControlsNotifier.value;
  bool get isLandscape => _isLandscape;
  bool get isDraggingSeekbar => _isDraggingSeekbar;
  bool get isLocked => isLockedNotifier.value;
  bool get isUnlockControlsVisible => isUnlockControlsVisibleNotifier.value;
  String? get activeTray => activeTrayNotifier.value;
  bool get isDraggingSpeedSlider => _isDraggingSpeedSlider;
  String get currentQuality => _currentQuality;
  double get volume => volumeNotifier.value;
  double get brightness => brightnessNotifier.value;
  bool get showVolumeLabel => showVolumeLabelNotifier.value;
  bool get showBrightnessLabel => showBrightnessLabelNotifier.value;
  Map<String, double> get videoProgress => _videoProgress;
  String? get errorMessage => errorMessageNotifier.value;

  VideoPlayerLogicController({
    required List<Map<String, dynamic>> playlist,
    required int initialIndex,
    BaseVideoEngine? engineOverride,
  }) : playlistManager = VideoPlaylistManager(playlist: playlist, initialIndex: initialIndex) {
    engine = engineOverride ?? MediaKitVideoEngine();
    gestureHandler = VideoGestureHandler(
      volumeNotifier: volumeNotifier,
      brightnessNotifier: brightnessNotifier,
      showVolumeLabelNotifier: showVolumeLabelNotifier,
      showBrightnessLabelNotifier: showBrightnessLabelNotifier,
    );
    _init();
  }

  Future<void> _init() async {
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    await engine.init();
    await _initAudioSession();
    await _initVolumeBrightness();
    _setupPlayerListeners();
    _initSensor();
    await _initProgress();

    if (playlist.isNotEmpty) {
      await playVideo(currentIndex);
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      isReadyNotifier.value = true;
    });

    startHideTimer();
  }

  Future<void> _initAudioSession() async {
    _session = await AudioSession.instance;
    await _session!.configure(const AudioSessionConfiguration.music());
    
    _session!.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.duck) {
          engine.pause();
        } else {
          engine.pause();
        }
      } else {
        if (event.type != AudioInterruptionType.unknown) {
          engine.play();
        }
      }
    });

    if (await _session!.setActive(true)) {
      debugPrint("Audio session active");
    }
  }

  void _setupPlayerListeners() {
    engine.positionStream.listen((pos) {
      positionNotifier.value = pos;
      _handlePositionUpdate(pos);
    });

    engine.durationStream.listen((dur) {
      durationNotifier.value = dur;
      if (dur != Duration.zero) {
        if (playlist[currentIndex]['duration'] == null || playlist[currentIndex]['duration'] == "00:00") {
          playlistManager.updateDuration(currentIndex, formatDurationString(dur));
          // Use granular notify
        }
      }
    });

    engine.playingStream.listen((p) {
      isPlayingNotifier.value = p;
      if (p) {
        errorMessageNotifier.value = null; 
        _session?.setActive(true);
      }
    });

    engine.bufferingStream.listen((b) {
      isBufferingNotifier.value = b;
    });

    engine.completedStream.listen((completed) {
      if (completed) {
        if (playlistManager.next()) {
          playVideo(currentIndex);
        }
      }
    });

    engine.errorStream.listen((error) {
      errorMessageNotifier.value = error.toString();
    });

    FlutterVolumeController.addListener((v) {
      if (!gestureHandler.isChangingVolumeViaGesture) {
        volumeNotifier.value = v;
      }
    });
  }

  Future<void> _initVolumeBrightness() async {
    try {
      _initialSystemVolume = await FlutterVolumeController.getVolume() ?? VideoPlayerConstants.defaultVolume;
      volumeNotifier.value = _initialSystemVolume;
      brightnessNotifier.value = await ScreenBrightness().current;
      FlutterVolumeController.updateShowSystemUI(false);
    } catch (e) {}
  }

  Future<void> _initProgress() async {
    await VideoPersistenceService.init();
    final paths = playlist.map((e) => e['path'] as String?).whereType<String>().toList();
    _videoProgress = await VideoPersistenceService.getAllProgress(paths);
  }

  void _initSensor() {
    _resumeSensor();
  }

  void _resumeSensor() {
    _accelerometerSubscription?.cancel();
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

  void _pauseSensor() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  Future<void> playVideo(int index) async {
    if (index < 0 || index >= playlist.length) return;
    playlistManager.goToIndex(index);
    showControlsNotifier.value = true;
    errorMessageNotifier.value = null;

    try {
      final path = playlistManager.currentPath;
      if (path != null) {
        await engine.open(path, play: true);
        final progress = _videoProgress[path];
        if (progress != null && progress > 0 && progress < VideoPlayerConstants.watchedThreshold) {
          _resumeProgress(path, progress);
        }
      }
    } catch (e) {
      debugPrint('Error playing video: $e');
    }
    notifyListeners();
  }

  void _resumeProgress(String path, double ratio) async {
    int attempts = 0;
    while (engine.duration <= Duration.zero && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    if (engine.duration > Duration.zero) {
      final targetMs = (engine.duration.inMilliseconds * ratio).toInt();
      if (targetMs < engine.duration.inMilliseconds - 5000) {
        await engine.seek(Duration(milliseconds: targetMs));
      }
    }
  }

  void _handlePositionUpdate(Duration pos) {
    final dur = engine.duration;
    if (dur <= Duration.zero) return;

    final ratio = pos.inMilliseconds / dur.inMilliseconds;
    final currentPath = playlistManager.currentPath;
    if (currentPath == null) return;

    double oldRatio = _videoProgress[currentPath] ?? 0.0;

    if ((ratio - oldRatio).abs() > VideoPlayerConstants.significantProgressChange || 
        (oldRatio < VideoPlayerConstants.watchedThreshold && ratio >= VideoPlayerConstants.watchedThreshold)) {
      _videoProgress[currentPath] = ratio;
      // Granularly notify playlist if needed, for now we do notifyListeners 
      // but less frequently thanks to significantProgressChange
      notifyListeners();
    }
    if (ratio >= VideoPlayerConstants.completionThreshold && oldRatio < VideoPlayerConstants.completionThreshold) {
      _videoProgress[currentPath] = 1.0;
      _lastSavedPath = currentPath;
      _lastSavedRatio = 1.0;
      VideoPersistenceService.saveProgress(currentPath, 1.0);
      notifyListeners();
    }
    
    // Debounced Persistence
    _lastSavedPath = currentPath;
    _lastSavedRatio = ratio;
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(seconds: 15), () {
      if (_lastSavedPath != null && _lastSavedRatio != null) {
        VideoPersistenceService.saveProgress(_lastSavedPath!, _lastSavedRatio!);
      }
    });
  }

  void handleVerticalDragStart() {
    gestureHandler.handleVerticalDragStart();
  }

  void handleVerticalDrag(DragUpdateDetails details, double screenWidth) {
    gestureHandler.handleVerticalDrag(details, screenWidth);
  }

  void startHideTimer([Duration? duration, bool forcePlayCheck = false]) {
    _hideTimer?.cancel();
    _hideTimer = Timer(duration ?? VideoPlayerConstants.autoHideDuration, () {
      if ((engine.isPlaying || forcePlayCheck) && !isLocked && activeTray == null && !_isDraggingSpeedSlider) {
        showControlsNotifier.value = false;
        activeTrayNotifier.value = null;
        if (_isLandscape) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
      }
    });
  }

  void toggleControls() {
    if (isLocked) {
      handleLockedTap();
      return;
    }
    showControlsNotifier.value = !showControlsNotifier.value;
    if (showControlsNotifier.value) {
      startHideTimer();
    } else {
      activeTrayNotifier.value = null;
      showVolumeLabelNotifier.value = false;
      showBrightnessLabelNotifier.value = false;
      if (_isLandscape) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
  }

  void togglePlayPause() {
    engine.playOrPause();
    startHideTimer();
  }

  void toggleLock() {
    isLockedNotifier.value = !isLockedNotifier.value;
    if (isLockedNotifier.value) {
      showControlsNotifier.value = false;
      isUnlockControlsVisibleNotifier.value = true;
      _startUnlockHideTimer();
      if (_isLandscape) SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _unlockHideTimer?.cancel();
      isUnlockControlsVisibleNotifier.value = false;
      showControlsNotifier.value = true;
      startHideTimer();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _startUnlockHideTimer() {
    _unlockHideTimer?.cancel();
    _unlockHideTimer = Timer(VideoPlayerConstants.lockAutoHideDuration, () {
      if (isLocked) {
        isUnlockControlsVisibleNotifier.value = false;
      }
    });
  }

  void handleLockedTap() {
    isUnlockControlsVisibleNotifier.value = true;
    _startUnlockHideTimer();
  }

  void toggleTray(String tray) {
    if (activeTray == tray) {
      activeTrayNotifier.value = null;
      _trayHideTimer?.cancel();
      startHideTimer();
    } else {
      activeTrayNotifier.value = tray;
      _hideTimer?.cancel();
      _startTrayHideTimer();
    }
  }

  void _startTrayHideTimer() {
    _trayHideTimer?.cancel();
    _trayHideTimer = Timer(VideoPlayerConstants.trayAutoHideDuration, () {
      if (activeTray != null && !_isDraggingSpeedSlider) {
        activeTrayNotifier.value = null;
        startHideTimer();
      }
    });
  }

  void setTrayItem(String item) {
    if (activeTray == 'quality') _currentQuality = item;
    activeTrayNotifier.value = null;
    startHideTimer();
    notifyListeners();
  }

  // Optimized Speed Handling
  void updatePlaybackSpeed(double s, {bool isFinal = false}) {
    engine.setRate(s);
    playbackSpeedNotifier.value = s;
    _isDraggingSpeedSlider = !isFinal;
    
    if (isFinal) {
      activeTrayNotifier.value = null;
      startHideTimer();
    } else {
      _hideTimer?.cancel();
      _trayHideTimer?.cancel();
    }
    notifyListeners();
  }

  void setPlaybackSpeed(double s) {
    updatePlaybackSpeed(s, isFinal: true);
  }

  void seekRelative(int seconds) {
    if (isLocked && _isLandscape) return;
    
    seekIndicatorNotifier.value = seconds;
    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 600), () {
      seekIndicatorNotifier.value = null;
    });

    final current = engine.position;
    final total = engine.duration;
    var newPos = current + Duration(seconds: seconds);
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > total) newPos = total;
    engine.seek(newPos);
    startHideTimer();
  }

  void onSeekbarChangeStart(double v) {
    _wasPlayingBeforeDrag = engine.isPlaying;
    engine.pause();
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
    engine.seek(Duration(milliseconds: (v * 1000).toInt())).then((_) {
      if (_wasPlayingBeforeDrag) {
        engine.play();
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
        await engine.seek(Duration(milliseconds: (targetSeconds * 1000).toInt()));
      }
    } catch (e) {
    } finally {
      _isSeeking = false;
      if (_pendingSeekValue != null) _processSeekLoop();
    }
  }

  Future<void> toggleOrientation(BuildContext context) async {
    if (isLocked && _isLandscape) return;
    activeTrayNotifier.value = null;
    showControlsNotifier.value = false;

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

  bool _isMetadataWorkerRunning = false;
  


  String formatDurationString(Duration dur) {
    String two(int n) => n.toString().padLeft(2, "0");
    if (dur.inHours > 0) return "${dur.inHours}:${two(dur.inMinutes % 60)}:${two(dur.inSeconds % 60)}";
    return "${two(dur.inMinutes)}:${two(dur.inSeconds % 60)}";
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      engine.pause(); 
      FlutterVolumeController.setVolume(_initialSystemVolume);
      FlutterVolumeController.updateShowSystemUI(true);
      _pauseSensor();
      if (_lastSavedPath != null && _lastSavedRatio != null) {
        VideoPersistenceService.saveProgress(_lastSavedPath!, _lastSavedRatio!);
      }
    } else if (state == AppLifecycleState.resumed) {
      FlutterVolumeController.updateShowSystemUI(false);
      _resumeSensor();
      _session?.setActive(true);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _unlockHideTimer?.cancel();
    _trayHideTimer?.cancel();
    _saveDebounceTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    gestureHandler.dispose();
    _accelerometerSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    FlutterVolumeController.removeListener();
    WakelockPlus.disable();
    engine.dispose();
    playlistManager.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    positionNotifier.dispose();
    durationNotifier.dispose();
    isPlayingNotifier.dispose();
    isBufferingNotifier.dispose();
    playbackSpeedNotifier.dispose();
    showControlsNotifier.dispose();
    isLockedNotifier.dispose();
    isUnlockControlsVisibleNotifier.dispose();
    activeTrayNotifier.dispose();
    errorMessageNotifier.dispose();
    volumeNotifier.dispose();
    brightnessNotifier.dispose();
    showVolumeLabelNotifier.dispose();
    showBrightnessLabelNotifier.dispose();
    seekIndicatorNotifier.dispose();
    isReadyNotifier.dispose();
    super.dispose();
  }
}
