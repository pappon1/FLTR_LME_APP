import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/app_theme.dart';

class VideosTab extends StatelessWidget {
  const VideosTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Videos',
          style: AppTheme.heading2(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: AppTheme.infoGradient,
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.circlePlay,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Video Management',
              style: AppTheme.heading2(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload and manage course videos',
              style: AppTheme.bodyMedium(context),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const FaIcon(FontAwesomeIcons.upload, size: 20),
        label: const Text('Upload Video'),
        backgroundColor: AppTheme.infoGradient.colors.first,
        foregroundColor: Colors.white,
      ),
    );
  }
}
