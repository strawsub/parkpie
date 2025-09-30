import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/navigation/navigation_cubit.dart';
import 'features/navigation/filter_trigger_cubit.dart';

import 'features/map/map_screen.dart';
import 'features/map/pin/pin_cubit.dart';
import 'features/map/search/search_cubit.dart';
import 'features/gps_correction/location_bloc.dart'; 

import 'features/camera/camera_screen.dart';
import 'features/camera/camera_bloc.dart';

import 'features/parking_status_detection/parking_status_bloc.dart';
import 'features/parking_status_detection/parking_status_state.dart';
import 'features/parking_status_detection/parking_status_event.dart';
import 'features/parking_status_detection/gyroscope/gyro_bloc.dart';
import 'features/parking_status_detection/bluetooth/bluetooth_bloc.dart';
import 'features/parking_status_detection/accelerometer/acc_bloc.dart';

import 'l10n/app_localizations.dart';
import 'widgets/nav_bar.dart';

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
    final parkingBloc = ParkingBloc(
      accBloc: accBloc,
      gyroBloc: gyroBloc,
      bluetoothBloc: bluetoothBloc,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NavigationCubit()),
        BlocProvider(create: (_) => FilterTriggerCubit()),
        BlocProvider(create: (_) => CameraBloc()),
        BlocProvider(create: (_) => PinCubit()..loadPins()),
        BlocProvider<SearchCubit>(create: (context) => SearchCubit()),
        BlocProvider<AccBloc>.value(value: accBloc),
        BlocProvider<GyroBloc>.value(value: gyroBloc),
        BlocProvider<BluetoothBloc>.value(value: bluetoothBloc),
        BlocProvider<ParkingBloc>.value(value: parkingBloc),
        BlocProvider(create: (_) => LocationCubit(),),

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

  void _handleNavTap(BuildContext context, int index, int currentIndex) {
    if (index == 2) {
      // Filter tapped - stay on parking screen (index 0) and trigger filter
      if (currentIndex != 0) {
        context.read<NavigationCubit>().setIndex(0);
      }
      // Trigger the filter sheet
      context.read<FilterTriggerCubit>().triggerFilter();
    } else {
      // Regular navigation
      context.read<NavigationCubit>().setIndex(index);
    }
  }

  Widget _getSelectedView(int index) {
    switch (index) {
      case 0:
        return MapScreen();
      case 1:
        return const CameraScreen();
      case 2:
        return MapScreen(); // Filter shows MapScreen but triggers filter sheet
      default:
        return MapScreen(); // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ParkingBloc, ParkingState>(
      listener: (context, state) {
        if (state is ParkingDetected) {
          _showParkingDialog(context);
        }
      },
      child: BlocBuilder<NavigationCubit, int>(
        builder: (context, selectedIndex) {
          return Scaffold(
            body: Stack(
              children: [
                // Full-screen content
                _getSelectedView(selectedIndex),
                // Floating navigation bar (hidden when camera is active)
                if (selectedIndex != 1)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: BottomNavBar(
                      currentIndex: selectedIndex,
                      onTap: (index) => _handleNavTap(context, index, selectedIndex),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showParkingDialog(BuildContext context) {
    final parentContext = context;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Are you parked?"),
        content: const Text("It looks like you might be parked."),
        actions: [
          TextButton(
            onPressed: () {
              parentContext.read<ParkingBloc>().add(UserConfirmedParking());
              Navigator.of(parentContext).pop();
            },
            child: const Text("Yes"),
          ),
          TextButton(
            onPressed: () {
              parentContext.read<ParkingBloc>().add(ResetParking());
              Navigator.of(parentContext).pop();
            },
            child: const Text("No"),
          ),
        ],
      ),
    );
  }
}
