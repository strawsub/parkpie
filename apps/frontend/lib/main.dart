import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/camera/camera_screen.dart';
import 'package:frontend/features/camera/camera_bloc.dart';
import 'package:frontend/features/map/map_screen.dart';
import 'package:frontend/features/navigation/navigation_cubit.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/widgets/nav_bar.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
      supportedLocales: const [
        Locale('en', ''),
      ],
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => NavigationCubit()),
          BlocProvider(create: (context) => CameraBloc()),
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
        return MapScreen(); // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationCubit, int>(
      builder: (context, selectedIndex) {
        return Scaffold(
          body: _getSelectedView(selectedIndex),
          bottomNavigationBar: BottomNavBar(
            currentIndex: selectedIndex,
            onTap: (index) => context.read<NavigationCubit>().setIndex(index),
          ),
        );
      },
    );
  }
}
