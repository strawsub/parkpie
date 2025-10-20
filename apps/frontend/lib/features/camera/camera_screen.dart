import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:frontend/features/camera/camera_bloc.dart';
import 'package:frontend/features/camera/camera_event.dart';
import 'package:frontend/features/camera/camera_state.dart';
import 'package:frontend/features/navigation/navigation_cubit.dart';
import 'package:frontend/features/timer/timer_bloc.dart';
import 'package:frontend/features/timer/timer_event.dart';
import 'package:frontend/l10n/app_localizations_ext.dart';
import 'package:frontend/features/map/pin/pin_cubit.dart';

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
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
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
                padding: const EdgeInsets.only(
                  top: 60,
                  bottom: 20,
                  left: 20,
                  right: 20,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.getString('camera.takePhotoHeader'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black.withValues(alpha: 0.5),
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              // Instructions + capture button
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 40,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Center(
                            child: Text(
                              'P',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.getString('camera.instructions'),
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.maxFinite,
                      height: 1,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 20),
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
                          color: const Color(0xFF7FAC58),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                              color: Colors.black.withValues(alpha: 0.3),
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
    return Stack(
      children: [
        SizedBox.expand(child: Image.file(File(imagePath), fit: BoxFit.cover)),
        Positioned(
          top: 60,
          left: 20,
          child: GestureDetector(
            onTap: () {
              context.read<CameraBloc>().add(CameraClosed());
              context.read<NavigationCubit>().setIndex(0);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7FAC58)),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.getString('camera.analyzing'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 260,
                child: Text(
                  l10n.getString('camera.analyzingDetail'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
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
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 72),
                const SizedBox(height: 16),
                Text(
                  l10n.getString('camera.errorTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<CameraBloc>().add(PhotoRetaken());
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(l10n.getString('camera.retake')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7FAC58),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    context.read<CameraBloc>().add(CameraClosed());
                    context.read<NavigationCubit>().setIndex(0);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.75),
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
    return Scaffold(
      backgroundColor: Colors.white,
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
                      style: const TextStyle(
                        color: Colors.black,
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
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(File(state.imagePath)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Zone Header
                  Center(
                    child: Text(
                      l10n.getString('camera.zoneAdded'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Stats Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7FAC58),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.format('camera.restrictionsSynced', {
                              'count': state.restrictionsSaved.toString(),
                            }),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (state.replacedPrevious > 0) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        l10n.format('camera.restrictionsReplaced', {
                          'count': state.replacedPrevious.toString(),
                        }),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // AI Explanation Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(127, 172, 88, 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              color: Color(0xFF7FAC58),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.getString('camera.aiExplanation'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.explanation.trim().isEmpty
                              ? l10n.getString('camera.aiExplanationFallback')
                              : state.explanation.trim(),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Location Info
                  Center(
                    child: Text(
                      '${l10n.getString('camera.locationLabel')}: ${state.latitude.toStringAsFixed(5)}, ${state.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            context.read<CameraBloc>().add(PhotoRetaken());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            l10n.getString('camera.buttonRetake'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            context.read<CameraBloc>().add(CameraClosed());
                            context.read<NavigationCubit>().setIndex(0);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7FAC58),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            l10n.getString('camera.buttonDone'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
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
    return Scaffold(
      backgroundColor: Colors.black,
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
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7FAC58)),
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

          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7FAC58)),
            ),
          );
        },
      ),
    );
  }
}
