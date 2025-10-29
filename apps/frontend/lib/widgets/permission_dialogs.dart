import 'package:flutter/material.dart';
import 'package:frontend/theme/spacing.dart';
import 'package:frontend/theme/app_colors.dart';

/// Shows a dialog for location permission required for Timer
void showLocationPermissionDialog(BuildContext context) {
  final theme = Theme.of(context);

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.modal),
      ),
      backgroundColor: AppColors.surface,
      title: Text(
        'Location Required',
        style: theme.textTheme.titleLarge,
      ),
      content: Text(
        'Timer needs your location to work. Open Settings to turn on Location permission.',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: AppColors.surface,
            ),
            child: const Text('OK'),
          ),
        ),
      ],
    ),
  );
}

/// Shows a dialog for camera and location permissions required for Scan
void showCameraLocationPermissionDialog(BuildContext context) {
  final theme = Theme.of(context);

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.modal),
      ),
      backgroundColor: AppColors.surface,
      title: Text(
        'Camera and Location Required',
        style: theme.textTheme.titleLarge,
      ),
      content: Text(
        'Scan needs camera and location access to work. Open Settings to turn on both permissions.',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: AppColors.surface,
            ),
            child: const Text('OK'),
          ),
        ),
      ],
    ),
  );
}
