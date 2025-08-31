import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:frontend/features/camera/camera_event.dart';
import 'package:frontend/features/camera/camera_state.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// Khue's API key, use sparingly
const apiKey = "AIzaSyBTF-RFzdOlaveCX-5N6WVA_6UjaJ6KZ9M";

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  final ImagePicker _picker = ImagePicker();
  late final GenerativeModel _model;

  CameraBloc() : super(CameraInitial()) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
    );

    on<CameraOpened>(_onCameraOpened);
    on<PhotoCaptured>(_onPhotoCaptured);
    on<PhotoRetaken>(_onPhotoRetaken);
    on<PhotoUploaded>(_onPhotoUploaded);
  }

  Future<void> _onCameraOpened(CameraOpened event, Emitter<CameraState> emit) async {
    try {
      emit(CameraLoading());

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        emit(PhotoCapturedSuccess(image.path));
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