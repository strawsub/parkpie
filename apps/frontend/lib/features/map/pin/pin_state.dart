// pin_state.dart
import 'package:frontend/features/map/pin/pin_model.dart';

abstract class PinState {}

class PinInitial extends PinState {}

class PinLoading extends PinState {}

class PinLoaded extends PinState {
  final List<Pin> pins;
  PinLoaded(this.pins);
}

class PinError extends PinState {
  final String message;
  PinError(this.message);
}