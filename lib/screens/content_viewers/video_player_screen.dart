import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  late final Player player;
  late final VideoController controller;

  // Player State
  late int _currentIndex;
  bool _isPlaying = false;
  bool _isBuffering = false;
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

  // Local state for smooth seeking
  double? _dragValue;

  // Placeholder for quality/subtitle just for UI visuals as requested
  String _currentQuality = "Auto";
  String _currentSubtitle = "Off";

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    
    // Initialize Player
    player = Player();
    controller = VideoController(player);
    
    // Listen to streams
    player.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
    
    player.stream.buffering.listen((b) {
      if (mounted) setState(() => _isBuffering = b);
    });

    player.stream.completed.listen((completed) {
      if (completed) {
        // Auto play next if available
        if (_currentIndex < widget.playlist.length - 1) {
          _playVideo(_currentIndex + 1);
        }
      }
    });

    // Start initial video
    if (widget.playlist.isNotEmpty && _currentIndex < widget.playlist.length) {
      _playVideo(_currentIndex);
    }
    
    _startHideTimer();
  }

  Future<void> _playVideo(int index) async {
    if (index < 0 || index >= widget.playlist.length) return;

    setState(() {
      _currentIndex = index;
      _showControls = true;
    });

    try {
      final item = widget.playlist[index];
      final path = item['path'] as String?;
      
      if (path != null) {
        await player.open(Media(path), play: true);
      }
    } catch (e) {
      debugPrint('Error playing video: $e');
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _unlockHideTimer?.cancel();
    player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startHideTimer([Duration duration = const Duration(seconds: 4), bool forcePlayCheck = false]) {
    _hideTimer?.cancel();
    if (_showControls && (_isPlaying || forcePlayCheck) && !_isLocked) {
      _hideTimer = Timer(duration, () {
        if (mounted && _isPlaying && _showControls && !_isDraggingSeekbar) {
          setState(() {
            _showControls = false;
            // Hide System UI when controls hide in landscape
            if (_isLandscape) {
               SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            }
          });
        }
      });
    }
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
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
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

  // --- Feature Implementation: Speed Control ---
  void _showSpeedMenu() {
    // Stop hide timer while menu is open
    _hideTimer?.cancel();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212), // Pure Dark Grey
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Padding(
               padding: EdgeInsets.only(left: 20, bottom: 10),
               child: Text('Playback Speed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
             ),
             ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) => ListTile(
              leading: Icon(
                Icons.check, 
                color: _playbackSpeed == speed ? const Color(0xFF22C55E) : Colors.transparent
              ),
              title: Text('${speed}x', style: const TextStyle(color: Colors.white)),
              onTap: () {
                player.setRate(speed);
                setState(() => _playbackSpeed = speed);
                Navigator.pop(context);
                _startHideTimer();
              },
             )),
          ],
        ),
      ),
    ).then((_) => _startHideTimer());
  }

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
    
    // 1. Show global floating overlay
    _showOverlay(context);
    
    // Allow UI to render the black overlay
    await Future.delayed(const Duration(milliseconds: 50));

    if (_isLandscape) {
      // To Portrait
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      setState(() => _isLandscape = false);
    } else {
      // To Landscape
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
               // Header (Fixed) - Always takes space, but content hides if needed
               // If Locked: Back button hidden, Text visible (if interface visible)
               AnimatedOpacity(
                 duration: const Duration(milliseconds: 300),
                 opacity: isInterfaceVisible ? 1.0 : 0.0,
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
                        child: Container(color: Colors.transparent),
                      ),
                    ),

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
              
              // Fixed Controls Area
              AnimatedOpacity(
                 duration: const Duration(milliseconds: 300),
                 opacity: (_isLocked && !_isUnlockControlsVisible) ? 0.0 : 1.0,
                 child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Seekbar
                    // If Locked: Hide Slider, Show Timings. If Unlocked: Show Both.
                    Container(
                      color: Colors.black, // Pure Black
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: _buildSeekbar(isPortrait: true, hideSlider: _isLocked),
                    ),
                    
                    Container(
                      color: Colors.black, // Pure Black
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           // Speed
                           Opacity(opacity: _isLocked ? 0.0 : 1.0, child: IgnorePointer(ignoring: _isLocked, child: _buildControlIcon(Icons.speed, "${_playbackSpeed}x", _showSpeedMenu))),
                           // Subtitle
                           Opacity(opacity: _isLocked ? 0.0 : 1.0, child: IgnorePointer(ignoring: _isLocked, child: _buildControlIcon(Icons.closed_caption, _currentSubtitle == "Off" ? "Subtitle" : _currentSubtitle, () => setState(() => _currentSubtitle = _currentSubtitle == 'Off' ? 'Eng' : 'Off')))),
                           // Settings
                           Opacity(opacity: _isLocked ? 0.0 : 1.0, child: IgnorePointer(ignoring: _isLocked, child: _buildControlIcon(Icons.settings, _currentQuality, () {}))),
                           
                           // Lock Button (Double Size when locked)
                           GestureDetector(
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
                                      size: _isLocked ? 44 : 22 // Doubled size when locked
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

                           // Landscape
                           Opacity(opacity: _isLocked ? 0.0 : 1.0, child: IgnorePointer(ignoring: _isLocked, child: _buildControlIcon(Icons.fullscreen, "Landscape", _toggleOrientation))),
                        ],
                      ),
                    ),
                    // Light separator to indicate playlist start
                    if (!_isLocked)
                     const Divider(height: 1, color: Colors.white10),
                  ],
                ),
              ),
              
              // Scrollable Playlist (Expanded to fill remaining space)
              // If Locked: Show Black Space. If Unlocked: Show List.
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isLocked) _handleLockedTap();
                  },
                  child: Container(
                    color: Colors.black, // Pure black
                    width: double.infinity,
                    child: _isLocked 
                       ? null // No watermark text, pure black
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
        Center(
          child: AspectRatio(
            aspectRatio: player.state.width != null && player.state.height != null && player.state.height! > 0
              ? player.state.width! / player.state.height!
              : 16 / 9,
            child: Video(
              controller: controller,
              controls: (state) => const SizedBox(),
              fit: BoxFit.contain,
            ),
          ),
        ),

        // 2. Gesture Detector
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleControls,
            child: Container(color: Colors.transparent),
          ),
        ),
        
        // 3. Controls
        if (_showControls || (_isLocked && _isLandscape)) ...[
           SafeArea(
             child: Stack(
               children: [
                  // Lock Mode Overlay
                 if (_isLocked) ...[
                      _buildLockOverlay(),
                 ] else ...[
                   // Normal Landscape Controls
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
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
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (!_isDraggingSeekbar)
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              // Replay 10s
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
                              
                              // Play/Pause button
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
                              
                              // Forward 10s
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

                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSeekbar(isPortrait: false),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildControlIcon(Icons.speed, "${_playbackSpeed}x", _showSpeedMenu),
                                _buildControlIcon(Icons.closed_caption, _currentSubtitle == "Off" ? "Subtitle" : _currentSubtitle, () => setState(() => _currentSubtitle = _currentSubtitle == 'Off' ? 'Eng' : 'Off')),
                                _buildControlIcon(Icons.settings, _currentQuality, () {}),
                                _buildControlIcon(Icons.lock_outline, "Lock", _toggleLock),
                                _buildControlIcon(Icons.fullscreen_exit, "Portrait", _toggleOrientation),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                 ]
               ],
             ),
           )
        ]
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
                       // Restart timer immediately with shorter duration (0.7s)
                       _startHideTimer(const Duration(milliseconds: 700), true);
                     }
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(Duration(milliseconds: (currentSeconds * 1000).toInt())),
                    style: TextStyle(
                      color: const Color(0xFF22C55E), 
                      fontSize: 13, 
                      fontWeight: FontWeight.w600,
                      shadows: hideSlider ? [const Shadow(color: Colors.black, blurRadius: 2)] : null,
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
          ],
        );
      },
    );
  }

  Widget _buildControlIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem(Map<String, dynamic> item, int index) {
    final isPlaying = index == _currentIndex;
    
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
                  child: Center(
                    child: Icon(
                        isPlaying ? Icons.equalizer : Icons.play_circle_outline, 
                        color: isPlaying ? const Color(0xFF22C55E) : Colors.white, 
                        size: 40
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
                  if (item['type'] == 'video' && item['path'] != null)
                  Text(
                    item['path'].toString().split(Platform.pathSeparator).last,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
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
}
