import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import 'tabs/send_notification_tab.dart';
import 'tabs/scheduled_notifications_tab.dart';
import 'tabs/received_messages_tab.dart';

class NotificationManagerScreen extends StatefulWidget {
  const NotificationManagerScreen({super.key});

  @override
  State<NotificationManagerScreen> createState() =>
      _NotificationManagerScreenState();
}

class _NotificationManagerScreenState extends State<NotificationManagerScreen> {
  @override
  Widget build(BuildContext context) {
    const tabs = [
      Tab(
        child: FittedBox(fit: BoxFit.scaleDown, child: Text('Send')),
      ),
      Tab(
        child: FittedBox(fit: BoxFit.scaleDown, child: Text('Scheduled')),
      ),
      Tab(
        child: FittedBox(fit: BoxFit.scaleDown, child: Text('Received')),
      ),
    ];

    const tabViews = [
      SendNotificationTab(),
      ScheduledNotificationsTab(),
      ReceivedMessagesTab(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text('Notifications'),
            centerTitle: true,
            bottom: TabBar(
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorSize: TabBarIndicatorSize.label,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(width: 3, color: AppTheme.primaryColor),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(3.0),
                  topRight: Radius.circular(3.0),
                ),
              ),
              labelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              onTap: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              tabs: tabs,
            ),
          ),
          body: const TabBarView(children: tabViews),
        ),
      ),
    );
  }
}
