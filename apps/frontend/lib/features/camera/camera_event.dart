abstract class CameraEvent {}

class CameraOpened extends CameraEvent {}

class PhotoCaptured extends CameraEvent {}

class PhotoRetaken extends CameraEvent {}

class PhotoUploaded extends CameraEvent {
  final String imagePath;
  PhotoUploaded(this.imagePath); 
}

class CameraClosed extends CameraEvent {}
