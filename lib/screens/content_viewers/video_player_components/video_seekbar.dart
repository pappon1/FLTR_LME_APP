import 'package:flutter/material.dart';

class VideoSeekbar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Function(double) onChangeStart;
  final Function(double) onChanged;
  final Function(double) onChangeEnd;
  final bool isLocked;

  const VideoSeekbar({
    super.key,
    required this.position,
    required this.duration,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    this.isLocked = false,
  });

  @override
  State<VideoSeekbar> createState() => _VideoSeekbarState();
}

class _VideoSeekbarState extends State<VideoSeekbar> {
  double? _dragValue;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = widget.duration.inMilliseconds.toDouble() / 1000.0;
    final currentSeconds = _dragValue ?? (widget.position.inMilliseconds.toDouble() / 1000.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.isLocked)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _isDragging ? 12 : 8,
            alignment: Alignment.center,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: _isDragging ? 6 : 4,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: _isDragging ? 10 : 6,
                  elevation: _isDragging ? 4 : 2,
                ),
                activeTrackColor: const Color(0xFF22C55E),
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.white,
                overlayColor: const Color(0xFF22C55E).withOpacity(0.1),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
              ),
              child: Slider(
                value: currentSeconds.clamp(0.0, maxSeconds > 0 ? maxSeconds : 1.0),
                min: 0,
                max: maxSeconds > 0 ? maxSeconds : 1.0,
                onChangeStart: (v) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = v;
                  });
                  widget.onChangeStart(v);
                },
                onChanged: (v) {
                  setState(() {
                    _dragValue = v;
                  });
                  widget.onChanged(v);
                },
                onChangeEnd: (v) {
                  setState(() {
                    _isDragging = false;
                    _dragValue = null;
                  });
                  widget.onChangeEnd(v);
                },
              ),
            ),
          ),
        if (widget.isLocked) const SizedBox(height: 10),
        Opacity(
          opacity: widget.isLocked ? 0.7 : 1.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(Duration(milliseconds: (currentSeconds * 1000).toInt())),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatDuration(widget.duration),
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, "0");
    if (d.inHours > 0) {
      return "${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}";
    }
    return "${two(d.inMinutes)}:${two(d.inSeconds % 60)}";
  }
}
