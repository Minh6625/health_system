import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/features/fall/models/fall_event.dart';
import 'package:healthguard/features/fall/providers/fall_event_provider.dart';
import 'package:healthguard/features/fall/widgets/fall_status_chip.dart';

/// Timeline of past fall events, newest first.
///
/// Phase 4B-full slice 2c (mobile half). Pulls from
/// `GET /mobile/fall-events?limit=20`; pull-to-refresh re-runs the
/// fetch. No infinite scroll yet — plan §4B.3 calls for it as a
/// follow-up after pilot user feedback.
class FallHistoryScreen extends StatefulWidget {
  const FallHistoryScreen({super.key});

  static const String routeName = '/fall/history';

  @override
  State<FallHistoryScreen> createState() => _FallHistoryScreenState();
}

class _FallHistoryScreenState extends State<FallHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget initial fetch after the first frame so the
    // Provider is fully mounted in the widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FallEventProvider>();
      // Avoid re-fetching if the provider already loaded recently
      // (e.g. caller refreshed via the home screen).
      if (provider.listState == FallEventLoadState.initial) {
        provider.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sự kiện ngã'),
      ),
      body: Consumer<FallEventProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: _buildBody(theme, provider),
          );
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme, FallEventProvider provider) {
    switch (provider.listState) {
      case FallEventLoadState.initial:
      case FallEventLoadState.loading:
        return _ScrollableSingleChild(
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
        );

      case FallEventLoadState.empty:
        return _ScrollableSingleChild(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            child: Column(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có sự kiện ngã nào',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Khi đồng hồ phát hiện ngã, sự kiện sẽ xuất hiện ở đây.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );

      case FallEventLoadState.error:
        return _ScrollableSingleChild(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 56,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Không thể tải sự kiện ngã',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  provider.listErrorMessage ?? 'Vui lòng thử lại sau.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => provider.refresh(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );

      case FallEventLoadState.success:
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: provider.events.length + 1,  // +1 for footer disclaimer
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == provider.events.length) {
              return const _FooterDisclaimer();
            }
            return _FallEventTile(event: provider.events[index]);
          },
        );
    }
  }
}

class _FallEventTile extends StatelessWidget {
  final FallEvent event;
  const _FallEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm — EEEE, dd/MM/yyyy', 'vi');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    timeFormat.format(event.detectedAt),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                FallStatusChip(status: event.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.percent,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Độ tin cậy AI: ${(event.confidence * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (event.address != null && event.address!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.address!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (event.cancelReason != null && event.cancelReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  event.cancelReason!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FooterDisclaimer extends StatelessWidget {
  const _FooterDisclaimer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đây là cảnh báo do AI dự đoán, không phải chẩn đoán y khoa.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a single child in a scrollable so [RefreshIndicator] still
/// works on empty / loading / error states.
class _ScrollableSingleChild extends StatelessWidget {
  final Widget child;
  const _ScrollableSingleChild({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [child],
    );
  }
}
