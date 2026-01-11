import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import 'tabs/send_notification_tab.dart';
import 'tabs/scheduled_notifications_tab.dart';
import 'tabs/received_messages_tab.dart';

class NotificationManagerScreen extends StatelessWidget {
  const NotificationManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('status', isEqualTo: 'scheduled')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        
        bool hasScheduled = false;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          hasScheduled = true;
        }

        final tabs = [
          const Tab(text: 'Send'),
          if (hasScheduled) const Tab(text: 'Scheduled'),
          const Tab(text: 'Received'),
        ];

        final tabViews = [
          const SendNotificationTab(),
          if (hasScheduled) const ScheduledNotificationsTab(),
          const ReceivedMessagesTab(),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            behavior: HitTestBehavior.opaque,
            child: Scaffold(
              resizeToAvoidBottomInset: false, // Prevents keyboard from pushing content up unnecessarily if scrolling handles it
              appBar: AppBar(
                title: const Text('Notifications'),
                centerTitle: true,
                bottom: TabBar(
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  onTap: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  tabs: tabs,
                ),
              ),
              body: TabBarView(
                children: tabViews,
              ),
            ),
          ),
        );
      },
    );
  }
}
