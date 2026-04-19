import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/app.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:provider/provider.dart';

Widget _buildHarness({
  required AuthProvider authProvider,
  required Future<bool> bootstrapFuture,
}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: MaterialApp(
      home: AuthBootstrapGate(
        bootstrapFuture: bootstrapFuture,
        loadingBuilder: (_) => const Scaffold(body: Text('loading-auth')),
        authenticatedBuilder: (_) => const Scaffold(body: Text('authenticated-home')),
        unauthenticatedBuilder: (_) => const Scaffold(body: Text('auth-pages')),
      ),
    ),
  );
}

void main() {
  group('AuthBootstrapGate', () {
    testWidgets('shows loading while auth session is resolving', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider(AuthRepository());
      final completer = Completer<bool>();

      await tester.pumpWidget(
        _buildHarness(
          authProvider: authProvider,
          bootstrapFuture: completer.future,
        ),
      );

      expect(find.text('loading-auth'), findsOneWidget);
      expect(find.text('authenticated-home'), findsNothing);
      expect(find.text('auth-pages'), findsNothing);
    });

    testWidgets('shows authenticated builder when session is restored', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider(AuthRepository())
        ..sessionResolved = true
        ..accessToken = 'stored-access-token'
        ..currentUser = UserData(
          userId: 1,
          email: 'elder@example.com',
          fullName: 'Nguyen Van A',
          role: 'patient',
        );

      await tester.pumpWidget(
        _buildHarness(
          authProvider: authProvider,
          bootstrapFuture: Future<bool>.value(true),
        ),
      );
      await tester.pump();

      expect(find.text('authenticated-home'), findsOneWidget);
      expect(find.text('auth-pages'), findsNothing);
      expect(find.text('loading-auth'), findsNothing);
    });

    testWidgets('shows unauthenticated builder when no session is available', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider(AuthRepository())..sessionResolved = true;

      await tester.pumpWidget(
        _buildHarness(
          authProvider: authProvider,
          bootstrapFuture: Future<bool>.value(false),
        ),
      );
      await tester.pump();

      expect(find.text('auth-pages'), findsOneWidget);
      expect(find.text('authenticated-home'), findsNothing);
      expect(find.text('loading-auth'), findsNothing);
    });
  });
}
