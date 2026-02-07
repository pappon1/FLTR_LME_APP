import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/local_notification_service.dart';

class AdminNotificationProvider with ChangeNotifier {
  final LocalNotificationService _notificationService =
      LocalNotificationService();
  StreamSubscription? _subscription;

  // Counts
  int _unreadChat = 0;
  int _unreadDownloads = 0;
  int _unreadPayment = 0;

  int get unreadChat => _unreadChat;
  int get unreadDownloads => _unreadDownloads;
  int get unreadPayment => _unreadPayment;
  int get totalUnread => _unreadChat + _unreadDownloads + _unreadPayment;

  // Set of known IDs to prevent re-notifying on restart
  bool _isFirstLoad = true;

  void init() {
    _notificationService.init();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    _subscription = FirebaseFirestore.instance
        .collection('admin_notifications')
        .where('isRead', isEqualTo: false) // Only fetch unread to count badges
        .snapshots()
        .listen((snapshot) {
          int chat = 0;
          int downloads = 0;
          int payment = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final type = data['type'] as String?;
            if (type == 'message') {
              chat++;
            } else if (type == 'registration') {
              downloads++;
            } else if (type == 'purchase') {
              payment++;
            }
          }

          _unreadChat = chat;
          _unreadDownloads = downloads;
          _unreadPayment = payment;
          notifyListeners();

          // Handle New Notifications for System Alert
          if (!_isFirstLoad) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null) {
                  _triggerSystemNotification(data);
                }
              }
            }
          } else {
            _isFirstLoad = false;
          }
        });
  }

  void _triggerSystemNotification(Map<String, dynamic> data) {
    final type = data['type'] ?? 'Notification';
    String title = 'Notification';
    String body = 'You have a new update';

    if (type == 'message') {
      title = 'New Message from ${data['userName'] ?? 'User'}';
      body = data['message'] ?? 'Sent a message';
    } else if (type == 'purchase') {
      title = 'New Payment Recieved';
      body =
          '${data['userName']} bought ${data['title']} for ₹${data['amount']}';
    } else if (type == 'registration') {
      title = 'New App Download';
      body =
          '${data['userName']} just registered on ${data['deviceModel'] ?? 'Device'}';
    }

    _notificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
    );
  }

  Future<void> markAsRead(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_notifications')
          .doc(docId)
          .update({'isRead': true});
    } catch (e) {
      // debugPrint('Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead(String type) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_notifications')
          .where('type', isEqualTo: type)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      // Ignore
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
