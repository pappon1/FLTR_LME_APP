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
    if (_isLocked) {
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
      backgroundColor: const Color(0xFF1E293B),
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
      // If locking, hide controls immediately (except the lock button)
      if (_isLocked) {
        // Keep controls visible for a moment so user sees it's locked, then timer handles it?
        // Actually typical behavior relies on user tap to show the lock icon again.
        // We'll keep _showControls true initially to show the "Locked" state change
      }
    });
    _startHideTimer();
  }

  void _seekRelative(int seconds) {
    if (_isLocked) return;
    final current = player.state.position;
    final total = player.state.duration;
    
    var newPos = current + Duration(seconds: seconds);
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > total) newPos = total;
    
    player.seek(newPos);
    _startHideTimer();
  }

  void _toggleOrientation() {
    if (_isLocked) return;
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
        if (_isLocked) return false;
        if (_isLandscape) {
          _toggleOrientation();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: SafeArea(
          top: !_isLandscape,
          bottom: !_isLandscape,
          child: _isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    final size = MediaQuery.of(context).size;
    final videoHeight = size.width * 9 / 16;

    return Column(
      children: [
        // Video Section
        Container(
          width: size.width,
          height: videoHeight,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Video(controller: controller, controls: (state) => const SizedBox()),
              _buildControlOverlay(),
            ],
          ),
        ),
        
        // Playlist & Info Section (Only in Portrait)
        Expanded(
          child: Container(
             color: const Color(0xFF0F172A),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  // Current Video Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentTitle,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 2, 
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_currentIndex + 1} of ${widget.playlist.length} in playlist',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Playlist Header
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      'Up Next',
                      style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  
                  // Real Playlist
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.playlist.length,
                      itemBuilder: (context, i) {
                        final item = widget.playlist[i];
                        final isPlaying = i == _currentIndex;
                        
                        return InkWell(
                          onTap: () => _playVideo(i),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isPlaying ? const Color(0xFF22C55E).withOpacity(0.1) : Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: isPlaying ? Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)) : null,
                            ),
                            child: Row(
                              children: [
                                // Simple Icon Placeholder for Thumbnail
                                Container(
                                  width: 60,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    isPlaying ? Icons.equalizer : Icons.play_arrow_rounded,
                                    color: isPlaying ? const Color(0xFF22C55E) : Colors.white54,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? 'Unknown',
                                        style: TextStyle(
                                          color: isPlaying ? const Color(0xFF22C55E) : Colors.white,
                                          fontSize: 14,
                                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item['type'] == 'video' && item['path'] != null)
                                        Text(
                                          item['path'].toString().split(Platform.pathSeparator).last,
                                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
                      },
                    ),
                  ),
               ],
             ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Video(
          controller: controller,
          controls: (state) => const SizedBox(),
          fit: BoxFit.contain,
        ),
        _buildControlOverlay(),
      ],
    );
  }

  Widget _buildControlOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _toggleControls,
        child: Container(
          color: _showControls ? Colors.black.withOpacity(0.4) : Colors.transparent,
          child: _showControls ? Stack(
            children: [
              // Locked State - Minimal UI
              if (_isLocked) ...[
                 Center(
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                        const Icon(Icons.lock, color: Colors.white, size: 48),
                        const SizedBox(height: 8),
                        Text('Screen Locked', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                     ],
                   ),
                 ),
                 Positioned(
                   bottom: 40,
                   right: 40,
                   child: _buildGlassButton(
                     icon: Icons.lock_open, 
                     label: "Unlock", 
                     onTap: _toggleLock
                   ),
                 ),
              ] else ...[
                // Unlocked State - Full UI
                
                // Top Header
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SafeArea( // Check for notches in landscape
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: _isLandscape ? _toggleOrientation : () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              _currentTitle,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Optional: list button to show playlist in landscape?
                        ],
                      ),
                    ),
                  ),
                ),

                // Center Play/Pause
                Center(child: _buildPlayControls()),

                // Bottom Controls
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
                    padding: const EdgeInsets.all(20),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSeekbar(),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Use between ensuring strict layout
                            children: [
                              _buildTextButton(
                                icon: Icons.speed, 
                                text: '${_playbackSpeed}x', 
                                onTap: _showSpeedMenu
                              ),
                              _buildTextButton(
                                icon: Icons.closed_caption, 
                                text: _currentSubtitle, 
                                onTap: () => setState(() => _currentSubtitle = _currentSubtitle == 'Off' ? 'Eng' : 'Off') // Mock toggle
                              ),
                              _buildTextButton(
                                icon: Icons.settings, 
                                text: _currentQuality, 
                                onTap: () {} // Mock 
                              ),
                              
                              // Right side actions
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.lock_outline, color: Colors.white),
                                    onPressed: _toggleLock,
                                  ),
                                  IconButton(
                                    icon: Icon(_isLandscape ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                                    onPressed: _toggleOrientation,
                                  ),
                                ],
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ) : const SizedBox(),
        ),
      ),
    );
  }

  Widget _buildPlayControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          onPressed: _currentIndex > 0 ? () => _playVideo(_currentIndex - 1) : null,
        ),
        const SizedBox(width: 24),
        IconButton(
          iconSize: 36,
          icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
          onPressed: () => _seekRelative(-10),
        ),
        const SizedBox(width: 24),
        
        // Main Play Button
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        
        const SizedBox(width: 24),
        IconButton(
          iconSize: 36,
          icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
          onPressed: () => _seekRelative(10),
        ),
        const SizedBox(width: 24),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          onPressed: _currentIndex < widget.playlist.length - 1 ? () => _playVideo(_currentIndex + 1) : null,
        ),
      ],
    );
  }

  Widget _buildSeekbar() {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = player.state.duration;
        final maxSeconds = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
        final currentSeconds = pos.inSeconds.toDouble().clamp(0.0, maxSeconds);

        return Column(
          children: [
            Row(
              children: [
                Text(_formatDuration(pos), style: const TextStyle(color: Colors.white, fontSize: 13)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: _isDraggingSeekbar ? 8 : 6),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: const Color(0xFF22C55E),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: currentSeconds,
                      min: 0,
                      max: maxSeconds,
                      onChangeStart: (_) => setState(() => _isDraggingSeekbar = true),
                      onChanged: (v) {
                        // Optional: Debounce seeking if needed, but smooth enough usually
                        player.seek(Duration(seconds: v.toInt()));
                      },
                      onChangeEnd: (_) {
                        setState(() => _isDraggingSeekbar = false);
                        _startHideTimer();
                      },
                    ),
                  ),
                ),
                Text(_formatDuration(dur), style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ],
        );
      },
    );
  }

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
  
  Widget _buildTextButton({required IconData icon, required String text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent, // Hit test area
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, "0");
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    
    if (hours > 0) {
      return "${two(hours)}:${two(mins)}:${two(secs)}";
    }
    return "${two(mins)}:${two(secs)}";
  }
}
