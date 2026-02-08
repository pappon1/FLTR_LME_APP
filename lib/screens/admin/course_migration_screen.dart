import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseMigrationScreen extends StatefulWidget {
  const CourseMigrationScreen({super.key});

  @override
  State<CourseMigrationScreen> createState() => _CourseMigrationScreenState();
}

class _CourseMigrationScreenState extends State<CourseMigrationScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;
  String _status = 'Ready to migrate';
  int _coursesProcessed = 0;
  int _videosFixed = 0;
  final List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.insert(
        0,
        '[${DateTime.now().toString().substring(11, 19)}] $message',
      );
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  Future<void> _startMigration() async {
    setState(() {
      _isProcessing = true;
      _status = 'Starting migration...';
      _coursesProcessed = 0;
      _videosFixed = 0;
      _logs.clear();
    });

    try {
      _addLog('Fetching all courses...');
      final snapshot = await _firestore.collection('courses').get();
      _addLog('Found ${snapshot.docs.length} courses');

      for (final doc in snapshot.docs) {
        final courseId = doc.id;
        final data = doc.data();
        final courseName = data['title'] ?? 'Unknown';

        _addLog('Processing: $courseName');

        final List<dynamic> contents = data['contents'] ?? [];
        bool hasChanges = false;

        // Recursive function to fix durations
        List<dynamic> fixContents(List<dynamic> items) {
          final fixed = <Map<String, dynamic>>[];

          for (var item in items) {
            final fixedItem = Map<String, dynamic>.from(item);

            if (fixedItem['type'] == 'video') {
              final duration = fixedItem['duration'];

              if (duration is String && duration.contains(':')) {
                // Convert string duration to integer seconds
                final converted = _convertDurationToSeconds(duration);
                if (converted > 0) {
                  fixedItem['duration'] = converted;
                  hasChanges = true;
                  _videosFixed++;
                  _addLog(
                    '  ✅ Fixed: ${fixedItem['name']} ($duration → ${converted}s)',
                  );
                }
              } else if (duration == null) {
                _addLog('  ⚠️ Missing duration: ${fixedItem['name']}');
              }
            }

            // Recursively fix nested folder contents
            if (fixedItem['type'] == 'folder' &&
                fixedItem['contents'] != null) {
              fixedItem['contents'] = fixContents(
                List<dynamic>.from(fixedItem['contents']),
              );
            }

            fixed.add(fixedItem);
          }

          return fixed;
        }

        final fixedContents = fixContents(contents);

        if (hasChanges) {
          await doc.reference.update({'contents': fixedContents});
          _addLog('  💾 Updated course: $courseName');
        } else {
          _addLog('  ⏭️ No changes needed: $courseName');
        }

        _coursesProcessed++;
        setState(() {
          _status =
              'Processed $_coursesProcessed/${snapshot.docs.length} courses';
        });
      }

      _addLog('✅ Migration completed!');
      _addLog('Total courses: $_coursesProcessed');
      _addLog('Videos fixed: $_videosFixed');

      setState(() {
        _status =
            'Migration completed! Fixed $_videosFixed videos across $_coursesProcessed courses';
      });
    } catch (e) {
      _addLog('❌ Error: $e');
      setState(() {
        _status = 'Migration failed: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  int _convertDurationToSeconds(String duration) {
    try {
      final parts = duration.split(':');
      if (parts.length == 2) {
        // MM:SS
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return (minutes * 60) + seconds;
      } else if (parts.length == 3) {
        // HH:MM:SS
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return (hours * 3600) + (minutes * 60) + seconds;
      }
    } catch (e) {
      // Ignore parse errors
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Migration Tool'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Duration Format Migration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This tool will convert old string format durations (e.g., "00:19") to integer seconds format.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Courses Processed',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '$_coursesProcessed',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Videos Fixed',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '$_videosFixed',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_isProcessing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (_isProcessing) const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _status,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _isProcessing
                                  ? Colors.blue
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isProcessing ? null : _startMigration,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isProcessing ? 'Processing...' : 'Start Migration',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Migration Logs:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: ListView.builder(
                  reverse: false,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    Color logColor = Colors.white70;
                    if (log.contains('✅')) logColor = Colors.greenAccent;
                    if (log.contains('❌')) logColor = Colors.redAccent;
                    if (log.contains('⚠️')) logColor = Colors.orangeAccent;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: logColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
