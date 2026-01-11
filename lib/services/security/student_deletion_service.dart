import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/student_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/dashboard_provider.dart';
import 'security_service.dart';

class StudentDeletionService {
  
  static Future<void> initiateDeletion(BuildContext context, StudentModel student) async {
    // 1. In-App PIN Security Check (Using SecurityService)
    bool authenticated = await SecurityService.verifyPin(context);

    if (!authenticated) {
      // User cancelled or failed
      return;
    }

    // 2. Timer Dialog (3 Seconds)
    if (!context.mounted) return;
    bool confirmInitial = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TimerDialog(),
    ) ?? false;

    if (!confirmInitial) return;

    // 3. Overview Dialog
    if (!context.mounted) return;
    _showOverviewDialog(context, student);
  }

  static void _showOverviewDialog(BuildContext context, StudentModel student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Student Overview & Deletion'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Name:', student.name),
              _infoRow('Email:', student.email),
              _infoRow('Joined:', DateFormat('dd MMM yyyy').format(student.joinedDate)),
              const SizedBox(height: 16),
              const Text('Enrolled Courses:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: student.enrolledCourses > 0 
                  ? Text('${student.enrolledCourses} Active Courses\n(Purchased via App/Admin)')
                  : const Text('No Active Courses'),
              ),
              const SizedBox(height: 16),
              const Text(
                'WARNING: This action is permanent. All course access, certificates, and progress will be wiped.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              _performFinalDelete(context, student);
            },
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text('PERMANENTLY DELETE', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          )
        ],
      ),
    );
  }

  static Future<void> _performFinalDelete(BuildContext context, StudentModel student) async {
    Navigator.pop(context); // Close dialog
    
    // Show loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      if (student.id.startsWith('dummy')) {
         await Future.delayed(const Duration(seconds: 1)); // Fake delay
      } else {
         await FirestoreService().deleteUser(student.id); 
      }
      
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student Deleted Successfully'), backgroundColor: Colors.green));
      
      // Refresh Data
      Provider.of<DashboardProvider>(context, listen: false).refreshData();
      
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete Error: $e'), backgroundColor: Colors.red));
    }
  }

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }
}

// --- Timer Dialog (Same as before) ---
class _TimerDialog extends StatefulWidget {
  @override
  State<_TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<_TimerDialog> {
  int _seconds = 3;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() async {
    while (_seconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Deletion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          Text(
            _seconds > 0 ? 'Wait $_seconds seconds...' : 'Are you sure?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _seconds == 0 ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('YES, PROCEED', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
