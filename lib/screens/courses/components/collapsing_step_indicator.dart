import 'package:flutter/material.dart';
import '../../../utils/app_theme.dart';

class CollapsingStepIndicator extends SliverPersistentHeaderDelegate {
  final int currentStep;
  final bool isSelectionMode;
  final bool isDragMode;

  CollapsingStepIndicator({
    required this.currentStep,
    required this.isSelectionMode,
    required this.isDragMode,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    if (isSelectionMode || isDragMode) return const SizedBox(height: 0.1);

    // Calculate collapse progress (0.0 to 1.0)
    final double progress = (shrinkOffset / (maxExtent - minExtent + 0.01)).clamp(0.0, 1.0);
    
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, 
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2), // Reduced vertical padding to 2
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16, 
            vertical: 10 - (progress * 5) 
          ), 
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 80, // Allow some padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: _buildStepCircle(0, 'Basic Info', progress)),
                  _buildStepLine(0, progress),
                  Flexible(child: _buildStepCircle(1, 'Contents', progress)),
                  _buildStepLine(1, progress),
                  Flexible(child: _buildStepCircle(2, 'Advance', progress)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCircle(int step, String label, double progress) {
    final bool isActive = currentStep >= step;
    final bool isCurrent = currentStep == step;
    
    // Scale ranges
    final double size = 32.0 - (progress * 14); // 32 -> 18
    final double iconScale = 16.0 - (progress * 6); // 16 -> 10
    final double fontSize = 11.0 - (progress * 4); // 11 -> 7

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Using Container instead of AnimatedContainer to prevent layout lag during fast scrolls
        Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            boxShadow: isActive ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Center(
            child: isCurrent 
              ? Icon(Icons.edit, size: iconScale, color: Colors.white)
              : isActive ? Icon(Icons.check, size: iconScale, color: Colors.white) : Text('${step + 1}', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
          ),
        ),
        if (progress < 0.8) ...[ 
          SizedBox(height: 6 - (progress * 6)),
          Opacity(
              opacity: (1.0 - progress * 2.0).clamp(0.0, 1.0), 
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label, 
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: fontSize, 
                    color: isActive ? AppTheme.primaryColor : Colors.grey.shade500,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
          ),
        ]
      ],
    );
  }

  Widget _buildStepLine(int step, double progress) {
    return Expanded(
      child: Container(
        height: 2,
        color: currentStep > step ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.2),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  @override
  double get maxExtent => (isSelectionMode || isDragMode) ? 0.1 : 85.0;

  @override
  double get minExtent => (isSelectionMode || isDragMode) ? 0.1 : 50.0;

  @override
  bool shouldRebuild(covariant CollapsingStepIndicator oldDelegate) {
    return oldDelegate.currentStep != currentStep || 
           oldDelegate.isSelectionMode != isSelectionMode ||
           oldDelegate.isDragMode != isDragMode;
  }
}
