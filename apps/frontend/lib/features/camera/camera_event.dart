import 'dart:ui';

abstract class CameraEvent {}

class CameraOpened extends CameraEvent {}

class PhotoCaptured extends CameraEvent {
  PhotoCaptured({required this.locale, required this.capturedAt});

  final Locale locale;
  final DateTime capturedAt;
}

class PhotoRetaken extends CameraEvent {}

class PhotoUploaded extends CameraEvent {
  PhotoUploaded({
    required this.imagePath,
    required this.locale,
    required this.capturedAt,
  });

  final String imagePath;
  final Locale locale;
  final DateTime capturedAt;
}

class CameraClosed extends CameraEvent {}
