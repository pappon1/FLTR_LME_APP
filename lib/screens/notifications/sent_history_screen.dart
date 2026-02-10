import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/bunny_cdn_service.dart';

class SentHistoryScreen extends StatefulWidget {
  const SentHistoryScreen({super.key});

  @override
  State<SentHistoryScreen> createState() => _SentHistoryScreenState();
}

class _SentHistoryScreenState extends State<SentHistoryScreen> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sent History'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isRefreshing = true);
          await Future.delayed(
            const Duration(seconds: 1),
          ); // Simulating refresh for UX
          if (mounted) setState(() => _isRefreshing = false);
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('status', isEqualTo: 'sent') // Explicitly filter
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              // Revert to simpler error message if resolved, or keep detail for safety.
              // But since we fixed the query, this error shouldn't happen.
              return const Center(child: Text('Error loading history'));
            }

            if (snapshot.connectionState == ConnectionState.waiting ||
                _isRefreshing) {
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

            // Manual client-side sorting to avoid Index Requirement
            final docs = List<DocumentSnapshot>.from(snapshot.data!.docs);
            docs.sort((a, b) {
              final t1 = (a.data() as Map)['sentAt'] as Timestamp?;
              final t2 = (b.data() as Map)['sentAt'] as Timestamp?;
              if (t1 == null) return 1;
              if (t2 == null) return -1;
              return t2.compareTo(t1); // Descending
            });

            if (docs.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                      ),
                      FaIcon(
                        FontAwesomeIcons.clockRotateLeft,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications sent yet.',
                        style: AppTheme.bodyLarge(context),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final date = (data['sentAt'] as Timestamp?)?.toDate();

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: FaIcon(
                        data['imageUrl'] != null
                            ? FontAwesomeIcons.image
                            : FontAwesomeIcons.bell,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    title: Text(
                      data['title'] ?? 'No Title',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      date != null
                          ? DateFormat('MMM d, h:mm a').format(date)
                          : 'Just now',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['imageUrl'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3.0),
                                  child: CachedNetworkImage(
                                    imageUrl: BunnyCDNService()
                                        .getAuthenticatedUrl(
                                          data['imageUrl'] as String,
                                        ),
                                    width: double.infinity,
                                    fit: BoxFit
                                        .fitWidth, // Adjusted for full image view
                                    httpHeaders: {
                                      'AccessKey': BunnyCDNService.apiKey,
                                    },
                                    placeholder: (c, u) => Container(
                                      height: 180,
                                      color: Colors.grey[200],
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const SizedBox(
                                          height: 50,
                                          child: Center(
                                            child: Icon(Icons.broken_image),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            Text(
                              data['message'] ?? '',
                              style: AppTheme.bodyMedium(context),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Audience: ${data['targetAudience'] ?? 'All'}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
