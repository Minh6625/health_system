import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../utils/notification_severity.dart';
import '../utils/notification_vital_insight.dart';
import '../widgets/notification_empty_state.dart';
import '../widgets/notification_error_view.dart';
import '../widgets/notification_filter_chips.dart';
import '../widgets/notification_list_item.dart';
import '../widgets/notification_pagination_controls.dart';
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
  final TextEditingController _searchController = TextEditingController();
  static const int _pageSize = 10;
  static const int _fetchAllPageSize = 100;

  NotificationFilter _selectedFilter = NotificationFilter.all;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  int _currentPage = 1;
  int _totalPages = 1;
  int _unreadCount = 0;
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadNotifications();
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
      _currentPage = 1;
      _loadNotifications(showLoading: false, page: 1);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ─── API ───────────────────────────────────────────────────────────────

  Future<void> _loadNotifications({bool showLoading = true, int? page}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
        _error = null;
      });
    }

    try {
      final isSearching = _searchQuery.isNotEmpty;
      final unreadOnly = _selectedFilter == NotificationFilter.unread;

      if (isSearching) {
        await _fetchAllForSearch(unreadOnly: unreadOnly);
      } else {
        await _fetchSinglePage(
          page: page ?? _currentPage,
          showLoading: showLoading,
          unreadOnly: unreadOnly,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  /// Fetches ALL notifications across multiple pages for client-side search.
  ///
  /// Backend enforces `limit<=100`, so this loops through pages of
  /// [_fetchAllPageSize] until everything is retrieved.
  Future<void> _fetchAllForSearch({required bool unreadOnly}) async {
    final allItems = <Map<String, dynamic>>[];
    var offset = 0;
    int? totalCount;
    var unreadCount = 0;

    while (true) {
      if (!mounted) return;

      final result = await _apiClient.get(
        '/notifications',
        queryParams: {
          'limit': _fetchAllPageSize,
          'offset': offset,
          'unread_only': unreadOnly,
        },
      );

      final raw = result['notifications'] as List? ?? const [];
      final fetched = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      totalCount ??= (result['total_count'] as num?)?.toInt();
      unreadCount = (result['unread_count'] as num?)?.toInt() ?? unreadCount;

      allItems.addAll(fetched);

      if (fetched.isEmpty || fetched.length < _fetchAllPageSize) break;
      if (totalCount != null && allItems.length >= totalCount) break;

      offset += _fetchAllPageSize;
    }

    if (!mounted) return;

    final effectiveTotal = totalCount ?? allItems.length;
    final totalPages = math.max(
      1,
      (effectiveTotal + _pageSize - 1) ~/ _pageSize,
    );

    setState(() {
      _items = sortNotifications(allItems);
      _currentPage = 1;
      _totalPages = totalPages;
      _unreadCount = unreadCount;
    });
  }

  /// Fetches a single page of notifications for normal (non-search) browsing.
  Future<void> _fetchSinglePage({
    required int page,
    required bool showLoading,
    required bool unreadOnly,
  }) async {
    final normalizedPage = page < 1 ? 1 : page;
    final offset = (normalizedPage - 1) * _pageSize;

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
    final totalCount =
        (result['total_count'] as num?)?.toInt() ?? fetched.length;
    final totalPages = math.max(1, (totalCount + _pageSize - 1) ~/ _pageSize);
    final clampedPage = normalizedPage > totalPages
        ? totalPages
        : normalizedPage;
    final unreadCount = (result['unread_count'] as num?)?.toInt() ?? 0;

    if (!mounted) return;

    if (clampedPage != normalizedPage) {
      await _loadNotifications(showLoading: showLoading, page: clampedPage);
      return;
    }

    setState(() {
      _items = sortNotifications(fetched);
      _currentPage = clampedPage;
      _totalPages = totalPages;
      _unreadCount = unreadCount;
    });
  }

  // ─── Filtering / pagination derivation ─────────────────────────────────

  /// Returns ALL items matching the current filter + search query.
  List<Map<String, dynamic>> get _allFilteredItems {
    List<Map<String, dynamic>> filtered;
    switch (_selectedFilter) {
      case NotificationFilter.read:
        filtered = _items.where((item) => item['is_read'] == true).toList();
        break;
      case NotificationFilter.unread:
        filtered = _items.where((item) => item['is_read'] != true).toList();
        break;
      case NotificationFilter.all:
        filtered = _items;
        break;
    }

    if (_searchQuery.isEmpty) return filtered;

    return filtered.where((item) {
      final title = (item['title'] as String? ?? '').toLowerCase();
      final message = (item['message'] as String? ?? '').toLowerCase();
      return title.contains(_searchQuery) || message.contains(_searchQuery);
    }).toList();
  }

  /// Total pages: client-side count when searching, server-side otherwise.
  int get _effectiveTotalPages {
    if (_searchQuery.isNotEmpty) {
      final count = _allFilteredItems.length;
      return math.max(1, (count + _pageSize - 1) ~/ _pageSize);
    }
    return _totalPages;
  }

  /// Paginated slice of filtered items for the current page.
  List<Map<String, dynamic>> get _paginatedItems {
    final allFiltered = _allFilteredItems;
    if (_searchQuery.isNotEmpty) {
      final startIndex = (_currentPage - 1) * _pageSize;
      if (startIndex >= allFiltered.length) {
        return <Map<String, dynamic>>[];
      }
      final endIndex = math.min(startIndex + _pageSize, allFiltered.length);
      return allFiltered.sublist(startIndex, endIndex);
    }
    return allFiltered;
  }

  // ─── Actions ───────────────────────────────────────────────────────────

  Future<void> _changeFilter(NotificationFilter next) async {
    if (_selectedFilter == next) return;

    setState(() {
      _selectedFilter = next;
      _currentPage = 1;
    });
    await _loadNotifications(showLoading: false, page: 1);
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

  Future<void> _goToPreviousPage() async {
    if (_currentPage <= 1 || _isLoading || _isRefreshing) return;
    if (_searchQuery.isNotEmpty) {
      // Client-side pagination: just change page, no API call.
      setState(() {
        _currentPage = _currentPage - 1;
      });
      return;
    }
    await _loadNotifications(showLoading: false, page: _currentPage - 1);
  }

  Future<void> _goToNextPage() async {
    final totalPages = _effectiveTotalPages;
    if (_currentPage >= totalPages || _isLoading || _isRefreshing) return;
    if (_searchQuery.isNotEmpty) {
      setState(() {
        _currentPage = _currentPage + 1;
      });
      return;
    }
    await _loadNotifications(showLoading: false, page: _currentPage + 1);
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
        if (mounted) {
          await _loadNotifications(showLoading: false, page: _currentPage);
        }
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

    if (mounted) {
      await _loadNotifications(showLoading: false, page: _currentPage);
    }
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadNotifications(showLoading: false),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return NotificationPaginationControls(
      currentPage: _currentPage,
      totalPages: _effectiveTotalPages,
      canGoPrevious: _currentPage > 1 && !_isLoading && !_isRefreshing,
      canGoNext:
          _currentPage < _effectiveTotalPages && !_isLoading && !_isRefreshing,
      onPrevious: _goToPreviousPage,
      onNext: _goToNextPage,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return NotificationErrorView(
        message: _error!,
        onRetry: () => _loadNotifications(),
      );
    }

    final items = _paginatedItems;
    if (items.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: NotificationEmptyState(
              isSearching: _searchQuery.isNotEmpty,
              filter: _selectedFilter,
            ),
          ),
          _buildPaginationControls(),
        ],
      );
    }

    final list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        return NotificationListItem(
          item: item,
          onTap: () => _openNotification(item),
        );
      },
    );

    final content = !_isRefreshing
        ? list
        : Stack(
            children: [
              list,
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ],
          );

    return Column(
      children: [
        Expanded(child: content),
        _buildPaginationControls(),
      ],
    );
  }
}
