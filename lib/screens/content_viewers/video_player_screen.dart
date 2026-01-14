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
    player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_showControls && _isPlaying && !_isLocked) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
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
    if (_isLocked && _isLandscape) {
       // Only show lock button if locked and user taps
       if (!_showControls) {
         setState(() => _showControls = true);
         _startHideTimer();
       } else {
         setState(() => _showControls = false);
       }
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
    });
    _startHideTimer();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (Fixed)
        _buildHeader(),
        
        // Video Player Area (Fixed)
        SizedBox(
          width: size.width,
          height: videoHeight,
          child: Stack(
            children: [
              Video(controller: controller, controls: (state) => const SizedBox()),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  child: Container(color: Colors.transparent),
                ),
              ),
              if (_showControls) ...[
                 Center(
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
                 )
              ]
            ],
          ),
        ),
        
        // Fixed Controls Area
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.black, // Pure Black
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildSeekbar(isPortrait: true),
            ),
            
            Container(
              color: Colors.black, // Pure Black
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlIcon(Icons.speed, "${_playbackSpeed}x", _showSpeedMenu),
                  _buildControlIcon(Icons.closed_caption, _currentSubtitle == "Off" ? "Subtitle" : _currentSubtitle, () => setState(() => _currentSubtitle = _currentSubtitle == 'Off' ? 'Eng' : 'Off')),
                  _buildControlIcon(Icons.settings, _currentQuality, () {}),
                  _buildControlIcon(Icons.lock_outline, "Lock", () {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lock available in Landscape mode')));
                  }),
                  _buildControlIcon(Icons.fullscreen, "Landscape", _toggleOrientation),
                ],
              ),
            ),
            // Light separator to indicate playlist start
            const Divider(height: 1, color: Colors.white10),
          ],
        ),
        
        // Scrollable Playlist (Expanded to fill remaining space)
        Expanded(
          child: Container(
            color: Colors.black, // Pure black
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: widget.playlist.length,
              itemBuilder: (context, i) => _buildPlaylistItem(widget.playlist[i], i),
            ),
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
                    Positioned(
                       bottom: 40,
                       right: 40,
                       child: _buildGlassButton(
                         icon: Icons.lock_open, 
                         label: "Unlock", 
                         onTap: _toggleLock
                       ),
                     ),
                     Center(
                       child: Icon(Icons.lock, size: 50, color: Colors.white.withOpacity(0.5)),
                     )
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

  // Time tracking for seek throttling
  DateTime _lastSeekTime = DateTime.now();
  bool _wasPlayingBeforeDrag = false;

  Widget _buildSeekbar({required bool isPortrait}) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = player.state.duration;
        
        // Use milliseconds for higher precision
        final maxSeconds = dur.inMilliseconds.toDouble() / 1000.0;
        final currentSeconds = _dragValue ?? (pos.inMilliseconds.toDouble() / 1000.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: _isDraggingSeekbar ? 9 : 7,
                ),
                activeTrackColor: const Color(0xFF22C55E),
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.white,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: currentSeconds.clamp(0.0, maxSeconds > 0 ? maxSeconds : 1.0),
                min: 0,
                max: maxSeconds > 0 ? maxSeconds : 1.0,
                onChangeStart: (v) {
                  // Pause playback to ensure smooth seeking without decoder conflict
                  _wasPlayingBeforeDrag = player.state.playing;
                  player.pause();
                  
                  setState(() {
                    _isDraggingSeekbar = true;
                    _dragValue = v;
                  });
                },
                onChanged: (v) {
                  // Update UI immediately
                  setState(() {
                    _dragValue = v;
                  });
                  
                  // Ultra-Low Latency Throttle (~60fps)
                  // media_kit handles rapid seeking well, so we can update very frequently
                  // This ensures the video keeps up with fast finger movement
                  final now = DateTime.now();
                  if (now.difference(_lastSeekTime).inMilliseconds > 16) {
                    _lastSeekTime = now;
                    player.seek(Duration(milliseconds: (v * 1000).toInt()));
                  }
                },
                onChangeEnd: (v) {
                  setState(() {
                    _isDraggingSeekbar = false;
                    _dragValue = null;
                  });
                  
                  // Final precise seek
                  player.seek(Duration(milliseconds: (v * 1000).toInt())).then((_) {
                     // Restore playback if it was playing before drag
                     if (_wasPlayingBeforeDrag) {
                       player.play();
                     }
                  });
                  _startHideTimer();
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
                    style: const TextStyle(color: Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatDuration(dur),
                    style: const TextStyle(color: Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.w600),
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
}
