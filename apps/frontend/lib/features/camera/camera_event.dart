abstract class CameraEvent {}

class CameraOpened extends CameraEvent {}

class PhotoCaptured extends CameraEvent {
  final String imagePath;
  PhotoCaptured(this.imagePath);
}

class PhotoRetaken extends CameraEvent {}

class PhotoUploaded extends CameraEvent {
  final String imagePath;
  PhotoUploaded(this.imagePath); 
}
