import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ErrorLogsScreen extends StatelessWidget {
  const ErrorLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("System Error Logs", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textTheme.bodyLarge?.color),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('error_logs')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 60, color: Colors.green.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text("No Critical Errors Reported", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text("Your app is running smoothly.", style: GoogleFonts.inter(color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                         // Simulate an error for demo
                         FirebaseFirestore.instance.collection('error_logs').add({
                           'title': 'Test Error Log',
                           'details': 'This is a simulated error for testing the log viewer.',
                           'device': 'Admin Panel',
                           'timestamp': FieldValue.serverTimestamp(),
                           'version': '1.0.0'
                         });
                    }, 
                    child: const Text("Simulate Test Log")
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['title'] ?? 'Unknown Error',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                        Text(
                          DateFormat('MMM d, h:mm a').format(timestamp),
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['details'] ?? 'No details available.',
                      style: GoogleFonts.inter(fontSize: 13, color: theme.textTheme.bodyMedium?.color),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone_android, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(data['device'] ?? 'Unknown Device', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                        const SizedBox(width: 12),
                        Icon(Icons.info_outline, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text("v${data['version'] ?? '?'}", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
