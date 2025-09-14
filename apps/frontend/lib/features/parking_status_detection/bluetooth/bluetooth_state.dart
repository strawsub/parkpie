import 'package:equatable/equatable.dart';
import '../utils.dart';

abstract class BluetoothState extends Equatable {
  final SensorVote vote;
  final bool isConnected;
  final String? deviceName;

  const BluetoothState({
    required this.vote,
    required this.isConnected,
    this.deviceName,
  });

  @override
  List<Object?> get props => [vote, isConnected, deviceName];
}

class BluetoothInitial extends BluetoothState {
  const BluetoothInitial()
      : super(
          vote: SensorVote.unknown,
          isConnected: false,
        );
}

class BluetoothConnectionStatus extends BluetoothState {
  final bool wasConnected;

  const BluetoothConnectionStatus({
    required super.vote,
    required super.isConnected,
    required this.wasConnected,
    super.deviceName,
  });

  @override
  List<Object?> get props => [vote, isConnected, wasConnected, deviceName];
}