import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:frontend/features/camera/camera_event.dart';
import 'package:frontend/features/camera/camera_state.dart';

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  final ImagePicker _picker = ImagePicker();
  
  CameraBloc() : super(CameraInitial()) {
    on<CameraOpened>(_onCameraOpened);
    on<PhotoCaptured>(_onPhotoCaptured);
    on<PhotoRetaken>(_onPhotoRetaken);
    on<PhotoUploaded>(_onPhotoUploaded);

    // Auto-Trgger camera openings:
    add(CameraOpened());
  }

  Future<void> _onCameraOpened(CameraOpened event, Emitter<CameraState> emit) async {
    try {
      emit(CameraLoading());
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image != null) {
        // Skip flutter preview, go directly to upload
        add(PhotoUploaded(image.path));
      } else {
        emit(CameraInitial());
      }
    } catch (e) {
      emit(CameraError(e.toString()));
    }
  }

  void _onPhotoCaptured(PhotoCaptured event, Emitter<CameraState> emit) {
    emit(PhotoCapturedSuccess(event.imagePath));
  }

  void _onPhotoRetaken(PhotoRetaken event, Emitter<CameraState> emit) {
    add(CameraOpened());
  }

  Future<void> _onPhotoUploaded(PhotoUploaded event, Emitter<CameraState> emit) async {
    try {
      emit(PhotoUploading());
      
      final file = File(event.imagePath);
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      final url = Uri.parse(
        "https://parkpie.blob.core.windows.net/sign-photo-container/$fileName"
        "?sp=rac&st=2025-08-21T03:30:32Z&se=2025-12-21T10:45:32Z&spr=https&sv=2024-11-04&sr=c&sig=1UreYplNAKWeImXjTxXJ1OTSAlRQ3lO2kVHWEaHhpkE%3D",
      );

      final bytes = await file.readAsBytes();
      final response = await http.put(
        url,
        headers: {
          "x-ms-blob-type": "BlockBlob",
          "Content-Type": "image/jpeg", 
        },
        body: bytes,
      );

      if (response.statusCode == 201) {
        emit(PhotoUploadSuccess());
        await Future.delayed(const Duration(seconds: 1));
        emit(CameraInitial());
      } else {
        emit(CameraError('Upload failed with status ${response.statusCode}'));
      }
    } catch (e) {
      emit(CameraError(e.toString()));
    }
  }
}

