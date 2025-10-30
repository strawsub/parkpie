import 'package:flutter/material.dart';
import 'package:frontend/theme/spacing.dart';
import 'package:frontend/theme/app_colors.dart';

/// A banner widget that shows when the device is offline
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              Icons.wifi_off,
              color: AppColors.surface,
              size: 20,
              semanticLabel: 'No network connection',
            ),
            SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                'No network connection. Showing cached data. Please try again later.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.surface,
                  fontWeight: FontWeight.w500,
                  height: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
