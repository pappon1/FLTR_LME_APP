import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String videoTitle;

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
    required this.videoTitle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;

  bool _isPlaying = false;
  bool _showControls = true;
  bool _isLandscape = false;
  bool _isDraggingSeekbar = false;

  double _playbackSpeed = 1.0;
  String _currentQuality = "480p";
  String _currentSubtitle = "Off";
  bool _isLocked = false;

  Timer? _hideTimer;

  final _playlist = [
    {'title': '04. Summary & Quiz', 'duration': '05:45', 'watched': true},
    {'title': '05. Final Project Overview', 'duration': '12:20', 'watched': false},
    {'title': '06. Deployment Guide', 'duration': '08:15', 'watched': false},
    {'title': '07. Bonus Content', 'duration': '22:00', 'watched': false},
  ];

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    
    player.open(Media(widget.videoPath)).catchError((e) {
      debugPrint('Error opening video: $e');
    });
    
    player.stream.playing.listen((p) {
      if (mounted) {
        setState(() => _isPlaying = p);
      }
    });
    
    _startHideTimer();
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
    if (_showControls && _isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideTimer();
      }
    });
  }

  void _togglePlayPause() {
    player.playOrPause();
    _startHideTimer();
  }

  void _seekRelative(int seconds) {
    final current = player.state.position;
    final total = player.state.duration;
    
    var newPos = current + Duration(seconds: seconds);
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > total) newPos = total;
    
    player.seek(newPos);
  }

  void _toggleOrientation() {
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        if (_isLandscape) {
          _toggleOrientation();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E27),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Video Player Section
              SizedBox(
                width: size.width,
                height: _isLandscape ? size.height : size.width * 9 / 16,
                child: Stack(
                  children: [
                    // Video
                    Video(controller: controller, controls: (state) => const SizedBox()),
                    
                    // Tap Area
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _toggleControls,
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    // Controls
                    if (_showControls) _buildVideoControls(),
                  ],
                ),
              ),
              
              // Seekbar Section
              Container(
                color: const Color(0xFF0A0E27),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: _buildSeekbar(),
              ),
              
              // Control Icons Row
              Container(
                color: const Color(0xFF0A0E27),
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlIcon(Icons.speed, "${_playbackSpeed}x", () {}),
                    _buildControlIcon(Icons.closed_caption, _currentSubtitle == "Off" ? "Subtitle" : _currentSubtitle, () {}),
                    _buildControlIcon(Icons.settings, _currentQuality, () {}),
                    _buildControlIcon(Icons.lock_outline, "Lock", () {}),
                    _buildControlIcon(Icons.fullscreen, "Landscape", _toggleOrientation),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Playlist Section
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _playlist.length,
                  itemBuilder: (context, i) => _buildPlaylistItem(_playlist[i], i),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF0A0E27),
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
              widget.videoTitle,
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

  Widget _buildVideoControls() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // -10s
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
                onPressed: () => _seekRelative(-10),
              ),
              const Text('-10s', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 32),
          
          // Play/Pause
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 32),
          
          // +10s
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
                onPressed: () => _seekRelative(10),
              ),
              const Text('+10s', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ],
      ),
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
                value: currentSeconds,
                min: 0,
                max: maxSeconds,
                onChangeStart: (_) {
                  setState(() => _isDraggingSeekbar = true);
                },
                onChanged: (v) {
                  player.seek(Duration(seconds: v.toInt()));
                },
                onChangeEnd: (_) {
                  setState(() => _isDraggingSeekbar = false);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(pos),
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
    final isWatched = item['watched'] == true;
    
    return Container(
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
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_outline, color: Colors.white, size: 40),
                ),
              ),
              // Progress bar at bottom
              if (isWatched)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
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
                  item['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item['duration'],
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    if (isWatched) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Watched',
                          style: TextStyle(color: Colors.green, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, "0");
    return "${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}";
  }
}
