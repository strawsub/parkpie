import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/camera/camera_event.dart';
import 'package:frontend/features/camera/camera_state.dart';
import 'package:frontend/features/camera/sign_restriction.dart';
import 'package:frontend/services/gps_correction/location_cubit.dart';
import 'package:frontend/services/api_config.dart';
import 'package:frontend/services/sign_ingest_service.dart';
import 'package:frontend/services/sign_zone_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// TODO: Replace with secure runtime configuration
const apiKey = "AIzaSyBTF-RFzdOlaveCX-5N6WVA_6UjaJ6KZ9M";

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  final GenerativeModel _ocrModel;
  final SignIngestService _signService;
  final SignZoneStorage _zoneStorage;
  final LocationCubit _locationCubit;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  CameraBloc({
    required LocationCubit locationCubit,
    GenerativeModel? ocrModel,
    SignIngestService? signIngestService,
    SignZoneStorage? zoneStorage,
  }) : _ocrModel =
           ocrModel ??
           GenerativeModel(model: 'gemini-2.5-flash-lite', apiKey: apiKey),
       _signService =
           signIngestService ??
           SignIngestService(backendBaseUrl: resolveApiBaseUrl()),
       _zoneStorage = zoneStorage ?? SignZoneStorage(),
       _locationCubit = locationCubit,
       super(CameraInitial()) {
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
    _locationCubit.stopTracking();
    return super.close();
  }

  Future<void> _onCameraOpened(
    CameraOpened event,
    Emitter<CameraState> emit,
  ) async {
    try {
      await _locationCubit.startTracking();
      emit(CameraLoading());

      try {
        _cameras ??= await availableCameras();
      } catch (e) {
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('permission') ||
            errorMessage.contains('denied')) {
          emit(
            CameraError("Please grant camera permission to use this feature"),
          );
        } else {
          emit(CameraError("Failed to access camera: ${e.toString()}"));
        }
        return;
      }

      if (_cameras == null || _cameras!.isEmpty) {
        emit(CameraError("No cameras available on this device"));
        return;
      }

      CameraDescription? backCamera;
      try {
        backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
      } catch (_) {
        if (_cameras!.isNotEmpty) {
          backCamera = _cameras!.first;
        } else {
          emit(CameraError("No suitable camera found"));
          return;
        }
      }

      await _cameraController?.dispose();
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false,
      );

      try {
        await _cameraController!.initialize();
        if (!_cameraController!.value.isInitialized) {
          emit(CameraError("Camera initialization failed"));
          return;
        }
        emit(CameraReady());
      } catch (e) {
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('permission') ||
            errorMessage.contains('denied')) {
          emit(
            CameraError("Please grant camera permission to use this feature"),
          );
        } else {
          emit(CameraError("Camera initialization error: ${e.toString()}"));
        }
      }
    } catch (e) {
      emit(CameraError("Camera setup failed: ${e.toString()}"));
    }
  }

  Future<void> _onPhotoCaptured(
    PhotoCaptured event,
    Emitter<CameraState> emit,
  ) async {
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
        return;
      }

      emit(CameraLoading());
      try {
        final XFile image = await _cameraController!.takePicture();
        add(
          PhotoUploaded(
            imagePath: image.path,
            locale: event.locale,
            capturedAt: event.capturedAt,
          ),
        );
      } catch (e) {
        emit(CameraError("Failed to capture photo: ${e.toString()}"));
      }
    } catch (e) {
      emit(CameraError("Photo capture error: ${e.toString()}"));
    }
  }

  void _onPhotoRetaken(PhotoRetaken event, Emitter<CameraState> emit) {
    emit(CameraReady());
  }

  Future<void> _onPhotoUploaded(
    PhotoUploaded event,
    Emitter<CameraState> emit,
  ) async {
    try {
      emit(PhotoUploading(event.imagePath));

      final file = File(event.imagePath);
      final bytes = await file.readAsBytes();

      final ocrResponse = await _ocrModel.generateContent([
        Content.multi([
          TextPart(
            "Extract all the readable text from this parking sign image.",
          ),
          DataPart('image/jpeg', bytes),
        ]),
      ]);

      final rawText = (ocrResponse.text ?? '').trim();
      if (rawText.isEmpty) {
        emit(CameraError("AI returned no text for this sign"));
        return;
      }

      final position = await _obtainPosition();
      final filteredPosition = _locationCubit.state.filteredPosition;
      final latitude = filteredPosition != null && filteredPosition.length >= 2
          ? filteredPosition[0]
          : position.latitude;
      final longitude = filteredPosition != null && filteredPosition.length >= 2
          ? filteredPosition[1]
          : position.longitude;

      final parsed = await _signService.extractSignJson(
        signText: rawText,
        lat: latitude,
        lng: longitude,
        apiKey: apiKey,
      );

      try {
        _signService.validatePayload(parsed);
      } catch (validationError) {
        emit(
          CameraError("Sign validation failed: ${validationError.toString()}"),
        );
        return;
      }

      final restrictionMaps = (parsed['restrictions'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final restrictions = restrictionMaps
          .map((e) => SignRestriction.fromJson(e))
          .toList(growable: false);

      final fingerprint = _fingerprint(latitude, longitude, restrictions);
      final cachedZone = await _zoneStorage.readZone(fingerprint);

      final payload = Map<String, dynamic>.from(parsed)
        ..['location'] = {'lat': latitude, 'lng': longitude};
      if (cachedZone != null) {
        payload['zone_number'] = cachedZone;
      }

      final ingestResult = await _signService.sendToBackend(payload);
      await _zoneStorage.writeZone(fingerprint, ingestResult.zoneNumber);

      String explanation = '';
      try {
        explanation = await _signService.generateExplanation(
          restrictions: restrictionMaps,
          lat: latitude,
          lng: longitude,
          rawText: rawText,
          apiKey: apiKey,
          localeTag: _localeTag(event.locale),
          capturedAt: event.capturedAt.toLocal(),
        );
      } catch (_) {
        explanation = '';
      }

      emit(
        SignAnalysisSuccess(
          imagePath: event.imagePath,
          rawText: rawText,
          explanation: explanation,
          restrictions: restrictions,
          zoneNumber: ingestResult.zoneNumber,
          restrictionsSaved: ingestResult.restrictionsSaved,
          replacedPrevious: ingestResult.replacedPrevious,
          latitude: latitude,
          longitude: longitude,
        ),
      );
    } catch (e) {
      emit(CameraError("Sign analysis failed"));
    }
  }

  void _onCameraClosed(CameraClosed event, Emitter<CameraState> emit) {
    _cameraController?.dispose();
    _cameraController = null;
    _cameras = null;
    _locationCubit.stopTracking();
    emit(CameraInitial());
  }

  Future<Position> _obtainPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
  }

  String _fingerprint(
    double lat,
    double lng,
    List<SignRestriction> restrictions,
  ) {
    final sorted = [...restrictions]
      ..sort((a, b) {
        final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (dayCompare != 0) return dayCompare;
        final startCompare = a.startTime.compareTo(b.startTime);
        if (startCompare != 0) return startCompare;
        return a.endTime.compareTo(b.endTime);
      });

    final buffer = StringBuffer()
      ..write(lat.toStringAsFixed(5))
      ..write('|')
      ..write(lng.toStringAsFixed(5));
    for (final r in sorted) {
      buffer
        ..write('|')
        ..write(r.dayOfWeek)
        ..write('-')
        ..write(r.startTime)
        ..write('-')
        ..write(r.endTime)
        ..write('-')
        ..write(r.maximumStayMinutes?.toString() ?? 'null');
    }

    return sha1.convert(utf8.encode(buffer.toString())).toString();
  }

  String _localeTag(Locale locale) {
    final language = locale.languageCode;
    final script = locale.scriptCode;
    final country = locale.countryCode;
    final buffer = StringBuffer(language);
    if (script != null && script.isNotEmpty) {
      buffer
        ..write('-')
        ..write(script);
    }
    if (country != null && country.isNotEmpty) {
      buffer
        ..write('-')
        ..write(country);
    }
    return buffer.toString();
  }
}
