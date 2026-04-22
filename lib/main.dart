import 'package:flutter/material.dart';
import 'package:healthguard/app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:healthguard/features/notifications/services/notification_runtime_service.dart';

void main() async {
  debugPrint("==== MAIN STARTED ====");
  try {
    WidgetsFlutterBinding.ensureInitialized();
    // TẠM THỜI TẮT GIỮ SPLASH ĐỂ DEBUG XEM CÓ PHẢI NÓ LÀM ĐEN MÀN HÌNH KHÔNG
    // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    debugPrint("==== BINDING INITIALIZED ====");

    try {
      const isProduction = bool.fromEnvironment('dart.vm.product');
      await dotenv.load(fileName: isProduction ? ".env.prod" : ".env.dev");
      debugPrint("==== DOTENV LOADED ====");
    } catch (e) {
      debugPrint("==== DOTENV ERROR (IGNORING) ==== $e");
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        notificationFirebaseMessagingBackgroundHandler,
      );
      debugPrint("==== FIREBASE INITIALIZED ====");
    } catch (e) {
      debugPrint("==== FIREBASE INIT ERROR (IGNORING) ==== $e");
    }

    runApp(const HealthSystemApp());
    debugPrint("==== RUNAPP CALLED ====");
  } catch (e, stack) {
    debugPrint("==== ERROR IN MAIN ==== $e\n$stack");
  }
}
