import 'package:flutter/material.dart';
import 'package:healthguard/app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ignore: depend_on_referenced_packages

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const isProduction = bool.fromEnvironment('dart.vm.product');
  await dotenv.load(fileName: isProduction ? ".env.prod" : ".env.dev");
  runApp(const HealthSystemApp());
}
