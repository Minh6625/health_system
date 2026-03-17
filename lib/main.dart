import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:healthguard/app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  debugPrint("==== MAIN STARTED ====");
  try {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    // TẠM THỜI TẮT GIỮ SPLASH ĐỂ DEBUG XEM CÓ PHẢI NÓ LÀM ĐEN MÀN HÌNH KHÔNG
    // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    debugPrint("==== BINDING INITIALIZED ====");

    const isProduction = bool.fromEnvironment('dart.vm.product');
    await dotenv.load(fileName: isProduction ? ".env.prod" : ".env.dev");
    debugPrint("==== DOTENV LOADED ====");

    runApp(const HealthSystemApp());
    debugPrint("==== RUNAPP CALLED ====");
  } catch (e, stack) {
    debugPrint("==== ERROR IN MAIN ==== $e\n$stack");
  }
}
