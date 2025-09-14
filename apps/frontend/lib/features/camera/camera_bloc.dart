import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:frontend/features/camera/camera_event.dart';
import 'package:frontend/features/camera/camera_state.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// Khue's API key, use sparingly
const apiKey = "AIzaSyBTF-RFzdOlaveCX-5N6WVA_6UjaJ6KZ9M";

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  late final GenerativeModel _model;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  CameraBloc() : super(CameraInitial()) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
    );

    on<CameraOpened>(_onCameraOpened);
    on<PhotoCaptured>(_onPhotoCaptured);
    on<PhotoRetaken>(_onPhotoRetaken);
    on<PhotoUploaded>(_onPhotoUploaded);
    on<CameraClosed>(_onCameraClosed);
  }

  CameraController? get cameraController => _cameraController;

  @override
  Future<void> close() {
    _cameraController?.dispose();
    return super.close();
  }

  Future<void> _onCameraOpened(CameraOpened event, Emitter<CameraState> emit) async {
    try {
      emit(CameraLoading());

      // Initialize cameras - this will automatically request permissions if needed
      try {
        _cameras ??= await availableCameras();
      } catch (e) {
        // Handle permission and camera access errors
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('permission') || errorMessage.contains('denied')) {
          emit(CameraError("Please grant camera permission to use this feature"));
        } else {
          emit(CameraError("Failed to access camera: ${e.toString()}"));
        }
        return;
      }
      
      if (_cameras == null || _cameras!.isEmpty) {
        emit(CameraError("No cameras available on this device"));
        return;
      }

      // Find back camera
      CameraDescription? backCamera;
      try {
        backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
      } catch (e) {
        // If no back camera found, use the first available camera
        if (_cameras!.isNotEmpty) {
          backCamera = _cameras!.first;
        } else {
          emit(CameraError("No suitable camera found"));
          return;
        }
      }

      // Dispose existing controller if any
      await _cameraController?.dispose();

      // Initialize camera controller
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false, // Disable audio for photo capture
      );

      try {
        await _cameraController!.initialize();
        
        // Double check initialization was successful
        if (!_cameraController!.value.isInitialized) {
          emit(CameraError("Camera initialization failed"));
          return;
        }
        
        emit(CameraReady());
      } catch (e) {
        // Handle camera initialization errors, including permissions
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('permission') || errorMessage.contains('denied')) {
          emit(CameraError("Please grant camera permission to use this feature"));
        } else {
          emit(CameraError("Camera initialization error: ${e.toString()}"));
        }
      }
    } catch (e) {
      emit(CameraError("Camera setup failed: ${e.toString()}"));
    }
  }

  Future<void> _onPhotoCaptured(PhotoCaptured event, Emitter<CameraState> emit) async {
    try {
      if (_cameraController == null) {
        emit(CameraError("Camera controller not available"));
        return;
      }
      
      if (!_cameraController!.value.isInitialized) {
        emit(CameraError("Camera not initialized"));
        return;
      }

      if (_cameraController!.value.isTakingPicture) {
        // Already taking a picture, ignore this request
        return;
      }

      emit(CameraLoading());
      
      try {
        final XFile image = await _cameraController!.takePicture();
        add(PhotoUploaded(image.path));
      } catch (e) {
        emit(CameraError("Failed to capture photo: ${e.toString()}"));
      }
    } catch (e) {
      emit(CameraError("Photo capture error: ${e.toString()}"));
    }
  }

  void _onPhotoRetaken(PhotoRetaken event, Emitter<CameraState> emit) async {
    // Reset to camera ready state instead of reopening camera
    emit(CameraReady());
  }

  Future<void> _onPhotoUploaded(PhotoUploaded event, Emitter<CameraState> emit) async {
    try {
      emit(PhotoUploading(event.imagePath));

      final file = File(event.imagePath);
      final bytes = await file.readAsBytes();

      // Send image + prompt to Gemini
      final response = await _model.generateContent([
        Content.multi([
          TextPart("Extract all the readable text from this parking sign image."),
          DataPart('image/jpeg', bytes),
        ])
      ]);

      final ocrText = response.text ?? "";

      if (ocrText.isEmpty) {
        emit(CameraError("OCR returned no text"));
        return;
      }

      // Parse OCR into structured fields
      final databaseEntry = _parseOcrTextToFields(ocrText);

      // Emit success state
      emit(PhotoOCRSuccess(
        imagePath: event.imagePath,
        ocrText: ocrText,
        databaseEntry: databaseEntry,
      ));
    } catch (e) {
      emit(CameraError("Gemini OCR failed: $e"));
    }
  }

  void _onCameraClosed(CameraClosed event, Emitter<CameraState> emit) {
    // Cleanup camera resources
    _cameraController?.dispose();
    _cameraController = null;
    _cameras = null;
    emit(CameraInitial());
  }

  // Helper to extract structured fields
  Map<String, dynamic> _parseOcrTextToFields(String text) {
    final maxHoursMatch = RegExp(r"Maximum Hours:\s*(\d+)").firstMatch(text);
    final dayOfWeekMatch = RegExp(r"Day of Week:\s*(\w+)").firstMatch(text);
    final startTimeMatch = RegExp(r"Start Time:\s*([\d:APM]+)").firstMatch(text);

    return {
      "maximum_hours_restriction": maxHoursMatch?.group(1) ?? "",
      "day_of_week": dayOfWeekMatch?.group(1) ?? "",
      "start_time": startTimeMatch?.group(1) ?? "",
    };
  }
}