import 'package:flutter/material.dart';

class HealthMonitoringScreen extends StatelessWidget {
  const HealthMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giám Sát Sức Khỏe'),
        backgroundColor: Colors.blue[700],
      ),
      body: const Center(
        child: Text(
          'Giám Sát Sức Khỏe',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
