import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
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
            // Navigate back to map screen when camera is canceled
            context.read<NavigationCubit>().setIndex(0);
          }
        },
        builder: (context, state) {
          if (state is CameraLoading || state is PhotoUploading) {
            return const Center(child: CircularProgressIndicator());
          }


          // Show OCR result after upload + OCR
          if (state is PhotoOCRSuccess) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.file(File(state.imagePath)),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "OCR Text:",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.ocrText, // show OCR text directly
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () => context.read<CameraBloc>().add(PhotoRetaken()),
                      child: Text(l10n.retake),
                    ),
                  ),
                ],
              ),
            );
          }

          // Auto-opening camera, show loading while waiting
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}