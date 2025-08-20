import 'package:flutter/material.dart';

class ContributeScreen extends StatelessWidget {
  const ContributeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contribute'),
        backgroundColor: Colors.blue, // you can change to your theme color
      ),
      body: const Center(
        child: Text(
          'This is the Contribute screen',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}