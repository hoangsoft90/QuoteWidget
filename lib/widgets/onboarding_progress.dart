import 'package:flutter/material.dart';

/// Reusable 3-step onboarding progress indicator.
/// Step 1: Content (create collection + add items)
/// Step 2: Widget (add widget to home screen)
/// Step 3: Done
class OnboardingProgress extends StatelessWidget {
  final int currentStep; // 1, 2, or 3

  const OnboardingProgress({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStep(context, 1, 'Content', currentStep >= 1),
        _buildConnector(context, currentStep >= 2),
        _buildStep(context, 2, 'Widget', currentStep >= 2),
        _buildConnector(context, currentStep >= 3),
        _buildStep(context, 3, 'Done!', currentStep >= 3),
      ],
    );
  }

  Widget _buildStep(BuildContext context, int number, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: isActive
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }

  Widget _buildConnector(BuildContext context, bool isActive) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isActive
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
    );
  }
}
