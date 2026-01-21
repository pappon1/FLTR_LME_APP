import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:io';
import 'package:lottie/lottie.dart';
import '../../utils/app_theme.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/shimmer_loading.dart';
import 'dart:math' as math;

class UploadProgressScreen extends StatefulWidget {
  const UploadProgressScreen({super.key});

  @override
  State<UploadProgressScreen> createState() => _UploadProgressScreenState();
}

class _UploadProgressScreenState extends State<UploadProgressScreen> {
  List<Map<String, dynamic>> _queue = [];
  bool _isLoading = true;
  bool _isPaused = false; 
  bool _isManualRefreshing = false;
  Timer? _holdTimer;
  StreamSubscription? _statusSubscription;
  final Map<String, DateTime> _lastManualUpdates = {};
  @override
  void initState() {
    super.initState();
    _loadInitialState();
    _setupListener();
    _refreshStatus();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _refreshStatus() {
    FlutterBackgroundService().invoke('get_status');
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isLoading = true;
      _isManualRefreshing = true;
    });
    
    // 1. Ask service for update
    _refreshStatus();
    
    // 2. Also load from SharedPreferences for safety (if service is asleep)
    await _loadInitialState();
    
    // Shimmer will show up for at least 800ms for a premium feel
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isManualRefreshing = false;
      });
    }
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final String? queueJson = prefs.getString('upload_queue_v1');
    if (queueJson != null && mounted) {
      setState(() {
        _queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
        _isLoading = false;
      });
    } else {
      // Small artificial delay to show shimmer if fast
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _isLoading = false);
    }
  }

   void _setupListener() {
    _statusSubscription = FlutterBackgroundService().on('update').listen((event) {
      if (mounted && event != null) {

        setState(() {
          if (event['queue'] != null) {
            final List<dynamic> incomingQueue = event['queue'];
            final now = DateTime.now();

            // Smart Merge: Don't let service overwrite a very recent manual toggle
            _queue = incomingQueue.map((t) {
              final taskId = t['taskId'] ?? t['id'];
              final taskMap = Map<String, dynamic>.from(t);
              
              if (taskId != null && _lastManualUpdates.containsKey(taskId)) {
                final diff = now.difference(_lastManualUpdates[taskId]!);
                if (diff.inMilliseconds < 2500) {
                   // Keep the local 'paused' state, ignore service for a moment
                   final localTask = _queue.firstWhere((lt) => (lt['taskId'] ?? lt['id']) == taskId, orElse: () => {});
                   if (localTask.isNotEmpty) {
                      taskMap['paused'] = localTask['paused'];
                      // Also keep the local status if it was just resumed from failed
                      if (localTask['paused'] == false && localTask['status'] == 'pending' && t['status'] == 'failed') {
                         taskMap['status'] = 'pending';
                      }
                   }
                } else {
                   // Clean up map if too old
                   _lastManualUpdates.remove(taskId);
                }
              }
              return taskMap;
            }).toList();
          }
          if (event['isPaused'] != null) {
            _isPaused = event['isPaused'];
          }
          if (!_isManualRefreshing) {
            _isLoading = false;
          }
        });
      }
    });

    // Heartbeat Monitor removed

    FlutterBackgroundService().on('task_completed').listen((event) {
       // Optional: Trigger specific animations
    });
  }

  void _togglePause() async {
    final service = FlutterBackgroundService();
    final bool becomingPaused = !_isPaused;

    // 1. INSTANT UI UPDATE
    HapticFeedback.mediumImpact();
    setState(() {
      _isPaused = becomingPaused;
      for (var task in _queue) {
        if (task['status'] == 'pending' || task['status'] == 'uploading') {
          task['paused'] = becomingPaused;
        }
      }
    });

    // 2. TRIGGER SERVICE (Background)
    () async {
      if (!await service.isRunning()) {
        await service.startService();
        await Future.delayed(const Duration(milliseconds: 500)); 
      }
      service.invoke(becomingPaused ? 'pause' : 'resume');
    }();
    
    // 3. SNACKBAR
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(becomingPaused ? 'Queue Paused ⏸️' : 'Queue Resumed ▶️'), 
          backgroundColor: becomingPaused ? Colors.orange : Colors.green,
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _cancelAll() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    
    if (!isRunning) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active upload service found'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) {
        int seconds = 4;
        bool isCountingDown = false;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cancel All Uploads?'),
              content: Text(isCountingDown 
                  ? 'Deletion will start in $seconds seconds...' 
                  : 'This will stop all ongoing uploads and clear the queue. This action cannot be undone.'),
              actions: [
                if (!isCountingDown)
                  TextButton(
                    onPressed: () {
                      setDialogState(() => isCountingDown = true);
                      Future.doWhile(() async {
                        await Future.delayed(const Duration(seconds: 1));
                        if (!ctx.mounted) return false;
                        setDialogState(() => seconds--);
                        if (seconds <= 0) {
                          // Execute deletion
                          service.invoke('cancel_all');
                          await Future.delayed(const Duration(milliseconds: 500));
                          service.invoke('stop');
                          
                          if (mounted) {
                            setState(() => _queue.clear());
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All uploads deleted'), backgroundColor: Colors.red),
                            );
                          }
                          return false;
                        }
                        return true;
                      });
                    }, 
                    child: const Text('Delete All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                  ),
                if (isCountingDown)
                   TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('STOP ($seconds)', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                if (!isCountingDown)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
              ],
            );
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate Stats
    // Calculate Stats (Single Pass Optimization)
    int pending = 0;
    int uploading = 0;
    int completed = 0;
    int failed = 0;

    for (final t in _queue) {
      final status = t['status'];
      if (status == 'pending') pending++;
      else if (status == 'uploading') uploading++;
      else if (status == 'completed') completed++;
      else if (status == 'failed') failed++;
    }
    final double overallProgress = _queue.isEmpty ? 1.0 : completed / _queue.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uploads', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        titleSpacing: 0,
        actions: [
          if (_queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: TextButton.icon(
                onPressed: _togglePause,
                icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
                label: Text(_isPaused ? 'Resume' : 'Pause', style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  backgroundColor: (_isPaused ? Colors.green : Colors.orange).withOpacity(0.1),
                  foregroundColor: _isPaused ? Colors.green : Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          if (_queue.isNotEmpty)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 22), 
              onPressed: _cancelAll,
              tooltip: 'Cancel All',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _isLoading 
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildShimmerState(),
              )
            : _queue.isEmpty 
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height - 100, // Make it fill screen so pull works
                      child: _buildEmptyState(),
                    ),
                  )
                : Column(
                    children: [
                      _buildHeaderStats(uploading, pending, failed, overallProgress),
                      Expanded(
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _queue.length,
                          itemBuilder: (context, index) {
                            final task = _queue[index];
                            return UploadTaskCard(
                              task: task,
                              onTogglePause: () => _toggleTaskPause(task),
                              onDelete: () => _showDeleteTaskDialog(task),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildShimmerState() {
    return Column(
      children: [
        // Fake Header Stat Shimmer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          height: 80, // Ultra slim shimmer
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerLoading.rectangular(height: 14, width: 40),
                  ShimmerLoading.rectangular(height: 14, width: 40),
                  ShimmerLoading.rectangular(height: 14, width: 40),
                ],
              ),
              SizedBox(height: 12),
              ShimmerLoading.rectangular(height: 6),
            ],
          ),
        ),
        const ShimmerList(
          itemBuilder: UploadShimmerItem(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done, size: 80, color: Colors.green.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No Active Uploads', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Your upload queue is clean.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHeaderStats(int uploading, int pending, int failed, double progress) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), // Minimum padding
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)), 
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat('Active', uploading.toString(), Colors.blue),
              _buildStat('Pending', pending.toString(), Colors.orange),
              _buildStat('Failed', failed.toString(), Colors.red),
              Text(
                '${(progress * 100).toInt()}%', 
                style: TextStyle(
                  color: AppTheme.primaryColor, 
                  fontSize: 14, 
                  fontWeight: FontWeight.bold
                )
              ),
            ],
          ),
          const SizedBox(height: 8), 
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4, 
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$value $label', 
          style: TextStyle(
            color: color.withOpacity(0.8), 
            fontSize: 10, 
            fontWeight: FontWeight.bold
          )
        ),
      ],
    );
  }



  void _toggleTaskPause(Map<String, dynamic> task) async {
    final service = FlutterBackgroundService();
    final taskId = task['taskId'] ?? task['id']; // Safety fallback
    final isPaused = task['paused'] == true;
    
    // 1. INSTANT UI UPDATE (Optimistic)
    HapticFeedback.lightImpact();
    if (taskId != null) _lastManualUpdates[taskId] = DateTime.now();
    
    setState(() {
      task['paused'] = !isPaused;
      if (isPaused && task['status'] == 'failed') {
        task['status'] = 'pending';
      }
    });

    // 2. TRIGGER SERVICE (In background)
    () async {
      if (!await service.isRunning()) {
         await service.startService();
         // Wait longer for isolate to boot before sending command
         await Future.delayed(const Duration(milliseconds: 1000));
      }
      
      if (isPaused) {
        service.invoke('resume_task', {'taskId': taskId});
      } else {
        service.invoke('pause_task', {'taskId': taskId});
      }
    }();

    // 3. SHOW SNACKBAR (Non-blocking)
    if (mounted) {
       ScaffoldMessenger.of(context).hideCurrentSnackBar();
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(isPaused ? 'Resuming...' : 'Pausing...'), 
           duration: const Duration(milliseconds: 600),
           backgroundColor: isPaused ? Colors.green : Colors.orange
         ),
       );
    }
  }

  void _showDeleteTaskDialog(Map<String, dynamic> task) {
    final name = task['remotePath'].toString().split('/').last;
    final service = FlutterBackgroundService();

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Delete $name?'),
          content: const Text('This will stop the upload and permanently delete the file from the server. This cannot be undone.'),
          actions: [
              TextButton(
                onPressed: () {
                      // Execute deletion
                      // Optimistic UI Update + Start Service to handle command
                      final taskId = task['taskId'] ?? task['id'];
                      service.startService().then((_) {
                        service.invoke('delete_task', {'taskId': taskId});
                      });
                      
                      if (mounted) {
                        setState(() {
                          _queue.removeWhere((t) => (t['taskId'] ?? t['id']) == taskId);
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$name removed'), backgroundColor: Colors.red),
                        );
                      }
                }, 
                child: const Text('Delete Permanently', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
          ],
        );
      }
    );
  }
}

String _formatBytes(int? bytes, int decimals) {
  if (bytes == null || bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB"];
  var i = (math.log(bytes) / math.log(1024)).floor();
  return ((bytes / math.pow(1024, i)).toStringAsFixed(decimals)) + ' ' + suffixes[i];
}

class UploadTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTogglePause;
  final VoidCallback onDelete;

  const UploadTaskCard({
    super.key,
    required this.task,
    required this.onTogglePause,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    
    final status = task['status'];
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.schedule;

    if (status == 'uploading') {
      statusColor = Colors.blue;
      statusIcon = Icons.upload;
    } else if (status == 'completed') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'failed') {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    }

    final String name = task['remotePath'].toString().split('/').last;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () {
            HapticFeedback.heavyImpact();
            onDelete();
        },
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: _buildLeading(task),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (task['paused'] == true ? 'PAUSED' : status.toString().toUpperCase()), 
                    style: TextStyle(
                      fontSize: 10, 
                      color: task['paused'] == true ? Colors.orange : statusColor, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                  if (task['totalBytes'] != null)
                    Text(
                      status == 'completed' 
                        ? "Total: ${_formatBytes(task['totalBytes'], 1)}"
                        : "${_formatBytes(task['uploadedBytes'] ?? 0, 1)} / ${_formatBytes(task['totalBytes'], 1)}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500
                      ),
                    ),
                ],
              ),
              if (status == 'failed' && task['error'] != null)
                Text(task['error'], style: const TextStyle(fontSize: 10, color: Colors.red), maxLines: 1, overflow: TextOverflow.ellipsis),
              
              if (status == 'uploading' || (task['paused'] == true && (task['progress'] ?? 0) > 0))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: (task['progress'] ?? 0).toDouble()),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: value,
                        backgroundColor: statusColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ACTION BUTTON (Pause/Resume/Retry)
              if (status != 'completed')
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: onTogglePause,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == 'failed') ...[
                          const Icon(Icons.refresh_rounded, color: Colors.blue, size: 22),
                          const Text('Retry', style: TextStyle(fontSize: 8, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ] else if (task['paused'] == true) ...[
                          const Icon(Icons.play_circle_filled_rounded, color: Colors.green, size: 22),
                          const Text('Resume', style: TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold)),
                        ] else ...[
                          const Icon(Icons.pause_circle_filled_rounded, color: Colors.orange, size: 22),
                          const Text('Pause', style: TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                ),
              // SPINNER (Only for active uploading)
              if (status == 'uploading' && task['paused'] != true)
                const SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.orange))
                ),
              if (status == 'completed')
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(Map<String, dynamic> task) {
    final String path = (task['localPath'] ?? task['remotePath'] ?? '').toString().toLowerCase();
    final String thumbnail = task['thumbnail'] ?? '';
    
    // File Type Detection
    final bool isVideo = path.endsWith('.mp4') || path.endsWith('.mkv') || path.endsWith('.mov') || path.endsWith('.avi');
    final bool isImage = path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png') || path.endsWith('.webp');
    final bool isPdf = path.endsWith('.pdf');
    final bool isZip = path.endsWith('.zip') || path.endsWith('.rar') || path.endsWith('.7z');

    if (isVideo) {
      return Container(
        width: 60,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(6),
          image: thumbnail.isNotEmpty && File(thumbnail).existsSync()
              ? DecorationImage(image: FileImage(File(thumbnail)), fit: BoxFit.cover)
              : null,
        ),
        child: thumbnail.isEmpty || !File(thumbnail).existsSync()
            ? const Center(child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 16))
            : Center(
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                ),
              ),
      );
    }

    if (isImage) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          image: File(task['localPath'] ?? '').existsSync()
              ? DecorationImage(image: FileImage(File(task['localPath'])), fit: BoxFit.cover)
              : null,
        ),
        child: !File(task['localPath'] ?? '').existsSync()
            ? const Icon(Icons.image_rounded, color: Colors.grey, size: 20)
            : null,
      );
    }

    // Document Icons with Premium Tinted Backgrounds
    Color docColor = Colors.grey;
    IconData docIcon = Icons.insert_drive_file_rounded;

    if (isPdf) {
      docColor = Colors.red;
      docIcon = Icons.picture_as_pdf_rounded;
    } else if (isZip) {
      docColor = Colors.amber[700]!;
      docIcon = Icons.folder_zip_rounded;
    } else if (path.contains('folder')) {
      docColor = Colors.blue;
      docIcon = Icons.folder_rounded;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: docColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(docIcon, color: docColor, size: 22),
    );
  }
}
