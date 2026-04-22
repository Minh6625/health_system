import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../services/notification_runtime_service.dart';

class NotificationRuntimeAuthBridge extends StatefulWidget {
  const NotificationRuntimeAuthBridge({
    super.key,
    required this.service,
    required this.child,
  });

  final NotificationRuntimeService service;
  final Widget child;

  @override
  State<NotificationRuntimeAuthBridge> createState() =>
      _NotificationRuntimeAuthBridgeState();
}

class _NotificationRuntimeAuthBridgeState
    extends State<NotificationRuntimeAuthBridge> {
  AuthProvider? _authProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextProvider = context.read<AuthProvider>();
    if (identical(nextProvider, _authProvider)) {
      return;
    }

    _authProvider?.removeListener(_onAuthChanged);
    _authProvider = nextProvider;
    _authProvider?.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final authProvider = _authProvider;
    if (authProvider == null) {
      return;
    }

    unawaited(
      widget.service.onAuthStateChanged(
        isAuthenticated:
            authProvider.sessionResolved && authProvider.isAuthenticated,
      ),
    );
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
