import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver {
  late final Player player;
  late final VideoController controller;

  // Player State
  late int _currentIndex;
  bool _isPlaying = false;
  
  // Performance: ValueNotifiers for granular UI updates
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(Duration.zero);
  double _playbackSpeed = 1.0;
  
  // UI State
  bool _showControls = true;
  bool _isLandscape = false;
  bool _isDraggingSeekbar = false;
  bool _isLocked = false;
  Timer? _hideTimer;
  
  // Lock UI State
  bool _isUnlockControlsVisible = false;
  Timer? _unlockHideTimer;

  // Tray State
  String? _activeTray;
  Timer? _trayHideTimer;
  bool _isDraggingSpeedSlider = false;

  // Feature State
  String _currentQuality = "Auto";
  String _currentSubtitle = "Off"; 
  List<String> _subtitles = ["Off", "English", "Bengali", "Hindi"];
  List<String> _qualities = ["Auto", "480p", "720p", "1080p", "1920p"];

  // Gesture State
  double _volume = 0.5;
  double _initialSystemVolume = 0.5;
  bool _isChangingVolumeViaGesture = false; 
  double _brightness = 0.5;
  bool _showVolumeLabel = false;
  bool _showBrightnessLabel = false;
  Timer? _volumeTimer;
  Timer? _brightnessTimer;
  final ScrollController _playlistScrollController = ScrollController();
  
  // Sensor State
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DeviceOrientation? _lastSensorOrientation;

  // Progress State
  Map<String, double> _videoProgress = {}; // key: path, value: ratio (0.0 to 1.0)
  late SharedPreferences _prefs;
  bool _prefsInitialized = false;
  StreamSubscription? _posSubscription;
  DateTime? _lastSaveTime;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    
    // Feature: Prevent Screen Sleep
    WakelockPlus.enable();

    // Feature: Initialize Volume/Brightness
    _initVolumeBrightness();
    
    // Start listening to volume changes immediately
    FlutterVolumeController.addListener((volume) {
      // ONLY update state if the user is NOT actively swiping.
      // This prevents the "jerking" where the system's discrete volume steps
      // fight with the smooth double value from the gesture.
      if (!_isChangingVolumeViaGesture) {
        _volume = volume;
        if (mounted) setState(() {});
      }
    });

    // Initialize Player
    player = Player();
    controller = VideoController(player);
    
    _setupPlayerListeners();

    // Start initial video
    if (widget.playlist.isNotEmpty && _currentIndex < widget.playlist.length) {
      _playVideo(_currentIndex);
    }
    
    // Background scan for missing durations
    Future.delayed(const Duration(seconds: 1), () => _loadMissingDurations());

    _startHideTimer();
    _initSensor();
    _initProgress();
  }

  void _setupPlayerListeners() {
    player.stream.position.listen((pos) {
       _positionNotifier.value = pos;
       _handlePositionUpdate(pos);
    });

    player.stream.duration.listen((dur) {
       _durationNotifier.value = dur;
       // Feature: Update real duration in playlist if it was missing
       if (dur != Duration.zero) {
          final item = widget.playlist[_currentIndex];
          final formatted = _formatDurationString(dur);
          if (item['duration'] == null || item['duration'] == "00:00") {
             item['duration'] = formatted;
             // Only setState for the playlist duration update
             if (mounted) setState(() {});
          }
       }
    });

    player.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
    
    player.stream.buffering.listen((b) {
      // Buffering state not used in UI for now
    });

    player.stream.completed.listen((completed) {
      if (completed) {
        if (_currentIndex < widget.playlist.length - 1) {
          _playVideo(_currentIndex + 1);
        }
      }
    });
    
    player.stream.error.listen((error) {
       debugPrint("Player Error: $error");
    });
  }

  Future<void> _loadMissingDurations() async {
    for (int i = 0; i < widget.playlist.length; i++) {
        final item = widget.playlist[i];
        if (item['duration'] == null || item['duration'] == "00:00") {
           final path = item['path'] as String?;
           if (path != null) {
              final dur = await _getVideoDuration(path);
              if (dur != "00:00" && mounted) {
                 setState(() {
                   item['duration'] = dur;
                 });
              }
           }
        }
    }
  }

  Future<String> _getVideoDuration(String path) async {
    final tempPlayer = Player();
    final completer = Completer<String>();
    
    final subscription = tempPlayer.stream.duration.listen((dur) {
      if (dur != Duration.zero && !completer.isCompleted) {
        completer.complete(_formatDurationString(dur));
      }
    });

    try {
      await tempPlayer.open(Media(path), play: false);
      final result = await completer.future.timeout(
        const Duration(seconds: 4), 
        onTimeout: () => "00:00"
      );
      await subscription.cancel();
      await tempPlayer.dispose();
      return result;
    } catch (e) {
      await subscription.cancel();
      await tempPlayer.dispose();
      return "00:00";
    }
  }

  String _formatDurationString(Duration dur) {
    String two(int n) => n.toString().padLeft(2, "0");
    if (dur.inHours > 0) {
      return "${dur.inHours}:${two(dur.inMinutes % 60)}:${two(dur.inSeconds % 60)}";
    } else {
      return "${two(dur.inMinutes)}:${two(dur.inSeconds % 60)}";
    }
  }

  void _initSensor() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      if (!_isLandscape) return; // Only control rotation when in manual landscape mode

      const double threshold = 5.0; // Lowered threshold slightly for better responsiveness

      // x > threshold => Landscape Left (Top of phone to left) - Gravity on positive X
      // x < -threshold => Landscape Right (Top of phone to right) - Gravity on negative X
      
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
    }); // End Listen
  }

  Future<void> _initVolumeBrightness() async {
    try {
      // Capture the REAL initial volume before any app-specific changes
      _initialSystemVolume = await FlutterVolumeController.getVolume() ?? 0.5;
      _volume = _initialSystemVolume;
      _brightness = await ScreenBrightness().current;
      
      FlutterVolumeController.updateShowSystemUI(false);
      if (mounted) setState(() {});
    } catch (e) {}
  }

  Future<void> _playVideo(int index) async {
    if (index < 0 || index >= widget.playlist.length) return;

    setState(() {
      _currentIndex = index;
      _showControls = true;
    });
    
    // Feature: Playlist Auto Scroll
    _scrollToCurrent();

    try {
      final item = widget.playlist[index];
      final path = item['path'] as String?;
      
      if (path != null) {
        await player.open(Media(path), play: true);
        
        // Resume from saved progress
        if (_prefsInitialized) {
          final progress = _videoProgress[path];
          if (progress != null && progress > 0 && progress < 0.95) {
             // Wait for duration to be available before seeking precisely
             // For simplicity, we can try seeking immediately after open, 
             // MediaKit usually handles this well.
             
             // Wait for a small delay or a one-time listener
             _resumeProgress(path, progress);
          }
        }
      }
    } catch (e) {
      debugPrint('Error playing video: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error playing video: $e'), backgroundColor: Colors.red),
         );
      }
    }
  }

  void _resumeProgress(String path, double ratio) async {
    // Wait until duration is loaded
    int attempts = 0;
    while (player.state.duration <= Duration.zero && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (player.state.duration > Duration.zero) {
      final targetMs = (player.state.duration.inMilliseconds * ratio).toInt();
      // Don't resume if it's almost at the end
      if (targetMs < player.state.duration.inMilliseconds - 5000) {
        await player.seek(Duration(milliseconds: targetMs));
      }
    }
  }
  
  Future<void> _onVerticalDragUpdate(DragUpdateDetails details) async {
    // Block if it started as a horizontal drag (though GestureDetector usually handles this separation, explicit checks help)
    // Actually, simply relying on onVerticalDragUpdate is usually enough if onHorizontal isn't consuming it.
    // However, user wants to BLOCK vertical gestures if the user is swiping horizontally.
    // The issue is likely that slight vertical movement during a horizontal swipe triggers this.
    
    // To fix this robustly:
    // We check the primary delta. If the user is moving more horizontally than vertically, ignore.
    // But DragUpdateDetails in onVerticalDragUpdate only gives vertical delta usually if the detector is purely vertical.
    
    // Better approach: Use onScale or check pure deltas.
    // But since we are inside onVerticalDragUpdate, the system has already decided it's a vertical drag?
    // User says "horizontal gesture karne se ye dono gesture kam nehi karna chaiye".
    // This means if I am seeking (horizontal), volume/brightness shouldn't change.
    
    // Since we don't have a horizontal drag handler on this SAME detector, Flutter might be lenient.
    // Let's enforce that we ONLY respond if we are sure it's vertical.
    
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;
    final delta = details.primaryDelta ?? 0;
    
    // If delta is very small, ignore
    if (delta.abs() < 0.5) return;

    // Sensitivity
    final double sensitivity = 0.01;

    if (dx > width / 2) {
      // Right Side -> Volume
      double newVolume = _volume - (delta * sensitivity);
      if (newVolume <= 0) { newVolume = 0; }
      if (newVolume >= 1) { newVolume = 1; }
      
      // Only update if change is significant to prevent hardware lag/jerking
      if ((newVolume - _volume).abs() > 0.01 || newVolume == 0 || newVolume == 1) {
        _volume = newVolume;
        _isChangingVolumeViaGesture = true;
        FlutterVolumeController.setVolume(_volume);

        setState(() {
          _showVolumeLabel = true;
          _showBrightnessLabel = false;
        });
        _volumeTimer?.cancel();
        _volumeTimer = Timer(const Duration(seconds: 2), () {
           _isChangingVolumeViaGesture = false;
           if (mounted) setState(() => _showVolumeLabel = false);
        });
      }

    } else {
      // Left Side -> Brightness
      double newBrightness = _brightness - (delta * sensitivity);
      if (newBrightness <= 0) { newBrightness = 0; }
      if (newBrightness >= 1) { newBrightness = 1; }

      if ((newBrightness - _brightness).abs() > 0.01 || newBrightness == 0 || newBrightness == 1) {
        _brightness = newBrightness;
        try {
          ScreenBrightness().setScreenBrightness(_brightness);
        } catch(e) {}

        setState(() {
          _showBrightnessLabel = true;
          _showVolumeLabel = false;
        });
        _brightnessTimer?.cancel();
        _brightnessTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showBrightnessLabel = false);
        });
      }
    }
  }

  void _scrollToCurrent() {
    if (_playlistScrollController.hasClients) {
       Future.delayed(const Duration(milliseconds: 100), () {
          if (_playlistScrollController.hasClients) {
             _playlistScrollController.animateTo(
               _currentIndex * 100.0, 
               duration: const Duration(milliseconds: 300), 
               curve: Curves.easeInOut
             );
          }
       });
    }
  }

  Future<void> _initProgress() async {
    _prefs = await SharedPreferences.getInstance();
    _prefsInitialized = true;
    
    // Load existing progress for all videos in playlist
    Map<String, double> loadedProgress = {};
    for (var item in widget.playlist) {
      final path = item['path'] as String?;
      if (path != null) {
        final key = 'progress_$path';
        final saved = _prefs.getDouble(key);
        if (saved != null) {
          loadedProgress[path] = saved;
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _videoProgress = loadedProgress;
      });
    }
  }

  void _handlePositionUpdate(Duration pos) {
    if (!_prefsInitialized) return;
    final dur = player.state.duration;
    if (dur <= Duration.zero) return;

    final ratio = pos.inMilliseconds / dur.inMilliseconds;
    final currentPath = widget.playlist[_currentIndex]['path'] as String?;
    
    if (currentPath != null) {
      bool shouldUpdateUI = false;
      
      // Update local cache if significant change (0.5% or crossed 90% "Watched" threshold)
      double oldRatio = _videoProgress[currentPath] ?? 0.0;
      if ((ratio - oldRatio).abs() > 0.005 || (oldRatio < 0.9 && ratio >= 0.9)) {
        _videoProgress[currentPath] = ratio;
        shouldUpdateUI = true;
      }

      // Final completion
      if (ratio >= 0.99 && oldRatio < 0.99) {
        _videoProgress[currentPath] = 1.0;
        _prefs.setDouble('progress_$currentPath', 1.0);
        shouldUpdateUI = true;
      }

      if (shouldUpdateUI && mounted) {
        setState(() {});
      }

      // Periodic persistent save (every 10 seconds)
      final now = DateTime.now();
      if (_lastSaveTime == null || now.difference(_lastSaveTime!) > const Duration(seconds: 10)) {
        _lastSaveTime = now;
        _prefs.setDouble('progress_$currentPath', ratio);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Revert volume when app goes to background
      FlutterVolumeController.setVolume(_initialSystemVolume);
      FlutterVolumeController.updateShowSystemUI(true);
      
      // Safety hit
      Future.delayed(const Duration(milliseconds: 300), () {
        FlutterVolumeController.setVolume(_initialSystemVolume);
      });
    } else if (state == AppLifecycleState.resumed) {
      FlutterVolumeController.updateShowSystemUI(false);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _unlockHideTimer?.cancel();
    _volumeTimer?.cancel();
    _brightnessTimer?.cancel();
    _posSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _playlistScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    FlutterVolumeController.removeListener();
    
    // Feature: Restore System State
    WakelockPlus.disable();
    player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startHideTimer([Duration duration = const Duration(seconds: 4), bool forcePlayCheck = false]) {
    _hideTimer?.cancel();
    _hideTimer = Timer(duration, () {
      if (mounted && (player.state.playing || forcePlayCheck) && !_isLocked && _activeTray == null) {
        setState(() {
          _showControls = false;
          _activeTray = null; // Close tray on auto-hide
          // Hide System UI when controls hide in landscape
          if (_isLandscape) {
             SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          }
        });
      }
    });
  }

  void _startTrayHideTimer() {
    _trayHideTimer?.cancel();
    _trayHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _activeTray = null;
        });
        _startHideTimer();
      }
    });
  }

  void _toggleTray(String tray) {
    setState(() {
      if (_activeTray == tray) {
        _activeTray = null;
        _startHideTimer();
      } else {
        _activeTray = tray;
        _hideTimer?.cancel(); // Stop main hide timer while tray is open
        _startTrayHideTimer();
      }
    });
  }


  void _toggleControls() {
    if (_isLocked) {
       _handleLockedTap();
       return;
    }

    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideTimer();
      } else {
        // Close EVERYTHING when hiding controls manually
        _activeTray = null;
        _showVolumeLabel = false;
        _showBrightnessLabel = false;
        if (_isLandscape) {
           SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
      }
    });
  }

  void _togglePlayPause() {
    player.playOrPause();
    _startHideTimer();
  }

  // Speed Menu replaced by Tray System


  // --- Feature Implementation: Lock ---
  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        // Enforce lock state
        _showControls = false;
        // Show Unlock UI initially
        _isUnlockControlsVisible = true; 
        _startUnlockHideTimer();
        // Force Immersive Mode
        if (_isLandscape) {
           SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
      } else {
        // Unlock
        _unlockHideTimer?.cancel();
        _isUnlockControlsVisible = false;
        _showControls = true;
        _startHideTimer();
        // Restore Edge to Edge (or immersive if controls hide later)
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  void _startUnlockHideTimer() {
    _unlockHideTimer?.cancel();
    _unlockHideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && _isLocked) {
        setState(() {
          _isUnlockControlsVisible = false;
        });
      }
    });
  }

  void _handleLockedTap() {
    // If hidden, show it. If shown, reset timer?
    // User said: "screen ke kisis bhi jaga pe touch kare to us lock icon dike"
    setState(() {
       _isUnlockControlsVisible = true;
    });
    _startUnlockHideTimer();
  }

  void _seekRelative(int seconds) {
    if (_isLocked && _isLandscape) return;
    final current = player.state.position;
    final total = player.state.duration;
    
    var newPos = current + Duration(seconds: seconds);
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > total) newPos = total;
    
    player.seek(newPos);
    _startHideTimer();
  }

  OverlayEntry? _overlayEntry;

  void _showOverlay(BuildContext context) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Container(
          color: Colors.black,
          child: const Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                 color: Colors.white,
                 strokeWidth: 3,
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _toggleOrientation() async {
    if (_isLocked && _isLandscape) return;
    
    // Reset any active tray & hide controls during orientation change
    setState(() {
      _activeTray = null;
      _showControls = false;
    });

    // 1. Show global floating overlay
    _showOverlay(context);
    
    // Allow UI to render the black overlay
    await Future.delayed(const Duration(milliseconds: 50));

    if (_isLandscape) {
      // To Portrait
      // Enable system UI first to avoid weird jumps back to portrait
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      setState(() {
        _isLandscape = false;
        _lastSensorOrientation = null;
      });
    } else {
      // To Landscape
      // In Landscape, we want immersive mode to prevent status bar from pushing the layout
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      setState(() => _isLandscape = true);
    }

    // 2. Wait for rotation
    await Future.delayed(const Duration(milliseconds: 600));

    // 3. Remove overlay
    if (mounted) {
      _removeOverlay();
    }
  }

  String get _currentTitle {
    if (widget.playlist.isEmpty) return "No Video";
    return widget.playlist[_currentIndex]['name'] ?? "Video";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isLocked && _isLandscape) return;
        if (_isLandscape) {
          _toggleOrientation();
          return;
        }
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: !_isLandscape,
          bottom: !_isLandscape,
          left: !_isLandscape,
          right: !_isLandscape,
          child: _isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return VideoPlayerPortraitLayout(
      size: MediaQuery.of(context).size,
      videoHeight: MediaQuery.of(context).size.width * 9 / 16,
      isLocked: _isLocked,
      isUnlockControlsVisible: _isUnlockControlsVisible,
      showControls: _showControls,
      controller: controller,
      currentTitle: _currentTitle,
      onLockedTap: _handleLockedTap,
      onToggleControls: _toggleControls,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      showBrightnessLabel: _showBrightnessLabel,
      showVolumeLabel: _showVolumeLabel,
      brightness: _brightness,
      volume: _volume,
      isPlaying: _isPlaying,
      onPlayPause: _togglePlayPause,
      onSeekRelative: _seekRelative,
      positionNotifier: _positionNotifier,
      durationNotifier: _durationNotifier,
      onSeekbarChangeStart: (v) {
        _wasPlayingBeforeDrag = player.state.playing;
        player.pause();
        _isDraggingSeekbar = true;
      },
      onSeekbarChanged: (v) {
        _pendingSeekValue = v;
        if (!_isSeeking) _processSeekLoop();
      },
      onSeekbarChangeEnd: (v) {
        _isDraggingSeekbar = false;
        _pendingSeekValue = null;
        player.seek(Duration(milliseconds: (v * 1000).toInt())).then((_) {
          if (_wasPlayingBeforeDrag) {
            player.play();
            _startHideTimer(const Duration(milliseconds: 700), true);
          }
        });
      },
      playbackSpeed: _playbackSpeed,
      currentSubtitle: _currentSubtitle,
      currentQuality: _currentQuality,
      activeTray: _activeTray,
      onToggleTray: _toggleTray,
      onToggleLock: _toggleLock,
      onToggleOrientation: _toggleOrientation,
      onResetSpeed: () => setState(() { _playbackSpeed = 1.0; player.setRate(1.0); }),
      onResetSubtitle: () => setState(() => _currentSubtitle = "Off"),
      onResetQuality: () => setState(() => _currentQuality = "Auto"),
      trayItems: _activeTray == 'quality' ? _qualities : _subtitles,
      trayCurrentSelection: _activeTray == 'quality' ? _currentQuality : _currentSubtitle,
      isDraggingSpeedSlider: _isDraggingSpeedSlider,
      onTrayItemSelected: (item) {
        setState(() {
          if (_activeTray == 'quality') _currentQuality = item;
          else _currentSubtitle = item;
          _activeTray = null; // Hide immediately
        });
        _startHideTimer();
      },
      onTraySpeedChanged: (s) {
        player.setRate(s);
        setState(() {
          _playbackSpeed = s;
          _activeTray = null; // Hide immediately
        });
        _startHideTimer();
      },
      onTrayClose: () => setState(() => _activeTray = null),
      onTrayInteraction: _startTrayHideTimer,
      playlist: widget.playlist,
      currentIndex: _currentIndex,
      videoProgress: _videoProgress,
      onVideoTap: _playVideo,
      onBack: () => Navigator.pop(context),
      onDoubleLockTap: _toggleLock,
    );
  }

  // Restore Landscape Layout
  Widget _buildLandscapeLayout() {
    return VideoPlayerLandscapeLayout(
      isLocked: _isLocked,
      isUnlockControlsVisible: _isUnlockControlsVisible,
      showControls: _showControls,
      controller: controller,
      currentTitle: _currentTitle,
      onLockedTap: _handleLockedTap,
      onToggleControls: _toggleControls,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      showBrightnessLabel: _showBrightnessLabel,
      showVolumeLabel: _showVolumeLabel,
      brightness: _brightness,
      volume: _volume,
      isPlaying: _isPlaying,
      onSeekRelative: _seekRelative,
      onPlayPause: _togglePlayPause,
      positionNotifier: _positionNotifier,
      durationNotifier: _durationNotifier,
      isDraggingSeekbar: _isDraggingSeekbar,
      onSeekbarChangeStart: (v) {
        _wasPlayingBeforeDrag = player.state.playing;
        player.pause();
        _isDraggingSeekbar = true;
      },
      onSeekbarChanged: (v) {
        _pendingSeekValue = v;
        if (!_isSeeking) _processSeekLoop();
      },
      onSeekbarChangeEnd: (v) {
        _isDraggingSeekbar = false;
        _pendingSeekValue = null;
        player.seek(Duration(milliseconds: (v * 1000).toInt())).then((_) {
          if (_wasPlayingBeforeDrag) {
            player.play();
            _startHideTimer(const Duration(milliseconds: 700), true);
          }
        });
      },
      playbackSpeed: _playbackSpeed,
      currentSubtitle: _currentSubtitle,
      currentQuality: _currentQuality,
      activeTray: _activeTray,
      onToggleTray: _toggleTray,
      onToggleLock: _toggleLock,
      onToggleOrientation: _toggleOrientation,
      onResetSpeed: () => setState(() { _playbackSpeed = 1.0; player.setRate(1.0); }),
      onResetSubtitle: () => setState(() => _currentSubtitle = "Off"),
      onResetQuality: () => setState(() => _currentQuality = "Auto"),
      trayItems: _activeTray == 'quality' ? _qualities : _subtitles,
      trayCurrentSelection: _activeTray == 'quality' ? _currentQuality : _currentSubtitle,
      isDraggingSpeedSlider: _isDraggingSpeedSlider,
      onTrayItemSelected: (item) {
        setState(() {
          if (_activeTray == 'quality') _currentQuality = item;
          else _currentSubtitle = item;
          _activeTray = null; // Hide immediately
        });
        _startHideTimer();
      },
      onTraySpeedChanged: (s) {
        player.setRate(s);
        setState(() {
          _playbackSpeed = s;
          _activeTray = null; // Hide immediately
        });
        _startHideTimer();
      },
      onTrayClose: () => setState(() => _activeTray = null),
      onTrayInteraction: _startTrayHideTimer,
      onDoubleLockTap: _toggleLock,
    );
  }


  // State for optimized seeking (Smart Scrubbing)
  bool _isSeeking = false;
  double? _pendingSeekValue;
  bool _wasPlayingBeforeDrag = false;

  Future<void> _processSeekLoop() async {
    if (_isSeeking) return;
    _isSeeking = true;

    try {
      while (_pendingSeekValue != null) {
        // Capture the latest target
        final targetSeconds = _pendingSeekValue!;
        // Clear pending so we know if a new one comes in during the await
        _pendingSeekValue = null;
        
        // Perform the seek
        await player.seek(Duration(milliseconds: (targetSeconds * 1000).toInt()));
      }
    } catch (e) {
      debugPrint("Seek error: $e");
    } finally {
      _isSeeking = false;
      // Double check in case a race condition added a value right at the end
      if (_pendingSeekValue != null) {
        _processSeekLoop();
      }
    }
  }



}
