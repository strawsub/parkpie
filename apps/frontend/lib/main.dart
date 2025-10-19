import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/navigation/navigation_cubit.dart';
import 'features/navigation/filter_trigger_cubit.dart';

import 'features/map/map_screen.dart';
import 'features/map/pin/pin_cubit.dart';
import 'features/map/search/search_cubit.dart';

import 'features/camera/camera_screen.dart';
import 'features/camera/camera_bloc.dart';
import 'features/gps_correction/location_cubit.dart';

import 'features/timer/timer_screen.dart';
import 'features/timer/timer_bloc.dart';
import 'features/timer/timer_event.dart';

import 'features/parking_status_detection/parking_status_bloc.dart';
import 'features/parking_status_detection/parking_status_state.dart';
import 'features/parking_status_detection/parking_status_event.dart';
import 'features/parking_status_detection/utils.dart';
import 'features/parking_status_detection/gyroscope/gyro_bloc.dart';
import 'features/parking_status_detection/bluetooth/bluetooth_bloc.dart';
import 'features/parking_status_detection/bluetooth/bluetooth_event.dart';
import 'features/parking_status_detection/accelerometer/acc_bloc.dart';
import 'features/parking_status_detection/gps/gps_speed_bloc.dart';

import 'l10n/app_localizations.dart';
import 'widgets/nav_bar.dart';
import 'widgets/parking_detected_bottom_sheet.dart';
import 'services/timer_service.dart';
import 'services/api_config.dart';

void main() {
  runApp(const ParkPieApp());
}

class ParkPieApp extends StatelessWidget {
  const ParkPieApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accBloc = AccBloc();
    final gyroBloc = GyroBloc();
    final bluetoothBloc = BluetoothBloc();
    final gpsSpeedBloc = GpsSpeedBloc();
    final parkingBloc = ParkingBloc(
      accBloc: accBloc,
      gyroBloc: gyroBloc,
      bluetoothBloc: bluetoothBloc,
      gpsSpeedBloc: gpsSpeedBloc,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NavigationCubit()),
        BlocProvider(create: (_) => FilterTriggerCubit()),
        BlocProvider(create: (_) => LocationCubit()),
        BlocProvider(
          create: (context) =>
              CameraBloc(locationCubit: context.read<LocationCubit>()),
        ),
        BlocProvider(create: (_) => PinCubit()..loadPins()),
        BlocProvider<SearchCubit>(create: (context) => SearchCubit()),
        BlocProvider<AccBloc>.value(value: accBloc),
        BlocProvider<GyroBloc>.value(value: gyroBloc),
        BlocProvider<BluetoothBloc>.value(value: bluetoothBloc),
        BlocProvider<GpsSpeedBloc>.value(value: gpsSpeedBloc),
        BlocProvider<ParkingBloc>.value(value: parkingBloc),
        BlocProvider(
          create: (context) =>
              TimerBloc(locationCubit: context.read<LocationCubit>())
                ..add(const LoadTimer()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const HomeContainer(),
      ),
    );
  }
}

class HomeContainer extends StatefulWidget {
  const HomeContainer({super.key});

  @override
  State<HomeContainer> createState() => _HomeContainerState();
}

class _HomeContainerState extends State<HomeContainer> {
  bool _isParkingDialogShowing = false;

  void _handleNavTap(BuildContext context, int index, int currentIndex) {
    // Regular navigation for all tabs
    context.read<NavigationCubit>().setIndex(index);
  }

  Widget _getSelectedView(int index) {
    switch (index) {
      case 0:
        return MapScreen();
      case 1:
        return const CameraScreen();
      case 2:
        return const TimerScreen();
      default:
        return MapScreen(); // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ParkingBloc, ParkingState>(
      listener: (context, state) {
        if (state is ParkingDetected && !_isParkingDialogShowing) {
          _showParkingDialog(context);
        }

        if (state is Parked) {
          context.read<TimerBloc>().add(const StartTimer());
          context.read<NavigationCubit>().setIndex(2);
        }
      },
      child: BlocBuilder<NavigationCubit, int>(
        builder: (context, selectedIndex) {
          return Scaffold(
            body: _getSelectedView(selectedIndex),
            bottomNavigationBar: selectedIndex != 1
                ? BottomNavBar(
                    currentIndex: selectedIndex,
                    onTap: (index) =>
                        _handleNavTap(context, index, selectedIndex),
                  )
                : null, // Hide nav bar on camera screen
          );
        },
      ),
    );
  }

  void _showParkingDialog(BuildContext context) {
    final parentContext = context;
    final parkingBloc = context.read<ParkingBloc>();
    final bluetoothBloc = context.read<BluetoothBloc>();
    final timerService = TimerService(backendBaseUrl: resolveApiBaseUrl());
    _isParkingDialogShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParkingDetectedBottomSheet(
        timerService: timerService,
        onConfirm: (selectedMinutes, selectedZone) {
          _isParkingDialogShowing = false;
          Navigator.of(parentContext).pop();
          parkingBloc.add(const UserConfirmedParking());

          // If user manually overrode duration, use that (manual override takes priority)
          if (selectedMinutes != null) {
            parentContext.read<TimerBloc>().add(
              UpdateRestrictionDuration(selectedMinutes),
            );
            // Store zone info only for display purposes, but don't use its time limit
            if (selectedZone != null) {
              parentContext.read<TimerBloc>().add(
                SetKnownZone(
                  zoneNumber: selectedZone.zoneNumber,
                  zoneName: selectedZone.zoneName ?? selectedZone.zoneId,
                ),
              );
            }
          }
          // Otherwise, use zone's restriction and store zone info
          else if (selectedZone != null) {
            if (selectedZone.maximumStayMinutes != null && selectedZone.maximumStayMinutes! > 0) {
              // Zone has a time limit - use it
              parentContext.read<TimerBloc>().add(
                UpdateRestrictionDuration(selectedZone.maximumStayMinutes!),
              );
            } else {
              // Zone has NO time limit - use -1 to indicate "no restriction" (different from null)
              parentContext.read<TimerBloc>().add(
                UpdateRestrictionDuration(-1),
              );
            }
            parentContext.read<TimerBloc>().add(
              SetKnownZone(
                zoneNumber: selectedZone.zoneNumber,
                zoneName: selectedZone.zoneName ?? selectedZone.zoneId,
              ),
            );
          }

          // Start the timer
          parentContext.read<TimerBloc>().add(const StartTimer());

          // Navigate to timer screen
          parentContext.read<NavigationCubit>().setIndex(2);
        },
        onCancel: () {
          _isParkingDialogShowing = false;
          Navigator.of(parentContext).pop();
          // Only reset Bluetooth if it was the trigger (bluetooth vote = parked)
          final btVote = parkingBloc.state.sensorVotes['bluetooth'];
          if (btVote == SensorVote.parked) {
            bluetoothBloc.add(const ResetBluetooth());
          }
          // Revert to Driving state
          parkingBloc.add(const RevertToDriving());
        },
      ),
    ).then((_) {
      if (!mounted) return;
      // Handle dismissal by swipe down (or any other dismissal method)
      _isParkingDialogShowing = false;
      // Revert to Driving state if dialog was dismissed without confirming
      if (parkingBloc.state is ParkingDetected) {
        // Only reset Bluetooth if it was the trigger (bluetooth vote = parked)
        final btVote = parkingBloc.state.sensorVotes['bluetooth'];
        if (btVote == SensorVote.parked) {
          bluetoothBloc.add(const ResetBluetooth());
        }
        parkingBloc.add(const RevertToDriving());
      }
    });
  }
}
