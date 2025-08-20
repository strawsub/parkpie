import 'package:flutter/material.dart';
import 'features/map/map_screen.dart';
import 'features/contribute/contribute_screen.dart';
import 'shared/widgets/nav_bar.dart'; // Make sure you created this

void main() {
  runApp(const ParkPieApp());
}

class ParkPieApp extends StatelessWidget {
  const ParkPieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeContainer(), // changed from MapScreen()
    );
  }
}

class HomeContainer extends StatefulWidget {
  const HomeContainer({super.key});

  @override
  _HomeContainerState createState() => _HomeContainerState();
}

class _HomeContainerState extends State<HomeContainer> {
  int _selectedIndex = 0;

  // List of screens to switch between
  final List<Widget> _screens = [
    MapScreen(),
    ContributeScreen(),
  ];

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex], // show selected screen
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// void main() {
//   runApp(const ProviderScope(child: ParkPieApp()));
// }

// class ParkPieApp extends StatelessWidget {
//   const ParkPieApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'ParkPie Demo',
//       theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
//       home: const SignsDemoPage(),
//     );
//   }
// }
