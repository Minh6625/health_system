import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../utils/notification_severity.dart';
import '../utils/notification_vital_insight.dart';
import '../widgets/notification_empty_state.dart';
import '../widgets/notification_error_view.dart';
import '../widgets/notification_filter_chips.dart';
import '../widgets/notification_list_item.dart';
import '../widgets/notification_search_bar.dart';
import 'notification_detail_screen.dart';

/// Notifications inbox screen. Owns paging, search debounce, filter, and the
/// `mark-as-read` lifecycle. UI pieces live in `widgets/`.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  ApiClient get _apiClient => widget.apiClient ?? ApiClient();

  static const int _pageSize = 20;
  static const double _loadMoreThresholdPx = 240;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  NotificationFilter _selectedFilter = NotificationFilter.all;
  NotificationTypeFilter _typeFilter = NotificationTypeFilter.all;
  String _searchQuery = '';
  Timer? _searchDebounce;

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  int _unreadCount = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch when the parent passes a different ApiClient (e.g. the user
    // logged out and back in with a different token). Without this the
    // screen would keep showing the old payload until pull-to-refresh.
    if (oldWidget.apiClient != widget.apiClient) {
      _refresh();
    }
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final newQuery = _searchController.text.trim().toLowerCase();
    if (newQuery == _searchQuery) return;
    setState(() {
      _searchQuery = newQuery;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      // Search runs purely client-side over already-loaded items, so a
      // setState is enough — no need to round-trip the API.
      setState(() {});
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThresholdPx) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─── API ───────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    if (!mounted) return;
    final hasItems = _items.isNotEmpty;
    setState(() {
      _isInitialLoading = !hasItems;
      _isRefreshing = hasItems;
      _error = null;
    });

    try {
      final page = await _fetchPage(offset: 0);
      if (!mounted) return;
      setState(() {
        _items = sortNotifications(page.items);
        _hasMore = page.hasMore;
        _unreadCount = page.unreadCount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore ||
        _isInitialLoading ||
        _isRefreshing ||
        _isLoadingMore ||
        !mounted) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final page = await _fetchPage(offset: _items.length);
      if (!mounted) return;
      setState(() {
        final merged = <Map<String, dynamic>>[..._items, ...page.items];
        _items = sortNotifications(merged);
        _hasMore = page.hasMore;
        _unreadCount = page.unreadCount;
      });
    } catch (_) {
      // Silently swallow load-more failures so the list stays usable; the
      // user can pull-to-refresh to retry.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<_NotificationsPage> _fetchPage({required int offset}) async {
    final unreadOnly = _selectedFilter == NotificationFilter.unread;
    final result = await _apiClient.get(
      '/notifications',
      queryParams: {
        'limit': _pageSize,
        'offset': offset,
        'unread_only': unreadOnly,
      },
    );
    final raw = result['notifications'] as List? ?? const [];
    final fetched = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final unreadCount = (result['unread_count'] as num?)?.toInt() ?? 0;
    return _NotificationsPage(
      items: fetched,
      unreadCount: unreadCount,
      hasMore: fetched.length >= _pageSize,
    );
  }

  // ─── Filtering ─────────────────────────────────────────────────────────

  /// All items matching the current status, type and search filters.
  List<Map<String, dynamic>> get _filteredItems {
    Iterable<Map<String, dynamic>> stream = _items;

    switch (_selectedFilter) {
      case NotificationFilter.read:
        stream = stream.where((item) => item['is_read'] == true);
        break;
      case NotificationFilter.unread:
        stream = stream.where((item) => item['is_read'] != true);
        break;
      case NotificationFilter.all:
        break;
    }

    if (_typeFilter != NotificationTypeFilter.all) {
      stream = stream.where(
        (item) => notificationTypeBucket(item) == _typeFilter,
      );
    }

    if (_searchQuery.isNotEmpty) {
      stream = stream.where((item) {
        final title = (item['title'] as String? ?? '').toLowerCase();
        final message = (item['message'] as String? ?? '').toLowerCase();
        return title.contains(_searchQuery) ||
            message.contains(_searchQuery);
      });
    }

    return stream.toList();
  }

  /// Groups already-filtered items into ordered date sections so the list
  /// can render sticky-style "Hôm nay / Hôm qua / Tuần này / Trước đó"
  /// headers between cards.
  List<_NotificationDateGroup> _groupByDate(
    List<Map<String, dynamic>> items,
  ) {
    final buckets = <NotificationDateBucket, List<Map<String, dynamic>>>{};
    final undated = <Map<String, dynamic>>[];
    for (final item in items) {
      final ts = notificationCreatedAt(item);
      if (ts == null) {
        undated.add(item);
        continue;
      }
      final bucket = notificationDateBucketOf(ts);
      buckets.putIfAbsent(bucket, () => <Map<String, dynamic>>[]).add(item);
    }
    final groups = <_NotificationDateGroup>[];
    for (final bucket in NotificationDateBucket.values) {
      final list = buckets[bucket];
      if (list != null && list.isNotEmpty) {
        groups.add(_NotificationDateGroup(bucket: bucket, items: list));
      }
    }
    if (undated.isNotEmpty) {
      groups.add(
        _NotificationDateGroup(
          bucket: NotificationDateBucket.older,
          items: undated,
        ),
      );
    }
    return groups;
  }

  // ─── Actions ───────────────────────────────────────────────────────────

  Future<void> _changeFilter(NotificationFilter next) async {
    if (_selectedFilter == next) return;
    setState(() => _selectedFilter = next);
    await _refresh();
  }

  void _changeTypeFilter(NotificationTypeFilter next) {
    if (_typeFilter == next) return;
    // Type is a purely client-side filter so we just rebuild over the
    // already-loaded items; no API round-trip needed.
    setState(() => _typeFilter = next);
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null || item['is_read'] == true) return;

    try {
      await _apiClient.put('/notifications/$id/read', body: const {});
      if (!mounted) return;

      setState(() {
        item['is_read'] = true;
        if (_unreadCount > 0) {
          _unreadCount -= 1;
        }
        if (_selectedFilter == NotificationFilter.unread) {
          _items.removeWhere((e) => e['id'] == id);
        }
        _items = sortNotifications(_items);
      });
    } catch (_) {
      // Keep UI responsive; refresh will sync actual state.
    }
  }

  void _syncNotificationFromServer(Map<String, dynamic> serverItem) {
    final id = serverItem['id'];
    if (id == null || !mounted) return;

    setState(() {
      final index = _items.indexWhere((e) => e['id'] == id);
      final nextIsRead = serverItem['is_read'] == true;

      if (index >= 0) {
        final previousIsRead = _items[index]['is_read'] == true;
        _items[index] = {..._items[index], ...serverItem};

        if (!previousIsRead && nextIsRead && _unreadCount > 0) {
          _unreadCount -= 1;
        } else if (previousIsRead && !nextIsRead) {
          _unreadCount += 1;
        }
      } else if (!(_selectedFilter == NotificationFilter.unread &&
          nextIsRead)) {
        _items.add(Map<String, dynamic>.from(serverItem));
      }

      if (_selectedFilter == NotificationFilter.unread && nextIsRead) {
        _items.removeWhere((e) => e['id'] == id);
      }

      _items = sortNotifications(_items);
    });
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    await _markAsRead(item);
    if (!mounted) return;

    if (isSosNotification(item)) {
      final sosId = extractNotificationSosId(item) ?? item['id']?.toString();
      if (sosId != null && sosId.isNotEmpty) {
        await Navigator.pushNamed(
          context,
          AppRouter.emergencySosDetail,
          arguments: {'sosId': sosId},
        );
        if (mounted) await _refresh();
        return;
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(
          initialItem: Map<String, dynamic>.from(item),
          apiClient: _apiClient,
          onDetailLoaded: _syncNotificationFromServer,
        ),
      ),
    );

    if (mounted) await _refresh();
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Chưa đọc: $_unreadCount',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          NotificationSearchBar(
            controller: _searchController,
            hasQuery: _searchQuery.isNotEmpty,
            onClear: () => _searchController.clear(),
          ),
          NotificationFilterChips(
            selected: _selectedFilter,
            onChanged: _changeFilter,
          ),
          NotificationTypeFilterChips(
            selected: _typeFilter,
            onChanged: _changeTypeFilter,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const _NotificationsListSkeleton();
    }

    if (_error != null) {
      return NotificationErrorView(message: _error!, onRetry: _refresh);
    }

    final items = _filteredItems;
    if (items.isEmpty) {
      return NotificationEmptyState(
        isSearching: _searchQuery.isNotEmpty,
        filter: _selectedFilter,
      );
    }

    final groups = _groupByDate(items);

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (_isRefreshing)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(minHeight: 2),
          ),
        for (final group in groups) ...[
          SliverToBoxAdapter(
            child: _DateSectionHeader(
              label: notificationDateBucketLabel(group.bucket),
              count: group.items.length,
            ),
          ),
          SliverList.builder(
            itemCount: group.items.length,
            itemBuilder: (context, index) {
              final item = group.items[index];
              return NotificationListItem(
                item: item,
                onTap: () => _openNotification(item),
              );
            },
          ),
        ],
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ),
          )
        else if (!_hasMore && items.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Bạn đã xem hết thông báo',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 12)),
      ],
    );
  }
}

/// Plain data holder for the result of a single page fetch.
class _NotificationsPage {
  const _NotificationsPage({
    required this.items,
    required this.unreadCount,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> items;
  final int unreadCount;
  final bool hasMore;
}

/// Internal grouping container used by `_buildBody` to render section
/// headers between item runs.
class _NotificationDateGroup {
  const _NotificationDateGroup({required this.bucket, required this.items});

  final NotificationDateBucket bucket;
  final List<Map<String, dynamic>> items;
}

/// Renders a section divider with the bucket label (e.g. "Hôm nay") and
/// the number of items inside the bucket.
class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· $count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder shown during the initial fetch. Mirrors the
/// dimensions of `NotificationListItem` so the layout doesn't visibly jump
/// when the real cards arrive.
class _NotificationsListSkeleton extends StatelessWidget {
  const _NotificationsListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemCount: 5,
      itemBuilder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppRadii.radiusMd),
            border: Border.all(color: AppColors.strokeSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.strokeSoft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.strokeSoft.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 220,
                      decoration: BoxDecoration(
                        color: AppColors.strokeSoft.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 140,
                      decoration: BoxDecoration(
                        color: AppColors.strokeSoft.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
