import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/camera/camera_event.dart';
import 'package:frontend/features/camera/camera_state.dart';
import 'package:frontend/features/camera/camera_bloc.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CameraBloc(),
      child: const CameraView(),
    );
  }
}

class CameraView extends StatelessWidget {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contribute),
        backgroundColor: Colors.blue,
      ),
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
          }
        },
        builder: (context, state) {
          if (state is CameraLoading || state is PhotoUploading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PhotoCapturedSuccess) {
            return Column(
              children: [
                Expanded(
                  child: Image.file(File(state.imagePath)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => context.read<CameraBloc>().add(PhotoRetaken()),
                        child: Text(l10n.retake),
                      ),
                      ElevatedButton(
                        onPressed: () => context.read<CameraBloc>().add(
                          PhotoUploaded(state.imagePath)
                        ),
                        child: Text(l10n.useThisPhoto),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.noPhotoCaptured),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<CameraBloc>().add(CameraOpened()),
                  child: Text(l10n.takePhoto),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}