import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/camera/camera_screen.dart';
import 'features/camera/camera_bloc.dart';
import 'features/map/map_screen.dart';
import 'features/navigation/navigation_cubit.dart';
import 'features/map/pin/pin_cubit.dart';
import 'features/parking_status_detected/parking_status_bloc.dart';
import 'features/parking_status_detected/parking_status_state.dart';
import 'features/parking_status_detected/parking_status_event.dart';
import 'l10n/app_localizations.dart';
import 'widgets/nav_bar.dart';

void main() {
  runApp(const ParkPieApp());
}

class ParkPieApp extends StatelessWidget {
  const ParkPieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => NavigationCubit()),
          BlocProvider(create: (_) => CameraBloc()),
          BlocProvider(create: (_) => PinCubit()..loadPins()),
          BlocProvider(create: (_) => ParkingBloc()),
        ],
        child: const HomeContainer(),
      ),
    );
  }
}

class HomeContainer extends StatelessWidget {
  const HomeContainer({super.key});

  Widget _getSelectedView(int index) {
    switch (index) {
      case 0:
        return MapScreen();
      case 1:
        return const CameraScreen();
      default:
        return MapScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ParkingBloc, ParkingState>(
      listener: (context, state) {
        if (state is ParkingDetectedState) {
          _showParkingDialog(context);
        }
      },
      child: BlocBuilder<NavigationCubit, int>(
        builder: (context, selectedIndex) {
          return Scaffold(
            body: _getSelectedView(selectedIndex),
            bottomNavigationBar: BottomNavBar(
              currentIndex: selectedIndex,
              onTap: (index) => context.read<NavigationCubit>().setIndex(index),
            ),
          );
        },
      ),
    );
  }

  void _showParkingDialog(BuildContext context) {
    final parentContext = context; // <-- store parent context here

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
