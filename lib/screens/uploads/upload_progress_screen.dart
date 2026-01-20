import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:lottie/lottie.dart';
import '../../utils/app_theme.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/shimmer_loading.dart';

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
    _refreshStatus();
    // Shimmer will show up for at least 2 seconds for a premium feel
    await Future.delayed(const Duration(milliseconds: 2000));
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
    FlutterBackgroundService().on('update').listen((event) {
      if (mounted && event != null) {
        setState(() {
          if (event['queue'] != null) {
            _queue = List<Map<String, dynamic>>.from(event['queue']);
          }
          if (event['isPaused'] != null) {
            _isPaused = event['isPaused'];
          }
          // Only stop loading if we are NOT in a manual refresh
          if (!_isManualRefreshing) {
            _isLoading = false;
          }
        });
      }
    });

    FlutterBackgroundService().on('task_completed').listen((event) {
       // Optional: Trigger specific animations
    });
  }

  void _togglePause() {
    final service = FlutterBackgroundService();
    setState(() => _isPaused = !_isPaused);
    
    if (_isPaused) {
      service.invoke('pause');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploads Paused ⏸️'), backgroundColor: Colors.orange),
      );
    } else {
      service.invoke('resume');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploads Resumed ▶️'), backgroundColor: Colors.green),
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
    final int pending = _queue.where((t) => t['status'] == 'pending').length;
    final int uploading = _queue.where((t) => t['status'] == 'uploading').length;
    final int completed = _queue.where((t) => t['status'] == 'completed').length;
    final int failed = _queue.where((t) => t['status'] == 'failed').length;
    final double overallProgress = _queue.isEmpty ? 1.0 : completed / _queue.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Status'),
        actions: [
          if (_queue.isNotEmpty)
            IconButton(
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.orange), 
              onPressed: _togglePause,
              tooltip: _isPaused ? 'Resume' : 'Pause',
            ),
          if (_queue.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red), 
              onPressed: _cancelAll,
              tooltip: 'Cancel All',
            )
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
                            return _buildTaskItem(task);
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4, // Very thin bar
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
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

  Widget _buildTaskItem(Map<String, dynamic> task) {
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
      clipBehavior: Clip.antiAlias, // Important for InkWell ripple to follow border radius
      child: InkWell(
        onTapDown: (_) {
           _holdTimer?.cancel();
           _holdTimer = Timer(const Duration(milliseconds: 500), () { 
              if (mounted) {
                HapticFeedback.heavyImpact();
                _showDeleteTaskDialog(task);
              }
           });
        },
        onTapCancel: () => _holdTimer?.cancel(),
        onTapUp: (_) => _holdTimer?.cancel(),
        child: ListTile(
          onLongPress: () {
            _holdTimer?.cancel();
            HapticFeedback.heavyImpact();
            _showDeleteTaskDialog(task);
          },
          leading: CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (task['paused'] == true ? 'PAUSED' : status.toString().toUpperCase()), 
                style: TextStyle(
                  fontSize: 10, 
                  color: task['paused'] == true ? Colors.orange : statusColor, 
                  fontWeight: FontWeight.bold
                )
              ),
              if (status == 'failed' && task['error'] != null)
                Text(task['error'], style: const TextStyle(fontSize: 10, color: Colors.red), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Individual Pause/Resume for pending or uploading tasks
              if (status == 'pending' || status == 'uploading' || task['paused'] == true)
                IconButton(
                  icon: Icon(
                    task['paused'] == true ? Icons.play_circle : Icons.pause_circle,
                    color: task['paused'] == true ? Colors.green : Colors.orange,
                    size: 28,
                  ),
                  onPressed: () => _toggleTaskPause(task),
                ),
              if (status == 'uploading' && task['paused'] != true)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleTaskPause(Map<String, dynamic> task) {
    final service = FlutterBackgroundService();
    final taskId = task['id'];
    final isPaused = task['paused'] == true;
    
    if (isPaused) {
      service.invoke('resume_task', {'taskId': taskId});
      setState(() => task['paused'] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resumed: ${task['remotePath'].toString().split('/').last}'), backgroundColor: Colors.green),
      );
    } else {
      service.invoke('pause_task', {'taskId': taskId});
      setState(() => task['paused'] = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paused: ${task['remotePath'].toString().split('/').last}'), backgroundColor: Colors.orange),
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
        int seconds = 4;
        bool isCountingDown = false;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Delete $name?'),
              content: Text(isCountingDown 
                  ? 'File will be deleted in $seconds seconds...' 
                  : 'This will stop the upload and permanently delete the file from the server. This cannot be undone.'),
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
                          service.invoke('delete_task', {'taskId': task['id']});
                          
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$name deleted completely'), backgroundColor: Colors.red),
                            );
                          }
                          return false;
                        }
                        return true;
                      });
                    }, 
                    child: const Text('Delete Permanently', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
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
}
