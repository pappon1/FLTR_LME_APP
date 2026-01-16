import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/video_thumbnail_widget.dart';

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
  bool _isBuffering = false;
  // Performance: ValueNotifiers for granular UI updates
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(Duration.zero);
  double _playbackSpeed = 1.0;
  
  // UI State
  bool _showControls = true;
  bool _isLandscape = false;
  bool _isDraggingSeekbar = false;
  bool _isLocked = false;
  String? _errorMessage;
  Timer? _hideTimer;
  
  // Lock UI State
  bool _isUnlockControlsVisible = false;
  Timer? _unlockHideTimer;

  // Local state for smooth seeking
  double? _dragValue;

  // Tray State
  String? _activeTray; // 'quality', 'speed', 'subtitle'
  Timer? _trayHideTimer;
  bool _showSpeedPresets = false;
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
             if (mounted) {
               setState(() {
                 item['duration'] = formatted;
               });
             }
          }
       }
    });

    player.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
    
    player.stream.buffering.listen((b) {
      if (mounted) setState(() => _isBuffering = b);
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
       if (mounted) {
         setState(() {
           _errorMessage = error.toString();
           _isBuffering = false;
         });
       }
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
  
  // Gesture State Tracks
  bool _isVerticalDrag = false;

  void _onVerticalDragStart(DragStartDetails details) {
    _isVerticalDrag = true;
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isVerticalDrag = false;
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

  final GlobalKey _videoGestureKey = GlobalKey();

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
          _showSpeedPresets = false;
        });
        _startHideTimer();
      }
    });
  }

  void _toggleTray(String tray) {
    setState(() {
      if (_activeTray == tray) {
        _activeTray = null;
        _showSpeedPresets = false;
        _startHideTimer();
      } else {
        _activeTray = tray;
        _showSpeedPresets = false;
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
    return WillPopScope(
      onWillPop: () async {
        if (_isLocked && _isLandscape) return false;
        if (_isLandscape) {
          _toggleOrientation();
          return false;
        }
        return true;
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
    final size = MediaQuery.of(context).size;
    final videoHeight = size.width * 9 / 16;

    // Fixed column with expanded scrollable playlist at the bottom
    // Determine visibility based on Lock State
    // If locked: Visible only when `_isUnlockControlsVisible` is true.
    // If unlocked: Visible when `_showControls` is true.
    final isInterfaceVisible = _isLocked ? _isUnlockControlsVisible : _showControls;

    // Fixed column with expanded scrollable playlist at the bottom
    return Column(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // Header (Fixed)
               AnimatedOpacity(
                 duration: const Duration(milliseconds: 300),
                 opacity: _isLocked ? 0.5 : 1.0, // Always visible if unlocked
                 child: Container(
                    color: Colors.black, 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Back Button (Hide if locked)
                        Opacity(
                          opacity: _isLocked ? 0.0 : 1.0,
                          child: IgnorePointer(
                            ignoring: _isLocked,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                 ),
               ),
              
              // Video Player Area (Fixed)
              SizedBox(
                width: size.width,
                height: videoHeight,
                child: Stack(
                  children: [
                    Video(controller: controller, controls: (state) => const SizedBox()),
                    
                    // Locked Dark Overlay (Behind controls)
                    if (_isLocked)
                    Positioned.fill(
                      child: Container(color: Colors.black54),
                    ),

                    // Gesture Detector
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                           if (_isLocked) {
                              _handleLockedTap();
                           } else {
                              _toggleControls();
                           }
                        },
                        onVerticalDragUpdate: _isLocked ? null : _onVerticalDragUpdate,
                        onHorizontalDragUpdate: (details) {
                          // Consume horizontal drag to prevent vertical mistakenly acting?
                          // Or better, if we want future seek, we can implement it here.
                          // For now, doing nothing effectively blocks "vertical" interpretation if the user moves diagonally closer to horizontal.
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // Volume/Brightness Overlay
                    Positioned.fill(child: _buildGestureOverlay()),

                    // Play/Pause Controls (Only if Unlocked)
                    if (!_isLocked)
                      IgnorePointer(
                        ignoring: !isInterfaceVisible,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isInterfaceVisible ? 1.0 : 0.0,
                          child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    // Replay 10s
                                    GestureDetector(
                                      onTap: () => _seekRelative(-10),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    
                                    // Play/Pause
                                    GestureDetector(
                                      onTap: _togglePlayPause,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white30, width: 1),
                                        ),
                                        child: Icon(
                                          _isPlaying ? Icons.pause : Icons.play_arrow,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    
                                    // Forward 10s
                                    GestureDetector(
                                      onTap: () => _seekRelative(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                                      ),
                                    ),
                                ],
                              ),
                           ),
                        ),
                      )
                  ],
                ),
              ),
              
              // Subtitle Safe Area (Black Bar) - Pushes controls down
              if (_currentSubtitle != "Off" && !_isLandscape)
                 Container(height: 40, color: Colors.black),

              // Fixed Controls Area
              // Stack to allow Tray to float over icons without shifting layout
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seekbar
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 1.0, // Always visible
                    child: Container(
                      color: Colors.black, // Pure Black
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: _buildSeekbar(isPortrait: true, hideSlider: _isLocked),
                    ),
                  ),

                  // Icons Row + Floating Tray
                  Stack(
                    alignment: Alignment.bottomCenter, // Anchor at bottom
                    clipBehavior: Clip.none, // Allow tray to float out
                    children: [
                        // The Icons Row (Base)
                        Container(
                          color: Colors.black, // Pure Black
                          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                                // Speed
                               AnimatedOpacity(
                                 duration: const Duration(milliseconds: 300),
                                 opacity: _isLocked ? 0.0 : 1.0,
                                 child: IgnorePointer(
                                   ignoring: _isLocked, 
                                   child: _buildControlIcon(
                                      Icons.speed, 
                                      "${_playbackSpeed.toStringAsFixed(2)}x", 
                                      () => _toggleTray('speed'), 
                                      isActive: _activeTray == 'speed' || _playbackSpeed != 1.0,
                                      onReset: () => setState(() { _playbackSpeed = 1.0; player.setRate(1.0); }),
                                   )
                                 ),
                               ),
                               // Subtitle
                               AnimatedOpacity(
                                 duration: const Duration(milliseconds: 300),
                                 opacity: _isLocked ? 0.0 : 1.0,
                                 child: IgnorePointer(
                                   ignoring: _isLocked, 
                                   child: _buildControlIcon(
                                      Icons.closed_caption, 
                                      _currentSubtitle == "Off" ? "Subtitle" : _currentSubtitle, 
                                      () => _toggleTray('subtitle'), 
                                      isActive: _activeTray == 'subtitle' || _currentSubtitle != 'Off',
                                      onReset: () => setState(() => _currentSubtitle = "Off"),
                                   )
                                 ),
                               ),
                               // Settings
                               AnimatedOpacity(
                                 duration: const Duration(milliseconds: 300),
                                 opacity: _isLocked ? 0.0 : 1.0,
                                 child: IgnorePointer(
                                   ignoring: _isLocked, 
                                   child: _buildControlIcon(
                                      Icons.settings, 
                                      _currentQuality, 
                                      () => _toggleTray('quality'), 
                                      isActive: _activeTray == 'quality' || _currentQuality != "Auto",
                                      onReset: () => setState(() => _currentQuality = "Auto"),
                                   )
                                 ),
                               ),
                               
                                // Lock Button
                               // Logic: If Locked -> Always visible (1.0 or 0.2). If Unlocked -> Follow controls (1.0 or 0.0)
                               AnimatedOpacity(
                                 duration: const Duration(milliseconds: 300),
                                 opacity: _isLocked ? (_isUnlockControlsVisible ? 1.0 : 0.0) : 1.0,
                                 child: GestureDetector(
                                    onTap: () {
                                      if (!_isLocked) {
                                        _toggleLock();
                                      } else {
                                        _handleLockedTap();
                                      }
                                    },
                                    onDoubleTap: _isLocked ? _toggleLock : null,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          child: Icon(
                                            _isLocked ? Icons.lock : Icons.lock_open, 
                                            color: Colors.white, 
                                            size: _isLocked ? 44 : 22 
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        if (!_isLocked)
                                        const Text(
                                          "Lock",
                                          style: TextStyle(color: Colors.white, fontSize: 10),
                                        ),
                                        if (_isLocked && _isUnlockControlsVisible)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Text(
                                              "Double tap\nto unlock",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold 
                                              ),
                                            ),
                                          )
                                      ],
                                    ),
                                 ),
                               ),

                               // Landscape
                               AnimatedOpacity(
                                 duration: const Duration(milliseconds: 300),
                                 opacity: _isLocked ? 0.0 : 1.0,
                                 child: IgnorePointer(
                                   ignoring: _isLocked, 
                                   child: _buildControlIcon(Icons.fullscreen, "Landscape", _toggleOrientation)
                                 ),
                               ),
                            ],
                          ),
                        ),

                        // FLOATING TRAY (Positioned relative to the row)
                        // "bottom: 100%" implies it sits directly on top of the icons container
                        if (_activeTray != null)
                          Positioned(
                              bottom: 0, // Overlap the icons directly (Front layer)
                              left: 0, 
                              right: 0,
                              child: Center(child: _buildTray()), 
                          ),
                    ],
                  ),

                  // Light separator
                  AnimatedOpacity(
                     duration: const Duration(milliseconds: 300),
                     opacity: (_isLocked ? 0.0 : (_showControls ? 1.0 : 0.0)),
                     child: const Divider(height: 1, color: Colors.white10)
                  ),
                ],
              ),

              
              // Scrollable Playlist (Expanded to fill remaining space)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isLocked) _handleLockedTap();
                  },
                  child: Container(
                    color: Colors.black, // Pure black
                    width: double.infinity,
                    child: _isLocked 
                       ? null 
                       : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          itemCount: widget.playlist.length,
                          itemBuilder: (context, i) => _buildPlaylistItem(widget.playlist[i], i),
                        ),
                  ),
                ),
              ),
             
            ],
          ),
        ),
      ],
    );

  }

  // Restore Landscape Layout
  Widget _buildLandscapeLayout() {
    return Stack(
      fit: StackFit.expand,
      children: [
         // 1. Video Layer
        Container(
          color: Colors.black,
          child: Center(
            child: Video(
              controller: controller,
              controls: (state) => const SizedBox(),
              fit: BoxFit.contain, // Maintain aspect ratio without jumping
            ),
          ),
        ),

        // 2. Gesture Detector (Captures Taps and Double Taps)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleControls,
            onDoubleTapDown: (details) {
               // Consume double tap to prevent system UI from reacting
            },
            onDoubleTap: () {
               // Placeholder for future double tap seek
            },
            onVerticalDragUpdate: _isLocked ? null : _onVerticalDragUpdate,
            onHorizontalDragUpdate: (details) {}, 
            child: Container(color: Colors.transparent),
          ),
        ),

        // Gesture Overlay
        Positioned.fill(child: _buildGestureOverlay()),
        
        // 3. Controls
        // 3. Controls (NO SafeArea here to prevent 'jhatka' shift)
           Stack(
             children: [
                // Lock Mode Overlay
               if (_isLocked) ...[
                    _buildLockOverlay(),
               ] else ...[
                 // Normal Landscape Controls
                  // 1. Center Controls (Play/Pause)
                  // Placed first so bars appear on top, but we will ensure bars don't block center touches
                  // via HitTestBehavior or specific sizing.
                  if (!_isDraggingSeekbar)
                    Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _showControls ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !_showControls,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _seekRelative(-10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.replay_10, color: Colors.white, size: 36),
                                ),
                              ),
                              const SizedBox(width: 32),
                              GestureDetector(
                                onTap: _togglePlayPause,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30, width: 1),
                                  ),
                                  child: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32),
                              GestureDetector(
                                onTap: () => _seekRelative(10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.forward_10, color: Colors.white, size: 36),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 2. Visual Scrims (Gradients) - IGNORE POINTERS
                  // These provide the 'Shadow' look without blocking touches
                  Positioned(
                    top: 0, left: 0, right: 0, height: 140,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showControls ? 1.0 : 0.0, 
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 200,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showControls ? 1.0 : 0.0, 
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Interactive Top Bar (Transparent Background)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showControls ? 1.0 : 0.0, 
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: _toggleOrientation,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 4. Interactive Bottom Bar (Transparent Background)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showControls ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(32, 20, 32, 30),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSeekbar(isPortrait: false),
                              
                              // Stack for Icons + Tray Overlay
                              Stack(
                                alignment: Alignment.bottomCenter,
                                clipBehavior: Clip.none, 
                                children: [
                                  // Icons Row (Base)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        // Speed
                                        _buildControlIcon(
                                            Icons.speed, 
                                            "${_playbackSpeed.toStringAsFixed(2)}x", 
                                            () => _toggleTray('speed'), 
                                            isActive: _activeTray == 'speed' || _playbackSpeed != 1.0,
                                            onReset: () => setState(() { _playbackSpeed = 1.0; player.setRate(1.0); }),
                                        ),
                                        // Subtitle
                                        _buildControlIcon(
                                            Icons.closed_caption, 
                                            _currentSubtitle == "Off" ? "Subtitle" : _currentSubtitle, 
                                            () => _toggleTray('subtitle'), 
                                            isActive: _activeTray == 'subtitle' || _currentSubtitle != 'Off',
                                            onReset: () => setState(() => _currentSubtitle = "Off"),
                                        ),
                                        // Quality
                                        _buildControlIcon(
                                            Icons.settings, 
                                            _currentQuality, 
                                            () => _toggleTray('quality'), 
                                            isActive: _activeTray == 'quality' || _currentQuality != "Auto",
                                            onReset: () => setState(() => _currentQuality = "Auto"),
                                        ),
                                        // Lock
                                        _buildControlIcon(Icons.lock_outline, "Lock", _toggleLock),
                                        // Landscape
                                        _buildControlIcon(Icons.fullscreen_exit, "Portrait", _toggleOrientation),
                                      ],
                                    ),
                                  ),

                                  if (_activeTray != null)
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Center(child: _buildTray()),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
               ],
             ),
        ],
      );
   }

  // Restore Header
  Widget _buildHeader() {
    return Container(
      color: Colors.black, // Pure black
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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

  Widget _buildSeekbar({required bool isPortrait, bool hideSlider = false}) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = player.state.duration;
        
        final maxSeconds = dur.inMilliseconds.toDouble() / 1000.0;
        final currentSeconds = _dragValue ?? (pos.inMilliseconds.toDouble() / 1000.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hideSlider)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: _isDraggingSeekbar ? 9 : 7,
                ),
                activeTrackColor: const Color(0xFF22C55E),
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.white,
                // Large transparent overlay for bigger touch target
                overlayColor: Colors.transparent, 
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
              ),
              child: Slider(
                value: currentSeconds.clamp(0.0, maxSeconds > 0 ? maxSeconds : 1.0),
                min: 0,
                max: maxSeconds > 0 ? maxSeconds : 1.0,
                onChangeStart: (v) {
                  // Pause to free up resources for seeking
                  _wasPlayingBeforeDrag = player.state.playing;
                  player.pause();
                  
                  setState(() {
                    _isDraggingSeekbar = true;
                    _dragValue = v;
                  });
                },
                onChanged: (v) {
                  // Instant UI update
                  setState(() {
                    _dragValue = v;
                  });
                  
                  // Optimised Seeking:
                  // Store the latest value. If the player is busy seeking, it will pick this up next.
                  // If it's idle, we start the loop.
                  _pendingSeekValue = v;
                  if (!_isSeeking) {
                    _processSeekLoop();
                  }
                },
                onChangeEnd: (v) {
                  setState(() {
                    _isDraggingSeekbar = false;
                    _dragValue = null;
                  });
                  _pendingSeekValue = null; // Clear queue
                  
                  // Final precise seek
                  player.seek(Duration(milliseconds: (v * 1000).toInt())).then((_) {
                     if (_wasPlayingBeforeDrag) {
                       player.play();
                       _startHideTimer(const Duration(milliseconds: 700), true);
                     }
                  });
                },
              ),
            ),
            
            if (hideSlider) const SizedBox(height: 10),

            Opacity(
              opacity: hideSlider ? 0.7 : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(Duration(milliseconds: (currentSeconds * 1000).toInt())),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 13, 
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                      ),
                    ),
                    Text(
                      _formatDuration(dur),
                      style: TextStyle(
                        color: const Color(0xFF22C55E), 
                        fontSize: 13, 
                        fontWeight: FontWeight.w600,
                        shadows: hideSlider ? [const Shadow(color: Colors.black, blurRadius: 2)] : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlIcon(IconData icon, String label, VoidCallback onTap, {bool isActive = false, VoidCallback? onReset}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent, // Catches taps in empty spaces/gaps
      onLongPress: () {
         if (onReset != null) {
            HapticFeedback.heavyImpact();
            onReset();
         }
      },
      child: Container(
        color: Colors.transparent, // Explicit hit test area
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Expand touch target
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? const Color(0xFF22C55E) : Colors.white, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTray() {
    return Listener(
      onPointerDown: (_) => _startTrayHideTimer(),
      onPointerMove: (_) => _startTrayHideTimer(),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350), 
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95), 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 16), 
        child: Stack(
          children: [
             // TRAY CONTENT
             Padding(
               padding: const EdgeInsets.only(right: 30), // Space for close button
               child: _buildTrayContent(),
             ),
  
             // CLOSE BUTTON (Absolute in Tray)
             Positioned(
               right: 0,
               top: 0,
               bottom: 0,
               child: Center(
                 child: GestureDetector(
                   onTap: () => setState(() => _activeTray = null),
                   child: Container(
                     padding: const EdgeInsets.all(4),
                     decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                     child: const Icon(Icons.close, color: Colors.white, size: 14),
                   ),
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrayContent() {
    if (_activeTray == 'speed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: const PopupMenuThemeData(
                color: Color(0xFF202020),
                textStyle: TextStyle(color: Colors.white),
              ),
            ),
            child: PopupMenuButton<double>(
              initialValue: _playbackSpeed,
              offset: const Offset(0, 40),
              tooltip: 'Playback Speed',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onSelected: (s) {
                player.setRate(s);
                setState(() => _playbackSpeed = s);
                _startTrayHideTimer();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${_playbackSpeed.toStringAsFixed(2)}x", 
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                  ],
                ),
              ),
              itemBuilder: (context) => [0.5, 1.0, 1.25, 1.5, 2.0, 3.0].map((s) => 
                PopupMenuItem<double>(
                  value: s,
                  height: 32, // Compact items
                  child: Text(
                    "${s}x", 
                    style: TextStyle(
                      color: _playbackSpeed == s ? const Color(0xFF22C55E) : Colors.white, 
                      fontSize: 13,
                      fontWeight: _playbackSpeed == s ? FontWeight.bold : FontWeight.normal
                    )
                  ),
                )
              ).toList(),
            ),
          ),
          
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
               activeTrackColor: const Color(0xFF22C55E),
               inactiveTrackColor: Colors.grey[800],
               thumbColor: Colors.white,
               trackHeight: 2,
               thumbShape: RoundSliderThumbShape(enabledThumbRadius: _isDraggingSpeedSlider ? 9 : 5), // Dynamic Size
               overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: _playbackSpeed,
              min: 0.5,
              max: 3.0,
              divisions: 50,
              onChangeStart: (v) {
                setState(() => _isDraggingSpeedSlider = true);
              },
              onChangeEnd: (v) {
                 setState(() => _isDraggingSpeedSlider = false);
                  _startTrayHideTimer();
              },
              onChanged: (v) {
                setState(() => _playbackSpeed = v);
                player.setRate(v);
              },
            ),
          ),
        ],
      );
    } 
    
    if (_activeTray == 'quality' || _activeTray == 'subtitle') {
       final items = _activeTray == 'quality' ? _qualities : _subtitles;
       final current = _activeTray == 'quality' ? _currentQuality : _currentSubtitle;
       
       return SingleChildScrollView(
         scrollDirection: Axis.horizontal,
         child: Row(
           mainAxisAlignment: MainAxisAlignment.center,
           mainAxisSize: MainAxisSize.min, // Compact
           children: items.map((item) {
             final isSelected = item == current;
             return GestureDetector(
               onTap: () {
                 setState(() {
                   if (_activeTray == 'quality') _currentQuality = item;
                   else _currentSubtitle = item;
                   // _activeTray = null; // Removed to keep tray open as requested
                 });
                 _startTrayHideTimer(); // Reset tray timer instead of main timer
               },
               child: Container(
                 margin: const EdgeInsets.symmetric(horizontal: 4),
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Compact
                 decoration: BoxDecoration(
                   color: isSelected ? const Color(0xFF22C55E) : Colors.transparent,
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: isSelected ? Colors.transparent : Colors.grey),
                 ),
                 child: Text(item, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)), // Compact
               ),
             );
           }).toList(),
         ),
       );
    }

    return const SizedBox();
  }


  Widget _buildPlaylistItem(Map<String, dynamic> item, int index) {
    final isPlaying = index == _currentIndex;
    final path = item['path'] as String?;
    final progress = _videoProgress[path] ?? 0.0;
    
    return InkWell(
      onTap: () => _playVideo(index), 
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            // Thumbnail with progress
            Stack(
              children: [
                Container(
                  width: 150,
                  height: 85,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: isPlaying ? Border.all(color: const Color(0xFF22C55E), width: 2) : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      path != null 
                        ? VideoThumbnailWidget(videoPath: path, fit: BoxFit.cover)
                        : Center(
                            child: Icon(
                                isPlaying ? Icons.equalizer : Icons.play_circle_outline, 
                                color: isPlaying ? const Color(0xFF22C55E) : Colors.white, 
                                size: 40
                            ),
                          ),
                      
                      // Progress Bar at the bottom
                      if (progress > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            color: Colors.white24,
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(color: Colors.red),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill, color: Color(0xFF22C55E), size: 30),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Title and duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'Unknown',
                    style: TextStyle(
                      color: isPlaying ? const Color(0xFF22C55E) : Colors.white,
                      fontSize: 15,
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        item['duration'] ?? "00:00",
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      if (progress > 0.9) ...[
                        const SizedBox(width: 8),
                         const Icon(Icons.check_circle, size: 12, color: Color(0xFF22C55E)),
                         const SizedBox(width: 4),
                         const Text(
                           "Watched", 
                           style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold)
                         ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper for Lock/Unlock button
  Widget _buildGlassButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, "0");
    return "${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}";
  }
  // --- Reusable Lock Overlay ---
  Widget _buildLockOverlay() {
    return Stack(
      children: [
        // Catch taps to show/hide the lock UI
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _handleLockedTap,
            child: Container(color: Colors.transparent),
          ),
        ),
        
        IgnorePointer(
          ignoring: !_isUnlockControlsVisible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isUnlockControlsVisible ? 1.0 : 0.0,
            child: Stack(
              children: [
                  // 1. Dim Overlay
                  Positioned.fill(
                    child: Container(color: Colors.black54),
                  ),
                  
                  // 2. Title (Top Center)
                  Positioned(
                    top: 40, 
                    left: 20, 
                    right: 20,
                    child: Text(
                      _currentTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 3. Lock Icon (Center)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onDoubleTap: _toggleLock,
                          onTap: _handleLockedTap,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white30),
                            ),
                            child: const Icon(Icons.lock, size: 40, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Instructions (Bottom)
                  const Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        "Double tap to unlock",
                        style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildGestureOverlay() {
      return Stack(
          children: [
             // Brightness Slider (Left)
             if (_showBrightnessLabel)
              Positioned(
                 left: 20,
                 top: 0,
                 bottom: 0,
                 child: Center(
                   child: Container(
                     width: 40,
                     height: 160,
                     decoration: BoxDecoration(
                       color: Colors.black54,
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.end,
                       children: [
                         const Padding(padding: EdgeInsets.only(top: 10), child: Icon(Icons.wb_sunny, color: Colors.white, size: 20)),
                         Expanded(
                             child: RotatedBox(
                               quarterTurns: -1,
                               child: SliderTheme(
                                 data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white24,
                                 ),
                                 child: Slider(
                                   value: _brightness,
                                   onChanged: (v) {}, 
                                 ),
                               ),
                             )
                         ),
                       ],
                     ),
                   ),
                 ),
              ),

             // Volume Slider (Right)
             if (_showVolumeLabel)
              Positioned(
                 right: 20,
                 top: 0,
                 bottom: 0,
                 child: Center(
                   child: Container(
                     width: 40,
                     height: 160,
                     decoration: BoxDecoration(
                       color: Colors.black54,
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.end,
                       children: [
                         const Padding(padding: EdgeInsets.only(top: 10), child: Icon(Icons.volume_up, color: Colors.white, size: 20)),
                         Expanded(
                             child: RotatedBox(
                               quarterTurns: -1,
                               child: SliderTheme(
                                 data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                                    activeTrackColor: const Color(0xFF22C55E),
                                    inactiveTrackColor: Colors.white24,
                                 ),
                                 child: Slider(
                                   value: _volume,
                                   onChanged: (v) {}, 
                                 ),
                               ),
                             )
                         ),
                       ],
                     ),
                   ),
                 ),
              ),
          ],
      );
  }
}
