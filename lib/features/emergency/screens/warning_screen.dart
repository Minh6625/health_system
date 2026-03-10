import 'package:flutter/material.dart';

class WarningScreen extends StatelessWidget {
  const WarningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh Báo & Khẩn Cấp'),
        backgroundColor: Colors.orange[700],
      ),
      body: const Center(
        child: Text(
          'Cảnh Báo & Khẩn Cấp',
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
