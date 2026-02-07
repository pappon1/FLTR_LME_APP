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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart'; // Direct access for metadata extraction

class VideoPlayerLogicController extends ChangeNotifier
    with WidgetsBindingObserver {
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
  final ValueNotifier<bool> isUnlockControlsVisibleNotifier = ValueNotifier(
    false,
  );
  final ValueNotifier<String?> activeTrayNotifier = ValueNotifier(null);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);

  // Gesture Notifiers
  final ValueNotifier<double> volumeNotifier = ValueNotifier(
    VideoPlayerConstants.defaultVolume,
  );
  final ValueNotifier<double> brightnessNotifier = ValueNotifier(
    VideoPlayerConstants.defaultBrightness,
  );
  final ValueNotifier<bool> showVolumeLabelNotifier = ValueNotifier(false);
  final ValueNotifier<bool> showBrightnessLabelNotifier = ValueNotifier(false);
  final ValueNotifier<Map<String, double>> progressNotifier = ValueNotifier({});

  // Landscape Playlist State
  final ValueNotifier<bool> showPlaylistNotifier = ValueNotifier(false);

  // Smart Metadata Extraction State
  final _metadataPlayer = Player(); // Dedicated player for background metadata
  bool _isExtractingMetadata = false;
  final List<int> _metadataQueue = [];

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
  bool _isDisposed = false;

  // Timers
  Timer? _hideTimer;
  Timer? _unlockHideTimer;
  Timer? _trayHideTimer;

  // Persistence & Sensors
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
  ValueNotifier<int> get currentIndexNotifier =>
      playlistManager.currentIndexNotifier;
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
  Map<String, double> get videoProgress => progressNotifier.value;
  String? get errorMessage => errorMessageNotifier.value;

  VideoPlayerLogicController({
    required List<Map<String, dynamic>> playlist,
    required int initialIndex,
    BaseVideoEngine? engineOverride,
  }) : playlistManager = VideoPlaylistManager(
         playlist: playlist,
         initialIndex: initialIndex,
       ) {
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
    unawaited(WakelockPlus.enable());

    await engine.init();
    await _initAudioSession();
    await _initVolumeBrightness();
    _setupPlayerListeners();
    _initSensor();
    await _initProgress();

    // UI/UX Optimization: Load preferred quality (Defaults to 480p to save user data)
    final prefs = await SharedPreferences.getInstance();
    _currentQuality = prefs.getString('pref_video_quality') ?? "480p";

    if (playlist.isNotEmpty) {
      await playVideo(currentIndex);
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      isReadyNotifier.value = true;
    });

    startHideTimer();

    // Start Smart Duration Extraction (Low Priority)
    Future.delayed(const Duration(seconds: 2), _processDurationQueue);
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
      // debugPrint("Audio session active");
    }
  }

  final List<StreamSubscription> _subscriptions = [];

  void _setupPlayerListeners() {
    _subscriptions.add(
      engine.positionStream.listen((pos) {
        if (!_isDisposed) positionNotifier.value = pos;
        _handlePositionUpdate(pos);
      }),
    );

    _subscriptions.add(
      engine.durationStream.listen((dur) {
        if (!_isDisposed) durationNotifier.value = dur;
        if (dur != Duration.zero) {
          if (playlist[currentIndex]['duration'] == null ||
              playlist[currentIndex]['duration'] == "00:00") {
            playlistManager.updateDuration(
              currentIndex,
              formatDurationString(dur),
            );
          }
        }
      }),
    );

    _subscriptions.add(
      engine.playingStream.listen((p) {
        if (!_isDisposed) isPlayingNotifier.value = p;
        if (p) {
          if (!_isDisposed) errorMessageNotifier.value = null;
          _session?.setActive(true);
        }
      }),
    );

    _subscriptions.add(
      engine.bufferingStream.listen((b) {
        if (!_isDisposed) isBufferingNotifier.value = b;
      }),
    );

    _subscriptions.add(
      engine.completedStream.listen((completed) {
        if (completed) {
          if (playlistManager.next()) {
            playVideo(currentIndex);
          }
        }
      }),
    );

    final errorSub = engine.errorStream.listen((error) {
      if (!_isDisposed) {
        errorMessageNotifier.value = error.toString();
        _handleError();
      }
    });
    _subscriptions.add(errorSub);

    FlutterVolumeController.addListener((v) {
      if (!gestureHandler.isChangingVolumeViaGesture) {
        if (!_isDisposed) volumeNotifier.value = v;
      }
    });
  }

  Future<void> _initVolumeBrightness() async {
    try {
      _initialSystemVolume =
          await FlutterVolumeController.getVolume() ??
          VideoPlayerConstants.defaultVolume;
      volumeNotifier.value = _initialSystemVolume;
      brightnessNotifier.value = await ScreenBrightness().application;
      unawaited(FlutterVolumeController.updateShowSystemUI(false));
    } catch (e) {
      debugPrint('Error init brightness: $e');
    }
  }

  Future<void> _initProgress() async {
    await VideoPersistenceService.init();
    final paths = playlist
        .map((e) => e['path'] as String?)
        .whereType<String>()
        .toList();
    progressNotifier.value = await VideoPersistenceService.getAllProgress(
      paths,
    );
  }

  void _initSensor() {
    _resumeSensor();
  }

  void _resumeSensor() {
    _accelerometerSubscription?.cancel();
    // Optimization: Only listen to sensor in Landscape mode to save battery
    // because our specific logic only handles Landscape Left <-> Right rotation
    if (!_isLandscape) return;

    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      const double threshold = VideoPlayerConstants.sensorRotationThreshold;
      if (event.x > threshold) {
        if (_lastSensorOrientation != DeviceOrientation.landscapeLeft) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
          ]);
          _lastSensorOrientation = DeviceOrientation.landscapeLeft;
        }
      } else if (event.x < -threshold) {
        if (_lastSensorOrientation != DeviceOrientation.landscapeRight) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeRight,
          ]);
          _lastSensorOrientation = DeviceOrientation.landscapeRight;
        }
      }
    });
  }

  void _pauseSensor() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  // --- Smart Duration Extraction Logic (Lag-Free & No Cache) ---
  Future<void> _processDurationQueue() async {
    if (_isExtractingMetadata) return;

    // 1. Identify missing durations
    for (int i = 0; i < playlist.length; i++) {
      final item = playlist[i];
      if (item['duration'] == null || item['duration'] == "00:00") {
        _metadataQueue.add(i);
      }
    }

    if (_metadataQueue.isEmpty) return;

    _isExtractingMetadata = true;
    final prefs = await SharedPreferences.getInstance();

    // 2. Process Queue Sequentially
    while (_metadataQueue.isNotEmpty && !_isDisposed) {
      final index = _metadataQueue.removeAt(0);
      if (index >= playlist.length) continue;

      final item = playlist[index];
      final path = item['path'];

      // Check Cache First (Strong Persistence)
      final cachedDuration = prefs.getString('dur_$path');
      if (cachedDuration != null) {
        playlistManager.updateDuration(index, cachedDuration);
        continue;
      }

      // Extract using Background Player
      if (path != null) {
        try {
          await _metadataPlayer.open(Media(path), play: false);
          // Wait for metadata
          await _metadataPlayer.stream.duration
              .firstWhere((d) => d != Duration.zero)
              .timeout(const Duration(seconds: 2));
          final duration = _metadataPlayer.state.duration;

          if (duration != Duration.zero) {
            final fmt = formatDurationString(duration);
            playlistManager.updateDuration(index, fmt);

            // Save to DB (One-time save)
            await prefs.setString('dur_$path', fmt);
          }
        } catch (e) {
          // Ignore errors, skip item
        }
      }

      // Anti-Lag Delay: Yield control back to UI
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isExtractingMetadata = false;
  }

  void togglePlaylist() {
    showPlaylistNotifier.value = !showPlaylistNotifier.value;
    if (showPlaylistNotifier.value) {
      startHideTimer(const Duration(seconds: 5)); // Longer timer for playlist
    } else {
      startHideTimer();
    }
  }

  void playNextVideo() {
    if (playlistManager.hasNext) {
      playVideo(currentIndex + 1);
    }
  }

  void playPreviousVideo() {
    if (playlistManager.hasPrev) {
      playVideo(currentIndex - 1);
    }
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

        if (playbackSpeedNotifier.value != 1.0) {
          await engine.setRate(playbackSpeedNotifier.value);
        }

        // Apply persistent quality preference
        if (_currentQuality != "Auto") {
          await engine.setVideoTrack(_currentQuality);
        }

        final progress = progressNotifier.value[path];
        if (progress != null &&
            progress > 0 &&
            progress < VideoPlayerConstants.watchedThreshold) {
          _resumeProgress(path, progress);
        }
        _retryCount = 0; // Reset retry on success
      }
    } catch (e) {
      _handleError();
    }
    notifyListeners();
  }

  int _retryCount = 0;
  static const int maxRetries = 3;

  void _handleError() {
    if (_retryCount < maxRetries) {
      _retryCount++;
      debugPrint('Retrying video playback... attempt $_retryCount');
      Future.delayed(Duration(seconds: _retryCount * 2), () {
        if (!_isDisposed && errorMessageNotifier.value != null) {
          playVideo(currentIndex);
        }
      });
    }
  }

  Future<void> retryCurrentVideo() async {
    _retryCount = 0;
    unawaited(playVideo(currentIndex));
  }

  void _resumeProgress(String path, double ratio) async {
    // Logic Fix: Wait for duration using Stream instead of polling loop
    if (engine.duration <= Duration.zero) {
      try {
        await engine.durationStream
            .firstWhere((d) => d > Duration.zero)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        // Timeout, cannot resume
        return;
      }
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

    final double oldRatio = progressNotifier.value[currentPath] ?? 0.0;

    if ((ratio - oldRatio).abs() >
            VideoPlayerConstants.significantProgressChange ||
        (oldRatio < VideoPlayerConstants.watchedThreshold &&
            ratio >= VideoPlayerConstants.watchedThreshold)) {
      final newMap = Map<String, double>.from(progressNotifier.value);
      newMap[currentPath] = ratio;
      progressNotifier.value = newMap;
    }
    if (ratio >= VideoPlayerConstants.completionThreshold &&
        oldRatio < VideoPlayerConstants.completionThreshold) {
      final newMap = Map<String, double>.from(progressNotifier.value);
      newMap[currentPath] = 1.0;
      progressNotifier.value = newMap;
      _lastSavedPath = currentPath;
      _lastSavedRatio = 1.0;
      VideoPersistenceService.saveProgress(currentPath, 1.0);
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

  // --- Manual Pointer Logic (Replaces GestureDetector for Zoom Compatibility) ---
  void handleDoubleTap(double x, double screenWidth) {
    if (isLocked) return;
    if (x > screenWidth / 2) {
      seekRelative(10);
    } else {
      seekRelative(-10);
    }
  }

  void handleVerticalDragStart(DragStartDetails details, double screenWidth) {
    gestureHandler.handleVerticalDragStart(
      details.localPosition.dx,
      screenWidth,
    );
  }

  void handleVerticalDrag(DragUpdateDetails details, double screenWidth) {
    gestureHandler.handleVerticalDrag(details, screenWidth);
  }

  void handleVerticalDragEnd() {
    gestureHandler.handleVerticalDragEnd();
  }

  void startHideTimer([Duration? duration, bool forcePlayCheck = false]) {
    _hideTimer?.cancel();
    _hideTimer = Timer(duration ?? VideoPlayerConstants.autoHideDuration, () {
      if ((engine.isPlaying || forcePlayCheck) &&
          !isLocked &&
          activeTray == null &&
          !_isDraggingSpeedSlider) {
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
      if (_isLandscape)
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
    if (activeTray == 'quality') {
      _currentQuality = item;
      unawaited(engine.setVideoTrack(item));

      // Persist preference
      unawaited(
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('pref_video_quality', item);
        }),
      );
    }
    activeTrayNotifier.value = null;
    startHideTimer();
    notifyListeners();
  }

  void resetTrayHideTimer() {
    if (activeTrayNotifier.value != null) {
      _startTrayHideTimer();
    } else {
      startHideTimer();
    }
  }

  // Optimized Speed Handling
  void updatePlaybackSpeed(double s) {
    engine.setRate(s);
    playbackSpeedNotifier.value = s;
    _isDraggingSpeedSlider = true;

    // While dragging, cancel timers
    _hideTimer?.cancel();
    _trayHideTimer?.cancel();
    notifyListeners();
  }

  void onSpeedSliderEnd(double s) {
    _isDraggingSpeedSlider = false;
    // Don't close immediately, just restart timer (Smart optimize)
    _startTrayHideTimer();
  }

  void setPlaybackSpeed(double s) {
    // For direct button presses, close immediately
    engine.setRate(s);
    playbackSpeedNotifier.value = s;
    activeTrayNotifier.value = null;
    startHideTimer();
    notifyListeners();
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
        await engine.seek(
          Duration(milliseconds: (targetSeconds * 1000).toInt()),
        );
      }
    } finally {
      _isSeeking = false;
      if (_pendingSeekValue != null) unawaited(_processSeekLoop());
    }
  }

  Future<void> toggleOrientation(BuildContext context) async {
    if (isLocked && _isLandscape) return;
    activeTrayNotifier.value = null;
    showControlsNotifier.value = false;

    _showRotationOverlay(context);
    await Future.delayed(VideoPlayerConstants.orientationChangeOverlayDelay);

    if (_isLandscape) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      _isLandscape = false;
      _lastSensorOrientation = null;
      _pauseSensor(); // Stop sensor in Portrait
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _isLandscape = true;
      _resumeSensor(); // Start sensor in Landscape
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
        child: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeRotationOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  String formatDurationString(Duration dur) {
    String two(int n) => n.toString().padLeft(2, "0");
    if (dur.inHours > 0)
      return "${dur.inHours}:${two(dur.inMinutes % 60)}:${two(dur.inSeconds % 60)}";
    return "${two(dur.inMinutes)}:${two(dur.inSeconds % 60)}";
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
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
    _isDisposed = true;
    for (final s in _subscriptions) {
      s.cancel();
    }
    _hideTimer?.cancel();
    _unlockHideTimer?.cancel();
    _trayHideTimer?.cancel();
    _saveDebounceTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _metadataPlayer.dispose(); // Cleanup background player
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
    progressNotifier.dispose();
    super.dispose();
  }
}
