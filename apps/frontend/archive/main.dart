import 'package:flutter/material.dart';
import '../archived/views/map_view.dart';
import '../archived/views/camera_view.dart';
import '../archived/shared/widgets/nav_bar.dart';

void main() {
  runApp(const ProviderScope(child: ParkPieApp()));
}

class ParkPieApp extends StatelessWidget {
  const ParkPieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkPie Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      home: const SignsDemoPage(),
    );
  }
}

