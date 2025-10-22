import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:frontend/features/camera/camera_bloc.dart';
import 'package:frontend/features/camera/camera_event.dart';
import 'package:frontend/features/camera/camera_state.dart';
import 'package:frontend/widgets/navigation_cubit.dart';
import 'package:frontend/features/timer/timer_bloc.dart';
import 'package:frontend/features/timer/timer_event.dart';
import 'package:frontend/l10n/app_localizations_ext.dart';
import 'package:frontend/features/map/pin/pin_cubit.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/spacing.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CameraView();
  }
}

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  bool _hasTriggeredCamera = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentState = context.read<CameraBloc>().state;

    if ((currentState is CameraInitial || currentState is CameraCanceled) &&
        !_hasTriggeredCamera) {
      _hasTriggeredCamera = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CameraBloc>().add(CameraOpened());
      });
    }
  }

  Widget _buildCameraPreview(BuildContext context, CameraBloc cameraBloc) {
    final controller = cameraBloc.cameraController;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      );
    }

    return Stack(
      children: [
        SizedBox.expand(child: CameraPreview(controller)),
        Positioned.fill(
          child: Column(
            children: [
              // Header with back and map button
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: Spacing.huge,
                  bottom: Spacing.lg,
                  left: Spacing.lg,
                  right: Spacing.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.getString('camera.takePhotoHeader'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.surface,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                              color: AppColors.shadow,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Map button
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: Spacing.xxxl,
                    vertical: Spacing.xxxl,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.surface, width: 2),
                    borderRadius: BorderRadius.circular(Radii.card),
                  ),
                ),
              ),
              // Instructions + capture button
              Container(
                color: AppColors.surface,
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.lg,
                  vertical: Spacing.xxxl,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Center(
                            child: Text(
                              'P',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ),
                        SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text(
                            l10n.getString('camera.instructions'),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Spacing.lg),
                    Container(
                      width: double.maxFinite,
                      height: 1,
                      color: AppColors.border,
                    ),
                    SizedBox(height: Spacing.lg),
                    GestureDetector(
                      onTap: () {
                        final locale = Localizations.localeOf(context);
                        context.read<CameraBloc>().add(
                          PhotoCaptured(
                            locale: locale,
                            capturedAt: DateTime.now(),
                          ),
                        );
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 4),
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                              color: AppColors.shadow,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingView(String imagePath) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        SizedBox.expand(child: Image.file(File(imagePath), fit: BoxFit.cover)),
        Positioned(
          top: Spacing.huge,
          left: Spacing.lg,
          child: GestureDetector(
            onTap: () {
              context.read<CameraBloc>().add(CameraClosed());
              context.read<NavigationCubit>().setIndex(0);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.overlayLight,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
              SizedBox(height: Spacing.md),
              Text(
                l10n.getString('camera.analyzing'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.surface,
                ),
              ),
              SizedBox(height: Spacing.xs),
              SizedBox(
                width: 260,
                child: Text(
                  l10n.getString('camera.analyzingDetail'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.surface.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(String message) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      color: AppColors.cameraOverlay,
      width: double.infinity,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.xl + Spacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: AppColors.surface, size: 72),
                SizedBox(height: Spacing.md),
                Text(
                  l10n.getString('camera.errorTitle'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.surface,
                  ),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.surface.withValues(alpha: 0.75),
                  ),
                ),
                SizedBox(height: Spacing.xl + Spacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<CameraBloc>().add(PhotoRetaken());
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(l10n.getString('camera.retake')),
                  ),
                ),
                SizedBox(height: Spacing.sm),
                TextButton(
                  onPressed: () {
                    context.read<CameraBloc>().add(CameraClosed());
                    context.read<NavigationCubit>().setIndex(0);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.surface.withValues(alpha: 0.75),
                  ),
                  child: Text(l10n.getString('camera.errorBack')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisResultsView(SignAnalysisSuccess state) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Custom AppBar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.getString('camera.analysisTitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Preview
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.card),
                      image: DecorationImage(
                        image: FileImage(File(state.imagePath)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: Spacing.lg),

                  // Zone Header
                  Center(
                    child: Text(
                      l10n.getString('camera.zoneAdded'),
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  SizedBox(height: Spacing.sm),

                  // Stats Badge
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                        vertical: Spacing.xxs + 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(Radii.chip),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: AppColors.surface,
                          ),
                          SizedBox(width: Spacing.xxs + 2),
                          Text(
                            l10n.format('camera.restrictionsSynced', {
                              'count': state.restrictionsSaved.toString(),
                            }),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.surface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (state.replacedPrevious > 0) ...[
                    SizedBox(height: Spacing.xs),
                    Center(
                      child: Text(
                        l10n.format('camera.restrictionsReplaced', {
                          'count': state.replacedPrevious.toString(),
                        }),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],

                  SizedBox(height: Spacing.lg),

                  // AI Explanation Card
                  Container(
                    padding: EdgeInsets.all(Spacing.md + 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            SizedBox(width: Spacing.xs),
                            Text(
                              l10n.getString('camera.aiExplanation'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: Spacing.sm),
                        Text(
                          state.explanation.trim().isEmpty
                              ? l10n.getString('camera.aiExplanationFallback')
                              : state.explanation.trim(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary.withValues(alpha: 0.87),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: Spacing.xxl),

                  // Location Info
                  Center(
                    child: Text(
                      '${l10n.getString('camera.locationLabel')}: ${state.latitude.toStringAsFixed(5)}, ${state.longitude.toStringAsFixed(5)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),

                  SizedBox(height: Spacing.xl + Spacing.xxs),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            context.read<CameraBloc>().add(PhotoRetaken());
                          },
                          child: Text(l10n.getString('camera.buttonRetake')),
                        ),
                      ),
                      SizedBox(width: Spacing.sm),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            context.read<CameraBloc>().add(CameraClosed());
                            context.read<NavigationCubit>().setIndex(0);
                          },
                          child: Text(l10n.getString('camera.buttonDone')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.cameraOverlay,
      body: BlocConsumer<CameraBloc, CameraState>(
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);

          if (state is CameraError) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Unable to access the camera. Please check permissions or try again.',
                ),
              ),
            );
          } else if (state is SignAnalysisSuccess) {
            context.read<TimerBloc>().add(
              SetKnownZone(zoneNumber: state.zoneNumber),
            );
            context.read<PinCubit>().loadPins(forceRefresh: true);
          } else if (state is CameraCanceled) {
            _hasTriggeredCamera = false;
            context.read<CameraBloc>().add(CameraClosed());
            context.read<NavigationCubit>().setIndex(0);
          }
        },
        builder: (context, state) {
          if (state is CameraLoading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            );
          } else if (state is CameraError) {
            return _buildErrorView(state.message);
          } else if (state is CameraReady) {
            return _buildCameraPreview(context, context.read<CameraBloc>());
          } else if (state is PhotoUploading) {
            return _buildProcessingView(state.imagePath);
          } else if (state is SignAnalysisSuccess) {
            return _buildAnalysisResultsView(state);
          }

          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          );
        },
      ),
    );
  }
}
