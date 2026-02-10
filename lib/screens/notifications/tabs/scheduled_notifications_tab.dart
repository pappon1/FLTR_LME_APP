import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../utils/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../widgets/shimmer_loading.dart';
import '../edit_notification_screen.dart';
import '../../../services/bunny_cdn_service.dart';

class ScheduledNotificationsTab extends StatefulWidget {
  const ScheduledNotificationsTab({super.key});

  @override
  State<ScheduledNotificationsTab> createState() =>
      _ScheduledNotificationsTabState();
}

class _ScheduledNotificationsTabState extends State<ScheduledNotificationsTab> {
  bool _isRefreshing = false;

  Future<void> _cancelNotification(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Schedule?'),
        content: const Text(
          'Are you sure you want to cancel this scheduled notification? It will be removed permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc(id);
        final docSnapshot = await docRef.get();
        final data = docSnapshot.data();

        await docRef.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars(); // Clear previous
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Notification Canceled'),
              behavior: SnackBarBehavior.floating, // Make it floating
              margin: const EdgeInsets.all(16),
              action: SnackBarAction(
                label: 'UNDO',
                textColor: Colors.yellow,
                onPressed: () async {
                  if (data != null) {
                    await docRef.set(data);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Restored!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                  }
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _navigateToEditScreen(String id, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditNotificationScreen(notificationId: id, initialData: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Keep transparent to blend with parent
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isRefreshing = true);
          await Future.delayed(const Duration(seconds: 1)); // UX Delay
          if (mounted) setState(() => _isRefreshing = false);
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('status', isEqualTo: 'scheduled')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Stack(
                children: [
                  ListView(),
                  Center(child: Text('Error: ${snapshot.error}')),
                ],
              );
            }

            // Show shimmer if initial load OR currently refreshing visually
            if (snapshot.connectionState == ConnectionState.waiting ||
                _isRefreshing) {
              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 16,
                ),
                itemCount: 5,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) =>
                    const NotificationShimmerItem(),
              );
            }

            // Manual Sort (Client Side)
            final docs = List<DocumentSnapshot>.from(snapshot.data!.docs);
            docs.sort((a, b) {
              final t1 = (a.data() as Map)['scheduledAt'] as Timestamp?;
              final t2 = (b.data() as Map)['scheduledAt'] as Timestamp?;
              if (t1 == null) return 1;
              if (t2 == null) return -1;
              return t1.compareTo(t2);
            });

            if (docs.isEmpty) {
              return Stack(
                children: [
                  ListView(), // Always scrollable
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.clock,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Scheduled Notifications',
                          style: AppTheme.heading3(
                            context,
                          ).copyWith(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final id = docs[index].id;

                return _buildSystemNotificationItem(context, id, data);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSystemNotificationItem(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = data['title'] ?? 'No Title';
    final message = data['message'] ?? 'No Message';
    final imageUrl = data['imageUrl'];
    final date = (data['scheduledAt'] as Timestamp?)?.toDate();
    final timeStr = date != null
        ? DateFormat('h:mm a • d MMM').format(date)
        : 'Unscheduled';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Android System Notification Style Container
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              borderRadius: BorderRadius.circular(3.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (App Icon + Name + Time)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.handyman,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Engineer App',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• $timeStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.black54,
                        ),
                      ),
                      // Removed Icons from here
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Big Picture (If exists)
                if (imageUrl != null)
                  ClipRRect(
                    // No bottom radius here because we have buttons below now
                    child: CachedNetworkImage(
                      imageUrl: BunnyCDNService().getAuthenticatedUrl(
                        imageUrl!,
                      ),
                      width: double.infinity,
                      // removed height: 180 to allow full height
                      fit: BoxFit.fitWidth, // Show full image
                      httpHeaders: {'AccessKey': BunnyCDNService.apiKey},
                      errorWidget: (context, url, error) => Container(
                        height: 180,
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image, color: Colors.grey),
                            const SizedBox(height: 4),
                            Text(
                              'Error: $error',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      placeholder: (context, url) => Container(
                        height: 180,
                        color: Colors.grey[100],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 14),

                // Action Buttons Divider
                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),

                // Action Buttons Row
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _navigateToEditScreen(id, data),
                          icon: const Icon(
                            Icons.edit,
                            size: 18,
                            color: Colors.blue,
                          ),
                          label: const Text(
                            'EDIT',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.5),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _cancelNotification(id),
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'CANCEL',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
