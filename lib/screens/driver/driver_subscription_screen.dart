import 'package:flutter/material.dart';

import '../../widgets/app_drawer.dart';

class DriverSubscriptionScreen extends StatelessWidget {
  const DriverSubscriptionScreen({super.key, this.initialVehicleData});

  final Map<String, String>? initialVehicleData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('ежим водителя'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.amber,
      ),
      drawer: const AppDrawer(mode: AppMode.driver),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'астройка автомобиля перенесена в новый экран регистрации водителя.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
