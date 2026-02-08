import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/shimmer_loading.dart';

import '../../../providers/admin_notification_provider.dart';

class ReceivedMessagesTab extends StatefulWidget {
  const ReceivedMessagesTab({super.key});

  @override
  State<ReceivedMessagesTab> createState() => _ReceivedMessagesTabState();
}

class _ReceivedMessagesTabState extends State<ReceivedMessagesTab> {
  // We need independent refreshing states for each tab/list or one global one?
  // The structure here is TabBarView with 3 lists.
  // RefreshIndicator is INSIDE _buildNotificationList.
  // So we need a way to track refreshing for EACH list.
  // Best way: Convert _buildNotificationList into a Stateful Widget, OR
  // maintain a map of states.
  // Let's keep it simple: Make the local widget stateful and use a map.

  final Map<String, bool> _refreshingStates = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminNotificationProvider>(
      builder: (context, notifProvider, _) {
        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                color: Theme.of(context).cardColor,
                child: TabBar(
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    _buildTab('Chat', notifProvider.unreadChat),
                    _buildTab('Downloads', notifProvider.unreadDownloads),
                    _buildTab('Payment', notifProvider.unreadPayment),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildNotificationList(context, 'message'),
                    _buildNotificationList(context, 'registration'),
                    _buildNotificationList(context, 'purchase'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationList(BuildContext context, String type) {
    return Column(
      children: [
        // Header with Mark All Read
        Consumer<AdminNotificationProvider>(
          builder: (context, provider, _) {
            int unreadCount = 0;
            if (type == 'message') {
              unreadCount = provider.unreadChat;
            } else if (type == 'registration') {
              unreadCount = provider.unreadDownloads;
            } else if (type == 'purchase') {
              unreadCount = provider.unreadPayment;
            }

            if (unreadCount == 0) return const SizedBox.shrink();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: Theme.of(context).cardColor.withValues(alpha: 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$unreadCount Unread',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => provider.markAllAsRead(type),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Mark All Read'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('admin_notifications')
                .where('type', isEqualTo: type)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // Fallback if index missing or error
                return Center(
                  child: Text(
                    'Waiting for data... ($type)\n${snapshot.error.toString().contains("requires an index") ? "Index Required" : ""}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }

              final isRefreshing = _refreshingStates[type] ?? false;

              if (snapshot.connectionState == ConnectionState.waiting ||
                  isRefreshing) {
                return ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  itemCount: 8,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      const NotificationShimmerItem(),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _refreshingStates[type] = true);
                    await Future.delayed(const Duration(seconds: 1));
                    if (mounted)
                      setState(() => _refreshingStates[type] = false);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            _getIconForType(type),
                            size: 48,
                            color: Colors.grey[200],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No active ${type}s',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() => _refreshingStates[type] = true);
                  await Future.delayed(const Duration(seconds: 1));
                  if (mounted) setState(() => _refreshingStates[type] = false);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildNotificationCard(context, doc.id, data, type);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'registration':
        return FontAwesomeIcons.download;
      case 'purchase':
        return FontAwesomeIcons.creditCard;
      case 'message':
        return FontAwesomeIcons.solidCommentDots;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  Widget _buildNotificationCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    String type,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null
        ? DateFormat('h:mm a, MMM d').format(timestamp.toDate())
        : 'Just now';
    final isRead = data['isRead'] == true;

    // Data Extraction
    final userName = data['userName'] ?? 'Unknown User';
    final userImage = data['userImage'] ?? '';
    final message = data['message'] ?? '';
    final amount = data['amount']; // For payment
    final title = data['title'] ?? ''; // Course title or general title
    final device = data['deviceModel'] ?? '';

    // "Parat Charaya Huwa" (Layered/Highlighted) effect for Unread
    // If Unread: Light Blue/Red Tint Background + Border
    // If Read: Standard Card color

    final Color unreadBg = isDark
        ? Colors.blue.withValues(alpha: 0.15)
        : Colors.blue.withValues(alpha: 0.05);
    final Color readBg = Theme.of(context).cardColor;

    return Card(
      elevation: isRead ? 1 : 3, // Higher elevation for unread
      color: isRead ? readBg : unreadBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3.0),
        side: isRead
            ? BorderSide.none
            : BorderSide(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(3.0),
        onTap: () {
          // 1. Mark as Read
          if (!isRead) {
            Provider.of<AdminNotificationProvider>(
              context,
              listen: false,
            ).markAsRead(docId);
          }

          // 2. Navigate
          // Navigation to UserProfileScreen removed as per request
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile details unavailable")),
          );

          // Or for chat, navigate to Chat
          // if (type == 'message') ...
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with Unread Dot if needed
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: userImage.isNotEmpty
                        ? NetworkImage(userImage)
                        : null,
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    child: userImage.isEmpty
                        ? FaIcon(
                            _getIconForType(type),
                            size: 20,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                  if (!isRead)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontWeight: !isRead
                                  ? FontWeight.w900
                                  : FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: !isRead
                                ? AppTheme.primaryColor
                                : Colors.grey[500],
                            fontWeight: !isRead
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    if (type == 'registration') ...[
                      Text(
                        'New App Download',
                        style: TextStyle(
                          color: Colors.blue[400],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (device.isNotEmpty)
                        Text(
                          'Device: $device',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                    ],

                    if (type == 'purchase') ...[
                      Text(
                        'Purchased: $title',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3.0),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Received ₹$amount',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (type == 'message') ...[
                      Text(
                        message,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.black87,
                          fontWeight: !isRead
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              if (type == 'message')
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 12,
                    color: Colors.grey[400],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
