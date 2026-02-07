import 'package:flutter/material.dart';
import '../../../../../utils/app_theme.dart';
import '../../local_logic/state_manager.dart';
import 'review_item.dart';

class CourseReviewCard extends StatelessWidget {
  final CourseStateManager state;
  final Function(int) onEditStep;

  const CourseReviewCard({
    super.key,
    required this.state,
    required this.onEditStep,
  });

  @override
  Widget build(BuildContext context) {
    final String title = state.titleController.text;
    final String? category = state.selectedCategory;

    final String? language = state.selectedLanguage;
    final String? courseMode = state.selectedCourseMode;
    final String? supportType = state.selectedSupportType;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(3.0),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.rate_review_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Quick Course Review',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const Divider(height: 24),

          // --- Step 1: Basic Info ---
          Text(
            'BASIC INFO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.withValues(alpha: 0.7),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          ReviewItem(
            icon: Icons.title,
            label: 'Title',
            value: title.isEmpty ? 'Not Set' : title,
            onEdit: () => onEditStep(0),
          ),
          ReviewItem(
            icon: Icons.category_outlined,
            label: 'Category',
            value: category ?? 'Not Selected',
            onEdit: () => onEditStep(0),
          ),


          const SizedBox(height: 8),
          const Divider(height: 24),

          // --- Step 1.5: Setup ---
          Text(
            'SETUP & PRICING',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.withValues(alpha: 0.7),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          ReviewItem(
            icon: Icons.payments_outlined,
            label: 'Pricing',
            value: _buildPricingText(),
            onEdit: () => onEditStep(1),
          ),
          ReviewItem(
            icon: Icons.language,
            label: 'Language',
            value: language ?? 'Not Set',
            onEdit: () => onEditStep(1),
          ),
          ReviewItem(
            icon: Icons.computer,
            label: 'Mode',
            value: courseMode ?? 'Not Set',
            onEdit: () => onEditStep(1),
          ),
          ReviewItem(
            icon: Icons.support_agent,
            label: 'Support',
            value: supportType ?? 'Not Set',
            onEdit: () => onEditStep(1),
          ),
          ReviewItem(
            icon: Icons.history_toggle_off,
            label: 'Validity',
            value: _getValidityText(state.courseValidityDays),
            onEdit: () => onEditStep(1),
          ),
          ReviewItem(
            icon: Icons.laptop_chromebook,
            label: 'Web/PC',
            value: state.isBigScreenEnabled ? 'Allowed' : 'Not Allowed',
            onEdit: () => onEditStep(1),
          ),

          const SizedBox(height: 8),
          const Divider(height: 24),

          // --- Step 3: Advance ---
          Text(
            'ADVANCE & CONTENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.withValues(alpha: 0.7),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          ReviewItem(
            icon: Icons.download_for_offline_outlined,
            label: 'Downloads',
            value: state.isOfflineDownloadEnabled ? 'Enabled' : 'Disabled',
            onEdit: () => onEditStep(3),
          ),
          if (state.specialTagController.text.isNotEmpty)
            ReviewItem(
              icon: Icons.local_offer_outlined,
              label: 'Special Tag',
              value: state.specialTagController.text,
              onEdit: () => onEditStep(3),
            ),
          ReviewItem(
            icon: Icons.video_collection_outlined,
            label: 'Videos',
            value:
                '${_countItemsRecursively(state.courseContents, 'video')} Videos Added',
            onEdit: () => onEditStep(2),
          ),
          ReviewItem(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Resources',
            value:
                '${_countItemsRecursively(state.courseContents, 'pdf')} PDFs Added',
            onEdit: () => onEditStep(2),
          ),
        ],
      ),
    );
  }

  String _buildPricingText() {
    final mrp = state.mrpController.text;
    final discount = state.discountAmountController.text;
    final finalPrice = state.finalPriceController.text;

    if (mrp.isEmpty && finalPrice.isEmpty) {
      return 'Not Set';
    }

    return '₹$mrp (MRP) - ₹$discount (Disc) = ₹$finalPrice';
  }

  String _getValidityText(int? days) {
    if (days == null) return 'Not Selected';
    if (days == 0) return 'Lifetime Access';
    if (days == 184) return '6 Months';
    if (days == 365) return '1 Year';
    if (days == 730) return '2 Years';
    if (days == 1095) return '3 Years';
    return '$days Days';
  }

  int _countItemsRecursively(List<dynamic> items, String type) {
    int count = 0;
    for (var item in items) {
      if (item['type'] == type) {
        count++;
      } else if (item['type'] == 'folder' && item['contents'] != null) {
        count += _countItemsRecursively(item['contents'], type);
      }
    }
    return count;
  }
}
