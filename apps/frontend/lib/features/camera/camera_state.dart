import 'package:frontend/features/camera/sign_restriction.dart';

abstract class CameraState {}

class CameraInitial extends CameraState {}

class CameraLoading extends CameraState {}

class CameraReady extends CameraState {}

class PhotoCapturedSuccess extends CameraState {
  final String imagePath;
  PhotoCapturedSuccess(this.imagePath);
}

class PhotoUploading extends CameraState {
  final String imagePath;
  PhotoUploading(this.imagePath);
}

class PhotoUploadSuccess extends CameraState {}

class CameraCanceled extends CameraState {}

class CameraError extends CameraState {
  final String message;
  CameraError(this.message);
}

class SignAnalysisSuccess extends CameraState {
  final String imagePath;
  final String rawText;
  final String explanation;
  final List<SignRestriction> restrictions;
  final int zoneNumber;
  final int restrictionsSaved;
  final int replacedPrevious;
  final double latitude;
  final double longitude;

  SignAnalysisSuccess({
    required this.imagePath,
    required this.rawText,
    required this.explanation,
    required this.restrictions,
    required this.zoneNumber,
    required this.restrictionsSaved,
    required this.replacedPrevious,
    required this.latitude,
    required this.longitude,
  });
}
