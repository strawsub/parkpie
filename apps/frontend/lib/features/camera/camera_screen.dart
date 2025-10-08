import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:frontend/features/camera/camera_bloc.dart';
import 'package:frontend/features/camera/camera_event.dart';
import 'package:frontend/features/camera/camera_state.dart';
import 'package:frontend/features/camera/sign_restriction.dart';
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
                    // Back button
                    GestureDetector(
                      onTap: () {
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
    return Stack(
      children: [
        SizedBox.expand(child: Image.file(File(imagePath), fit: BoxFit.cover)),
        Container(color: Colors.black.withValues(alpha: 0.35)),
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
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
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
              const Text(
                'Analyzing parking sign...',
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
                  'Extracting text, summarising the rules and syncing with ParkPie.',
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

  Widget _buildAnalysisResultsView(SignAnalysisSuccess state) {
    final restrictions = state.restrictions;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () {
            context.read<CameraBloc>().add(CameraClosed());
            context.read<NavigationCubit>().setIndex(0);
          },
        ),
        title: const Text(
          'Sign Summary',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            _buildZoneInfoCard(state),
            const SizedBox(height: 16),
            _buildExplanationCard(state),
            const SizedBox(height: 20),
            const Text(
              'Restrictions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            if (restrictions.isEmpty)
              const Text('No restrictions found for this sign.'),
            for (final r in restrictions) _buildRestrictionTile(context, r),
            const SizedBox(height: 20),
            _buildRawTextSection(state.rawText),
            const SizedBox(height: 30),
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
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Retake Photo'),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Manual zone ${state.zoneNumber} saved to ParkPie.',
                          ),
                        ),
                      );
                      context.read<CameraBloc>().add(CameraClosed());
                      context.read<NavigationCubit>().setIndex(0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7FAC58),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneInfoCard(SignAnalysisSuccess state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFE7F2D9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual zone ${state.zoneNumber}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3D5A24),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  Icons.storage,
                  '${state.restrictionsSaved} window(s) synced',
                ),
                if (state.replacedPrevious > 0)
                  _buildInfoChip(
                    Icons.refresh,
                    '${state.replacedPrevious} old window(s) replaced',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Location: ${state.latitude.toStringAsFixed(5)}, ${state.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard(SignAnalysisSuccess state) {
    final text = state.explanation.trim().isEmpty
        ? 'Gemini could not summarise this sign. Please review the restrictions below.'
        : state.explanation.trim();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.lightbulb_outline, color: Color(0xFF7FAC58)),
                SizedBox(width: 8),
                Text(
                  'Gemini explanation',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB7D3A6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7FAC58)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Color(0xFF3D5A24), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictionTile(
    BuildContext context,
    SignRestriction restriction,
  ) {
    final start = _formatTime(context, restriction.startTime);
    final end = _formatTime(context, restriction.endTime);
    final stay = _formatStayDuration(restriction.maximumStayMinutes);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF7FAC58).withValues(alpha: 0.2),
          child: Text(
            restriction.dayLabel.substring(0, 3).toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF3D5A24),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          restriction.dayLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$start - $end'),
              const SizedBox(height: 4),
              Text(stay),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRawTextSection(String rawText) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: const Text(
          'Extracted text',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                rawText.isEmpty ? 'No text available.' : rawText,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final time = TimeOfDay(hour: hour, minute: minute);
    return time.format(context);
  }

  String _formatStayDuration(int? minutes) {
    if (minutes == null) {
      return 'No maximum stay stated';
    }
    if (minutes <= 0) {
      return 'No maximum stay stated';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return hours == 1 ? '1 hour maximum stay' : '$hours hours maximum stay';
    }
    if (hours == 0) {
      return '$minutes minutes maximum stay';
    }
    return '$hours h $mins m maximum stay';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<CameraBloc, CameraState>(
        listener: (context, state) {
          if (state is CameraError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is SignAnalysisSuccess) {
            final replaced = state.replacedPrevious;
            final message = replaced > 0
                ? 'Updated zone ${state.zoneNumber} ($replaced window(s) replaced).'
                : 'Stored zone ${state.zoneNumber} with ${state.restrictionsSaved} window(s).';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
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
