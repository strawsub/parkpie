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
