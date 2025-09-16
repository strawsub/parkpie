import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:frontend/features/camera/camera_event.dart';
import 'package:frontend/features/camera/camera_state.dart';
import 'package:frontend/features/camera/camera_bloc.dart';
import 'package:frontend/features/navigation/navigation_cubit.dart';

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
    
    // Auto-open camera when navigating to this screen
    if ((currentState is CameraInitial || currentState is CameraCanceled) && !_hasTriggeredCamera) {
      _hasTriggeredCamera = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CameraBloc>().add(CameraOpened());
      });
    }
  }

  Widget _buildCameraPreview(BuildContext context, CameraBloc cameraBloc) {
    final controller = cameraBloc.cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Camera preview
        SizedBox.expand(
          child: CameraPreview(controller),
        ),
        
        // Overlay UI
        Positioned.fill(
          child: Column(
            children: [
              // Header with back button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () {
                        // Cleanup camera and navigate back to map
                        context.read<CameraBloc>().add(CameraClosed());
                        context.read<NavigationCubit>().setIndex(0);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    
                    // Centered title
                    Expanded(
                      child: Text(
                        'TAKE PHOTO OF PARKING SIGN',
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
                    
                    // Spacer to balance the back button
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              
              // Camera viewfinder area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              // Instructions and capture button
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Column(
                  children: [
                    // Instructions
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
                            'Point your camera at the parking sign and capture the full view',
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
                    
                    // Capture button
                    GestureDetector(
                      onTap: () {
                        context.read<CameraBloc>().add(PhotoCaptured());
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7FAC58),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color.fromARGB(255, 255, 255, 255), width: 4),
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
    return Stack(
      children: [
        // Background image
        SizedBox.expand(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        
        // Semi-transparent overlay
        Container(
          color: Colors.black.withValues(alpha: 0.3),
        ),
        
        // Header with back button
        Positioned(
          top: 60,
          left: 20,
          right: 20,
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  // Cleanup camera and navigate back to map
                  context.read<CameraBloc>().add(CameraClosed());
                  context.read<NavigationCubit>().setIndex(0);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              
              // Centered title
              Expanded(
                child: Text(
                  'TAKE PHOTO OF PARKING SIGN',
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
              
              // Spacer to balance the back button
              const SizedBox(width: 40),
            ],
          ),
        ),
        
        // Green checkmark overlay
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF7FAC58),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ],
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<CameraBloc, CameraState>(
        listener: (context, state) {
          if (state is CameraError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is PhotoUploadSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.uploadSuccessful)),
            );
          } else if (state is CameraCanceled) {
            // Reset the trigger flag so camera can be opened again next time
            _hasTriggeredCamera = false;
            // Cleanup camera and navigate back to map screen when camera is canceled
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
          }

          if (state is CameraReady) {
            return _buildCameraPreview(context, context.read<CameraBloc>());
          }

          if (state is PhotoUploading) {
            return _buildProcessingView(state.imagePath);
          }

          // Show OCR result after upload + OCR
          if (state is PhotoOCRSuccess) {
            return Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with back button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
                      color: Colors.grey.shade100,
                      child: Row(
                        children: [
                          // Back button
                          GestureDetector(
                            onTap: () {
                              // Cleanup camera and navigate back to map
                              context.read<CameraBloc>().add(CameraClosed());
                              context.read<NavigationCubit>().setIndex(0);
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),

                          // Centered title
                          Expanded(
                            child: Text(
                              'OCR RESULT',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),

                          // Spacer to balance the back button
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    
                    // Image
                    Image.file(File(state.imagePath)),
                    
                    // OCR Text
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Extracted Text:",
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              state.ocrText,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Retake button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () => context.read<CameraBloc>().add(PhotoRetaken()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7FAC58),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                l10n.retake,
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Initial loading or error state
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