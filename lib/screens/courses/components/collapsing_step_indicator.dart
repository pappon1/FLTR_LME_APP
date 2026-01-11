import 'package:flutter/material.dart';
import '../../../utils/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    if (isSelectionMode || isDragMode) return const SizedBox.shrink();

    // Calculate collapse progress (0.0 to 1.0)
    final double progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    
    // Animate dimensions based on progress
    final double cardHeight = 120.0 - (progress * 50); // From 120 to 70
    final double iconSize = 48.0 - (progress * 24); // From 32 to 20 approx range
    final double fontSize = 11.0 - (progress * 11.0); // Fade out text completely or shrink? User said "chota hojaye" but maintain visibility. Let's make it 9.
    
    // User requested "card ki size 4 dp he to flod hoke 2 dp hojaye". 
    // This is metaphorical for "Shrink by half".
    
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // Match background to hide content behind
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16, 
            vertical: 12 - (progress * 4) // Reduce padding slightly
          ), 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepCircle(0, 'Basic Info', progress),
              _buildStepLine(0, progress),
              _buildStepCircle(1, 'Contents', progress),
              _buildStepLine(1, progress),
              _buildStepCircle(2, 'Advance', progress),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCircle(int step, String label, double progress) {
    bool isActive = currentStep >= step;
    bool isCurrent = currentStep == step;
    
    // Scale down Size
    double size = 32.0 - (progress * 10); // 32 -> 22
    double iconScale = 16.0 - (progress * 4); // 16 -> 12
    double fontSize = 11.0 - (progress * 3); // 11 -> 8

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: 100.ms,
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.grey.withOpacity(0.2),
            shape: BoxShape.circle,
            boxShadow: isActive ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Center(
            child: isCurrent 
              ? Icon(Icons.edit, size: iconScale, color: Colors.white)
              : isActive ? Icon(Icons.check, size: iconScale, color: Colors.white) : Text('${step + 1}', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
          ),
        ),
        if (progress < 0.6) ...[
          SizedBox(height: 6 - (progress * 6)),
          Opacity(
              opacity: (1.0 - progress * 1.5).clamp(0.0, 1.0),
              child: Text(label, style: TextStyle(
                fontSize: fontSize, 
                color: isActive ? AppTheme.primaryColor : Colors.grey.shade500,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              )),
          ),
        ]
      ],
    );
  }

  Widget _buildStepLine(int step, double progress) {
    return Expanded(
      child: Container(
        height: 2,
        color: currentStep > step ? AppTheme.primaryColor : Colors.grey.withOpacity(0.2),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  @override
  double get maxExtent => 110.0; // Normal Height

  @override
  double get minExtent => 70.0; // Collapsed Height

  @override
  bool shouldRebuild(covariant CollapsingStepIndicator oldDelegate) {
    return oldDelegate.currentStep != currentStep || 
           oldDelegate.isSelectionMode != isSelectionMode ||
           oldDelegate.isDragMode != isDragMode;
  }
}
