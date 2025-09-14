import 'package:equatable/equatable.dart';

abstract class BluetoothEvent extends Equatable {
  const BluetoothEvent();

  @override
  List<Object?> get props => [];
}

class BluetoothStatusChanged extends BluetoothEvent {
  final bool isConnected;
  final String? deviceName;

  const BluetoothStatusChanged({
    required this.isConnected,
    this.deviceName,
  });

  @override
  List<Object?> get props => [isConnected, deviceName];
}

class InitializeBluetooth extends BluetoothEvent {
  const InitializeBluetooth();
}

class ResetBluetooth extends BluetoothEvent {
  const ResetBluetooth();
}