import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/app_theme.dart';

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({super.key});

  final List<Map<String, dynamic>> _activities = const [
    {
      'type': 'enroll',
      'title': 'Rahul Sharma enrolled in iPhone Repair Masterclass',
      'time': '2 minutes ago',
      'icon': FontAwesomeIcons.userPlus,
      'color': AppTheme.successGradient,
    },
    {
      'type': 'payment',
      'title': 'Payment received: ₹2,999 from Amit Kumar',
      'time': '15 minutes ago',
      'icon': FontAwesomeIcons.creditCard,
      'color': AppTheme.warningGradient,
    },
    {
      'type': 'video',
      'title': 'New video uploaded: Samsung S23 Battery Replacement',
      'time': '1 hour ago',
      'icon': FontAwesomeIcons.video,
      'color': AppTheme.infoGradient,
    },
    {
      'type': 'review',
      'title': 'Priya Patel left a 5-star review',
      'time': '2 hours ago',
      'icon': FontAwesomeIcons.star,
      'color': AppTheme.primaryGradient,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.clock,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Activity',
                      style: AppTheme.heading3(context),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activities.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final activity = _activities[index];
                return Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: activity['color'] as LinearGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        activity['icon'] as IconData,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['title'] as String,
                            style: AppTheme.bodyMedium(context).copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activity['time'] as String,
                            style: AppTheme.bodySmall(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
