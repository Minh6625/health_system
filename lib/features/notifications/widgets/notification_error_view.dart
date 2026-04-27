import 'package:flutter/material.dart';

/// Inline error view shown inside the notifications list when the initial
/// fetch fails. Wrapped in `ListView` so [RefreshIndicator] still works.
class NotificationErrorView extends StatelessWidget {
  const NotificationErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  'Không thể tải thông báo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
