abstract class CameraState {}

class CameraInitial extends CameraState {}

class CameraLoading extends CameraState {}

class PhotoCapturedSuccess extends CameraState { 
  final String imagePath;
  PhotoCapturedSuccess(this.imagePath);
}

class PhotoUploading extends CameraState {}

class PhotoUploadSuccess extends CameraState {}

class CameraError extends CameraState {
  final String message;
  CameraError(this.message);
}

class PhotoOCRSuccess extends CameraState {
  final String imagePath;
  final String ocrText;
  final Map<String, dynamic> databaseEntry; // Map instead of String

  PhotoOCRSuccess({
    required this.imagePath,
    required this.ocrText,
    required this.databaseEntry,
  });
}
