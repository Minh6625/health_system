import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';

enum _NotificationFilter { all, unread, read }

String? normalizeNotificationSeverityLabel(String? severity) {
  switch (severity?.trim().toLowerCase()) {
    case 'low':
      return 'low';
    case 'medium':
    case 'moderate':
    case 'high':
      return 'medium';
    case 'critical':
      return 'critical';
    default:
      return null;
  }
}

Color notificationSeverityColor(String? severity) {
  switch (normalizeNotificationSeverityLabel(severity)) {
    case 'critical':
      return AppColors.critical;
    case 'medium':
      return AppColors.warning;
    case 'low':
    default:
      return AppColors.success;
  }
}

String notificationSeverityLabel(String? severity) {
  switch (normalizeNotificationSeverityLabel(severity)) {
    case 'critical':
      return 'critical';
    case 'medium':
      return 'medium';
    case 'low':
      return 'low';
    default:
      return 'low';
  }
}

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

  _NotificationFilter _selectedFilter = _NotificationFilter.all;
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
    if (!mounted) {
      return;
    }
    final newQuery = _searchController.text.trim().toLowerCase();
    if (newQuery == _searchQuery) {
      return;
    }
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

  DateTime? _parseCreatedAt(Map<String, dynamic> item) {
    final createdAtRaw = item['created_at'] as String?;
    if (createdAtRaw == null) {
      return null;
    }
    return DateTime.tryParse(createdAtRaw)?.toLocal();
  }

  bool _isSosNotification(Map<String, dynamic> item) {
    final alertType = (item['alert_type'] as String?)?.toLowerCase() ?? '';
    final title = (item['title'] as String?)?.toLowerCase() ?? '';

    return alertType == 'sos' ||
        alertType == 'manual' ||
        alertType.contains('sos') ||
        title.contains('sos');
  }

  bool _isRiskNotification(Map<String, dynamic> item) {
    final alertType = (item['alert_type'] as String?)?.toLowerCase() ?? '';
    return alertType.startsWith('risk_');
  }

  /// Priority score for sort order: lower = higher priority.
  int _notificationPriority(Map<String, dynamic> item) {
    if (_isSosNotification(item)) return 0;
    if (_isRiskNotification(item)) return 1;
    return 2;
  }

  List<Map<String, dynamic>> _sortNotifications(
    List<Map<String, dynamic>> source,
  ) {
    final sorted = List<Map<String, dynamic>>.from(source);
    sorted.sort((a, b) {
      final aIsRead = a['is_read'] == true;
      final bIsRead = b['is_read'] == true;

      // Always keep unread notifications above read notifications.
      if (aIsRead != bIsRead) {
        return aIsRead ? 1 : -1;
      }

      // SOS first, then risk, then others.
      final aPriority = _notificationPriority(a);
      final bPriority = _notificationPriority(b);
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }

      final aCreated = _parseCreatedAt(a);
      final bCreated = _parseCreatedAt(b);
      if (aCreated == null && bCreated == null) {
        return 0;
      }
      if (aCreated == null) {
        return 1;
      }
      if (bCreated == null) {
        return -1;
      }
      return bCreated.compareTo(aCreated);
    });
    return sorted;
  }

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
      final unreadOnly = _selectedFilter == _NotificationFilter.unread;

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
      if (!mounted) {
        return;
      }
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
  /// Backend enforces max `limit=100`, so this method loops through pages
  /// of [_fetchAllPageSize] until all items are retrieved.
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

      // Stop when: no more items returned, or we've fetched everything
      if (fetched.isEmpty || fetched.length < _fetchAllPageSize) {
        break;
      }
      if (totalCount != null && allItems.length >= totalCount) {
        break;
      }

      offset += _fetchAllPageSize;
    }

    if (!mounted) return;

    final effectiveTotal = totalCount ?? allItems.length;
    final totalPages = math.max(
      1,
      (effectiveTotal + _pageSize - 1) ~/ _pageSize,
    );

    setState(() {
      _items = _sortNotifications(allItems);
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
      _items = _sortNotifications(fetched);
      _currentPage = clampedPage;
      _totalPages = totalPages;
      _unreadCount = unreadCount;
    });
  }

  /// Returns ALL items matching the current filter + search query (no pagination).
  List<Map<String, dynamic>> get _allFilteredItems {
    List<Map<String, dynamic>> filtered;
    switch (_selectedFilter) {
      case _NotificationFilter.read:
        filtered = _items.where((item) => item['is_read'] == true).toList();
        break;
      case _NotificationFilter.unread:
        filtered = _items.where((item) => item['is_read'] != true).toList();
        break;
      case _NotificationFilter.all:
        filtered = _items;
        break;
    }

    if (_searchQuery.isEmpty) {
      return filtered;
    }

    return filtered.where((item) {
      final title = (item['title'] as String? ?? '').toLowerCase();
      final message = (item['message'] as String? ?? '').toLowerCase();
      return title.contains(_searchQuery) || message.contains(_searchQuery);
    }).toList();
  }

  /// Total pages based on filtered data (client-side) when searching,
  /// or server-side total when not searching.
  int get _effectiveTotalPages {
    if (_searchQuery.isNotEmpty) {
      final count = _allFilteredItems.length;
      return math.max(1, (count + _pageSize - 1) ~/ _pageSize);
    }
    return _totalPages;
  }

  /// Returns the paginated slice of filtered items for the current page.
  List<Map<String, dynamic>> get _paginatedItems {
    final allFiltered = _allFilteredItems;
    if (_searchQuery.isNotEmpty) {
      // Client-side pagination on filtered results
      final startIndex = (_currentPage - 1) * _pageSize;
      if (startIndex >= allFiltered.length) {
        return <Map<String, dynamic>>[];
      }
      final endIndex = math.min(startIndex + _pageSize, allFiltered.length);
      return allFiltered.sublist(startIndex, endIndex);
    }
    // When not searching, _items already contains only the current page from API
    return allFiltered;
  }

  Future<void> _changeFilter(_NotificationFilter next) async {
    if (_selectedFilter == next) {
      return;
    }

    setState(() {
      _selectedFilter = next;
      _currentPage = 1;
    });
    await _loadNotifications(showLoading: false, page: 1);
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null || item['is_read'] == true) {
      return;
    }

    try {
      await _apiClient.put('/notifications/$id/read', body: const {});
      if (!mounted) {
        return;
      }

      setState(() {
        item['is_read'] = true;
        if (_unreadCount > 0) {
          _unreadCount -= 1;
        }
        if (_selectedFilter == _NotificationFilter.unread) {
          _items.removeWhere((e) => e['id'] == id);
        }
        _items = _sortNotifications(_items);
      });
    } catch (_) {
      // Keep UI responsive; refresh will sync actual state.
    }
  }

  String _timeAgoLabel(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  String _dateTimeLabel(DateTime createdAt) {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year.toString();
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Color _severityColor(String severity) {
    return notificationSeverityColor(severity);
  }

  String _severityLabel(String severity) {
    return notificationSeverityLabel(severity);
  }

  String _alertTypeLabel(String alertType) {
    switch (alertType.toLowerCase()) {
      case 'fall_detected':
      case 'fall_detection':
        return 'Té ngã';
      case 'manual':
      case 'sos':
        return 'Khẩn cấp';
      case 'risk_critical':
        return 'Nguy cơ nghiêm trọng';
      case 'risk_high':
        return 'Cảnh báo nguy cơ';
      case 'medication_missed':
        return 'Quên thuốc';
      case 'heart_rate_critical':
      case 'spo2_critical':
      case 'blood_pressure_critical':
      case 'vital_critical':
        return 'Chỉ số nguy hiểm';
      default:
        return 'Hệ thống';
    }
  }

  Color _typeChipColor(String alertType) {
    switch (alertType.toLowerCase()) {
      case 'fall_detected':
      case 'fall_detection':
        return AppStateColors.criticalBg;
      case 'manual':
      case 'sos':
        return AppStateColors.warningBg;
      case 'risk_critical':
        return AppStateColors.criticalBg;
      case 'risk_high':
        return AppStateColors.warningBg;
      case 'medication_missed':
        return AppStateColors.successBg;
      default:
        return AppStateColors.infoBg;
    }
  }

  Map<String, dynamic> _toDataMap(Object? rawData) {
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return rawData.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  String _prettifyKey(String key) {
    final normalized = key.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) {
      return 'Thông tin';
    }
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String? _extractSosId(Map<String, dynamic> item) {
    final data = _toDataMap(item['data']);
    final candidates = <Object?>[
      item['sos_id'],
      item['sos_event_id'],
      data['sos_id'],
      data['sos_event_id'],
      data['sosId'],
      data['sosEventId'],
      data['event_id'],
    ];

    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final value = candidate.toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  List<MapEntry<String, String>> _buildRelatedFields(
    Map<String, dynamic> item,
  ) {
    final data = _toDataMap(item['data']);
    if (data.isEmpty) {
      return <MapEntry<String, String>>[];
    }

    final fields = <MapEntry<String, String>>[];
    final usedKeys = <String>{};

    void addField(String key, String label, String Function(dynamic)? format) {
      if (!data.containsKey(key)) {
        return;
      }
      final value = data[key];
      if (value == null) {
        return;
      }
      final text = format != null ? format(value) : value.toString();
      if (text.trim().isEmpty) {
        return;
      }
      fields.add(MapEntry(label, text));
      usedKeys.add(key);
    }

    addField('heart_rate', 'Nhịp tim', (v) => '${v.toString()} BPM');
    addField('spo2', 'SpO2', (v) => '${v.toString()}%');
    addField('temperature', 'Nhiệt độ', (v) => '${v.toString()}°C');
    addField('battery', 'Pin thiết bị', (v) => '${v.toString()}%');
    addField('confidence', 'Độ tin cậy', (v) {
      final num? parsed = num.tryParse(v.toString());
      if (parsed == null) {
        return v.toString();
      }
      final pct = parsed <= 1 ? parsed * 100 : parsed;
      return '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%';
    });
    addField('duration_minutes', 'Thời lượng', (v) => '${v.toString()} phút');
    addField('threshold', 'Ngưỡng cảnh báo', (v) => v.toString());
    addField('address', 'Vị trí', (v) => v.toString());
    addField('location', 'Khu vực', (v) => v.toString());
    addField('trigger', 'Kích hoạt bởi', (v) => v.toString());
    addField('offline_duration', 'Mất kết nối', (v) => '${v.toString()} phút');

    final sys = data['blood_pressure_sys'];
    final dia = data['blood_pressure_dia'];
    if (sys != null || dia != null) {
      final sysText = sys?.toString() ?? '--';
      final diaText = dia?.toString() ?? '--';
      fields.add(MapEntry('Huyết áp', '$sysText/$diaText mmHg'));
      usedKeys.add('blood_pressure_sys');
      usedKeys.add('blood_pressure_dia');
    }

    for (final entry in data.entries) {
      if (fields.length >= 8) {
        break;
      }
      if (usedKeys.contains(entry.key)) {
        continue;
      }
      if (entry.value == null || entry.value is Map || entry.value is List) {
        continue;
      }
      fields.add(MapEntry(_prettifyKey(entry.key), entry.value.toString()));
    }

    return fields;
  }

  bool _containsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  double? _asDouble(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse(raw.toString());
  }

  String _formatNumber(double value, {int maxFraction = 1}) {
    final isInt = value % 1 == 0;
    return value.toStringAsFixed(isInt ? 0 : maxFraction);
  }

  _DetailVitalState _heartRateState(double value) {
    if (value < 50 || value > 120) {
      return _DetailVitalState.critical;
    }
    if (value < 60 || value > 100) {
      return _DetailVitalState.warning;
    }
    return _DetailVitalState.normal;
  }

  _DetailVitalState _spo2State(double value) {
    if (value < 90) {
      return _DetailVitalState.critical;
    }
    if (value < 95) {
      return _DetailVitalState.warning;
    }
    return _DetailVitalState.normal;
  }

  _DetailVitalState _bloodPressureState(double? sys, double? dia) {
    final sysCritical = sys != null && (sys >= 180 || sys < 80);
    final diaCritical = dia != null && (dia >= 120 || dia < 50);
    if (sysCritical || diaCritical) {
      return _DetailVitalState.critical;
    }

    final sysWarning = sys != null && (sys >= 140 || sys < 90);
    final diaWarning = dia != null && (dia >= 90 || dia < 60);
    if (sysWarning || diaWarning) {
      return _DetailVitalState.warning;
    }
    return _DetailVitalState.normal;
  }

  _DetailVitalState _temperatureState(double value) {
    if (value >= 39 || value < 35) {
      return _DetailVitalState.critical;
    }
    if (value >= 37.5 || value < 36) {
      return _DetailVitalState.warning;
    }
    return _DetailVitalState.normal;
  }

  String _stateLabel(_DetailVitalState state) {
    return switch (state) {
      _DetailVitalState.normal => 'Bình thường',
      _DetailVitalState.warning => 'Cảnh báo',
      _DetailVitalState.critical => 'Nguy cấp',
    };
  }

  _DetailVitalInsight? _buildVitalInsight(Map<String, dynamic> item) {
    final data = _toDataMap(item['data']);
    final title = ((item['title'] as String?) ?? '').toLowerCase();
    final message = ((item['message'] as String?) ?? '').toLowerCase();
    final alertType = ((item['alert_type'] as String?) ?? '').toLowerCase();

    final text = '$title $message $alertType';
    final hasVitalKey =
        data.containsKey('heart_rate') ||
        data.containsKey('spo2') ||
        data.containsKey('blood_pressure_sys') ||
        data.containsKey('blood_pressure_dia') ||
        data.containsKey('temperature');

    final isVitalNotification =
        hasVitalKey ||
        _containsAny(text, [
          'nhịp tim',
          'heart rate',
          'spo2',
          'huyết áp',
          'nhiệt độ',
          'vital',
        ]);

    if (!isVitalNotification) {
      return null;
    }

    final hasHeartRate =
        data.containsKey('heart_rate') ||
        _containsAny(text, ['nhịp tim', 'heart rate']);
    if (hasHeartRate) {
      final current = _asDouble(data['heart_rate']);
      if (current == null) {
        return null;
      }

      final state = _heartRateState(current);
      String? trendText;
      if (current > 100) {
        final from = _asDouble(data['threshold']) ?? 100;
        trendText =
            'Tăng từ ${_formatNumber(from, maxFraction: 0)} BPM lên ${_formatNumber(current, maxFraction: 0)} BPM';
      } else if (current < 60) {
        final from = _asDouble(data['threshold_low']) ?? 60;
        trendText =
            'Giảm từ ${_formatNumber(from, maxFraction: 0)} BPM xuống ${_formatNumber(current, maxFraction: 0)} BPM';
      }

      return _DetailVitalInsight(
        metricLabel: 'Nhịp tim',
        valueText: '${_formatNumber(current, maxFraction: 0)} BPM',
        statusLabel: _stateLabel(state),
        state: state,
        icon: Icons.favorite_rounded,
        trendText: trendText,
      );
    }

    final hasSpo2 = data.containsKey('spo2') || text.contains('spo2');
    if (hasSpo2) {
      final current = _asDouble(data['spo2']);
      if (current == null) {
        return null;
      }

      final state = _spo2State(current);
      String? trendText;
      if (current < 95) {
        final from = _asDouble(data['threshold']) ?? 95;
        trendText =
            'Giảm từ ${_formatNumber(from)}% xuống ${_formatNumber(current)}%';
      }

      return _DetailVitalInsight(
        metricLabel: 'SpO2',
        valueText: '${_formatNumber(current)}%',
        statusLabel: _stateLabel(state),
        state: state,
        icon: Icons.water_drop_rounded,
        trendText: trendText,
      );
    }

    final hasBloodPressure =
        data.containsKey('blood_pressure_sys') ||
        data.containsKey('blood_pressure_dia') ||
        _containsAny(text, ['huyết áp', 'blood pressure']);
    if (hasBloodPressure) {
      final sys = _asDouble(data['blood_pressure_sys']);
      final dia = _asDouble(data['blood_pressure_dia']);
      if (sys == null && dia == null) {
        return null;
      }

      final state = _bloodPressureState(sys, dia);
      final sysText = sys != null ? _formatNumber(sys, maxFraction: 0) : '--';
      final diaText = dia != null ? _formatNumber(dia, maxFraction: 0) : '--';
      String? trendText;

      final isIncrease =
          (sys != null && sys >= 140) || (dia != null && dia >= 90);
      final isDecrease = (sys != null && sys < 90) || (dia != null && dia < 60);
      if (isIncrease) {
        final fromSys = _asDouble(data['threshold_sys']) ?? 140;
        final fromDia = _asDouble(data['threshold_dia']) ?? 90;
        trendText =
            'Tăng từ ${_formatNumber(fromSys, maxFraction: 0)}/${_formatNumber(fromDia, maxFraction: 0)} mmHg lên $sysText/$diaText mmHg';
      } else if (isDecrease) {
        final fromSys = _asDouble(data['threshold_sys_low']) ?? 90;
        final fromDia = _asDouble(data['threshold_dia_low']) ?? 60;
        trendText =
            'Giảm từ ${_formatNumber(fromSys, maxFraction: 0)}/${_formatNumber(fromDia, maxFraction: 0)} mmHg xuống $sysText/$diaText mmHg';
      }

      return _DetailVitalInsight(
        metricLabel: 'Huyết áp',
        valueText: '$sysText/$diaText mmHg',
        statusLabel: _stateLabel(state),
        state: state,
        icon: Icons.monitor_heart_rounded,
        trendText: trendText,
      );
    }

    final hasTemperature =
        data.containsKey('temperature') ||
        _containsAny(text, ['nhiệt độ', 'temperature', 'temp']);
    if (hasTemperature) {
      final current = _asDouble(data['temperature']);
      if (current == null) {
        return null;
      }

      final state = _temperatureState(current);
      String? trendText;
      if (current >= 37.5) {
        final from = _asDouble(data['threshold']) ?? 37.5;
        trendText =
            'Tăng từ ${_formatNumber(from)}°C lên ${_formatNumber(current)}°C';
      } else if (current < 36) {
        final from = _asDouble(data['threshold_low']) ?? 36;
        trendText =
            'Giảm từ ${_formatNumber(from)}°C xuống ${_formatNumber(current)}°C';
      }

      return _DetailVitalInsight(
        metricLabel: 'Nhiệt độ',
        valueText: '${_formatNumber(current)}°C',
        statusLabel: _stateLabel(state),
        state: state,
        icon: Icons.thermostat_rounded,
        trendText: trendText,
      );
    }

    return null;
  }

  void _syncNotificationFromServer(Map<String, dynamic> serverItem) {
    final id = serverItem['id'];
    if (id == null || !mounted) {
      return;
    }

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
      } else if (!(_selectedFilter == _NotificationFilter.unread &&
          nextIsRead)) {
        _items.add(Map<String, dynamic>.from(serverItem));
      }

      if (_selectedFilter == _NotificationFilter.unread && nextIsRead) {
        _items.removeWhere((e) => e['id'] == id);
      }

      _items = _sortNotifications(_items);
    });
  }

  Future<void> _goToPreviousPage() async {
    if (_currentPage <= 1 || _isLoading || _isRefreshing) {
      return;
    }
    if (_searchQuery.isNotEmpty) {
      // Client-side pagination: just change page, no API call
      setState(() {
        _currentPage = _currentPage - 1;
      });
      return;
    }
    await _loadNotifications(showLoading: false, page: _currentPage - 1);
  }

  Future<void> _goToNextPage() async {
    final totalPages = _effectiveTotalPages;
    if (_currentPage >= totalPages || _isLoading || _isRefreshing) {
      return;
    }
    if (_searchQuery.isNotEmpty) {
      // Client-side pagination: just change page, no API call
      setState(() {
        _currentPage = _currentPage + 1;
      });
      return;
    }
    await _loadNotifications(showLoading: false, page: _currentPage + 1);
  }

  Widget _buildPaginationControls() {
    final totalPages = _effectiveTotalPages;
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final canGoPrev = _currentPage > 1 && !_isLoading && !_isRefreshing;
    final canGoNext =
        _currentPage < totalPages && !_isLoading && !_isRefreshing;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: canGoPrev ? _goToPreviousPage : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            label: const Text('Trước'),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Trang $_currentPage/$totalPages',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: canGoNext ? _goToNextPage : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Sau'),
          ),
        ],
      ),
    );
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    await _markAsRead(item);
    if (!mounted) {
      return;
    }

    if (_isSosNotification(item)) {
      final sosId = _extractSosId(item) ?? item['id']?.toString();
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
        builder: (_) => _NotificationDetailScreen(
          initialItem: Map<String, dynamic>.from(item),
          apiClient: _apiClient,
          onDetailLoaded: _syncNotificationFromServer,
          alertTypeLabelBuilder: _alertTypeLabel,
          severityLabelBuilder: _severityLabel,
          severityColorBuilder: _severityColor,
          relatedFieldsBuilder: _buildRelatedFields,
          vitalInsightBuilder: _buildVitalInsight,
          createdAtParser: _parseCreatedAt,
          dateTimeLabelBuilder: _dateTimeLabel,
          timeAgoLabelBuilder: _timeAgoLabel,
        ),
      ),
    );

    if (mounted) {
      await _loadNotifications(showLoading: false, page: _currentPage);
    }
  }

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                border: Border.all(color: AppColors.strokeSoft),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tiêu đề hoặc nội dung...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterChip(
                    label: 'Tất cả',
                    filter: _NotificationFilter.all,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    label: 'Chưa đọc',
                    filter: _NotificationFilter.unread,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    label: 'Đã đọc',
                    filter: _NotificationFilter.read,
                  ),
                ),
              ],
            ),
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

  Widget _buildFilterChip({
    required String label,
    required _NotificationFilter filter,
  }) {
    final isSelected = filter == _selectedFilter;
    final selectedColor = switch (filter) {
      _NotificationFilter.unread => AppColors.critical,
      _NotificationFilter.read => AppColors.success,
      _NotificationFilter.all => AppColors.info,
    };

    return Material(
      color: isSelected
          ? selectedColor.withValues(alpha: 0.12)
          : AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        onTap: () => _changeFilter(filter),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.radiusSm),
            border: Border.all(
              color: isSelected ? selectedColor : AppColors.strokeSoft,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? selectedColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _loadNotifications(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final items = _paginatedItems;
    if (items.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'Không tìm thấy thông báo phù hợp'
                        : _selectedFilter == _NotificationFilter.read
                        ? 'Chưa có thông báo đã đọc'
                        : _selectedFilter == _NotificationFilter.unread
                        ? 'Không có thông báo chưa đọc'
                        : 'Chưa có thông báo nào',
                  ),
                ),
              ],
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
        final isRead = item['is_read'] == true;
        final type = (item['alert_type'] as String?) ?? 'general';
        final severity = (item['severity'] as String?) ?? 'normal';
        final createdAt = _parseCreatedAt(item);

        return Transform.translate(
          offset: Offset(0, isRead ? 0 : -2),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isRead ? AppColors.bgSurface : const Color(0xFFDDE8FA),
              borderRadius: BorderRadius.circular(AppRadii.radiusSm),
              border: Border.all(color: AppColors.strokeSoft, width: 1),
              boxShadow: [
                BoxShadow(
                  color: isRead
                      ? Colors.black.withValues(alpha: 0.03)
                      : AppColors.brandPrimary.withValues(alpha: 0.14),
                  blurRadius: isRead ? 8 : 12,
                  offset: Offset(0, isRead ? 2 : 4),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Stack(
              children: [
                if (!isRead)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: AppColors.info),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                    onTap: () => _openNotification(item),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _severityColor(severity),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (item['title'] as String?) ?? 'Thông báo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isRead
                                        ? FontWeight.w600
                                        : FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (createdAt != null)
                                Text(
                                  _timeAgoLabel(createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (item['message'] as String?) ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _InfoChip(
                                label: _alertTypeLabel(type),
                                color: _typeChipColor(type),
                              ),
                              _InfoChip(
                                label: _severityLabel(severity),
                                color: AppColors.bgPrimary,
                              ),
                              if (!isRead)
                                const _InfoChip(
                                  label: 'Mới',
                                  color: AppStateColors.infoBg,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: AppRadii.pillRadius,
        color: color,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

enum _DetailVitalState { normal, warning, critical }

class _DetailVitalInsight {
  const _DetailVitalInsight({
    required this.metricLabel,
    required this.valueText,
    required this.statusLabel,
    required this.state,
    required this.icon,
    this.trendText,
  });

  final String metricLabel;
  final String valueText;
  final String statusLabel;
  final _DetailVitalState state;
  final IconData icon;
  final String? trendText;
}

class _NotificationDetailScreen extends StatefulWidget {
  const _NotificationDetailScreen({
    required this.initialItem,
    required this.apiClient,
    required this.onDetailLoaded,
    required this.alertTypeLabelBuilder,
    required this.severityLabelBuilder,
    required this.severityColorBuilder,
    required this.relatedFieldsBuilder,
    required this.vitalInsightBuilder,
    required this.createdAtParser,
    required this.dateTimeLabelBuilder,
    required this.timeAgoLabelBuilder,
  });

  final Map<String, dynamic> initialItem;
  final ApiClient apiClient;
  final ValueChanged<Map<String, dynamic>> onDetailLoaded;
  final String Function(String) alertTypeLabelBuilder;
  final String Function(String) severityLabelBuilder;
  final Color Function(String) severityColorBuilder;
  final List<MapEntry<String, String>> Function(Map<String, dynamic>)
  relatedFieldsBuilder;
  final _DetailVitalInsight? Function(Map<String, dynamic>) vitalInsightBuilder;
  final DateTime? Function(Map<String, dynamic>) createdAtParser;
  final String Function(DateTime) dateTimeLabelBuilder;
  final String Function(DateTime) timeAgoLabelBuilder;

  @override
  State<_NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<_NotificationDetailScreen> {
  Map<String, dynamic>? _item;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  DateTime? _parseDateTimeValue(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw.toLocal();
    }
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  Future<void> _loadDetail() async {
    final id = widget.initialItem['id'];
    if (id == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Thiếu mã thông báo để tải chi tiết';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await widget.apiClient.get('/notifications/$id');
      final detail = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      if (!mounted) {
        return;
      }

      widget.onDetailLoaded(Map<String, dynamic>.from(detail));
      setState(() {
        _item = detail;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 28,
              color: AppColors.critical,
            ),
            const SizedBox(height: 10),
            const Text(
              'Không thể tải chi tiết thông báo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Đã xảy ra lỗi không xác định',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _loadDetail, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBlock({double? width, double height = 12}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.strokeSoft,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      ),
    );
  }

  Widget _buildInitialSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadii.radiusMd),
              border: Border.all(color: AppColors.strokeSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBlock(width: 210, height: 18),
                const SizedBox(height: 12),
                _skeletonBlock(width: double.infinity, height: 12),
                const SizedBox(height: 8),
                _skeletonBlock(width: 240, height: 12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _skeletonBlock(width: 78, height: 24),
                    const SizedBox(width: 8),
                    _skeletonBlock(width: 92, height: 24),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadii.radiusMd),
              border: Border.all(color: AppColors.strokeSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBlock(width: 150, height: 16),
                const SizedBox(height: 12),
                _skeletonBlock(width: double.infinity, height: 12),
                const SizedBox(height: 8),
                _skeletonBlock(width: double.infinity, height: 12),
                const SizedBox(height: 8),
                _skeletonBlock(width: 190, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({Color bg, Color border, Color accent}) _vitalPalette(
    _DetailVitalState state,
  ) {
    return switch (state) {
      _DetailVitalState.normal => (
        bg: AppStateColors.successBg,
        border: const Color(0xFFCDE9D7),
        accent: AppColors.success,
      ),
      _DetailVitalState.warning => (
        bg: AppStateColors.warningBg,
        border: const Color(0xFFF8CF9B),
        accent: AppColors.warning,
      ),
      _DetailVitalState.critical => (
        bg: AppStateColors.criticalBg,
        border: const Color(0xFFF4B6BF),
        accent: AppColors.critical,
      ),
    };
  }

  Widget _buildVitalInsightCard(_DetailVitalInsight insight) {
    final palette = _vitalPalette(insight.state);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        border: Border.all(color: palette.border, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(insight.icon, size: 18, color: palette.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.metricLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight.valueText,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            insight.statusLabel,
            style: TextStyle(
              fontSize: 12,
              color: palette.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;

    if (item == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: const Text('Chi tiết thông báo')),
        body: _isLoading ? _buildInitialSkeleton() : _buildLoadError(),
      );
    }

    final type = (item['alert_type'] as String?) ?? 'general';
    final severity = (item['severity'] as String?) ?? 'normal';
    final title = (item['title'] as String?) ?? 'Thông báo';
    final message = (item['message'] as String?) ?? '';
    final notificationId = item['id']?.toString() ?? '--';
    final alertTypeLabel = widget.alertTypeLabelBuilder(type);
    final severityLabel = widget.severityLabelBuilder(severity);
    final severityColor = widget.severityColorBuilder(severity);
    final createdAt = widget.createdAtParser(item);
    final createdAtText = createdAt != null
        ? widget.dateTimeLabelBuilder(createdAt)
        : '--';
    final createdAgoText = createdAt != null
        ? widget.timeAgoLabelBuilder(createdAt)
        : '--';
    final readStatusText = item['is_read'] == true ? 'Đã đọc' : 'Chưa đọc';
    final readAt = _parseDateTimeValue(item['read_at']);
    final readAtText = readAt != null
        ? widget.dateTimeLabelBuilder(readAt)
        : null;
    final relatedFields = widget.relatedFieldsBuilder(item);
    final vitalInsight = widget.vitalInsightBuilder(item);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Chi tiết thông báo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 10),
            ],
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppStateColors.criticalBg,
                  borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                  border: Border.all(color: const Color(0xFFF0C7C7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_tethering_error_rounded,
                      size: 18,
                      color: AppColors.critical,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.critical,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadDetail,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                border: Border.all(color: AppColors.strokeSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: severityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message.isEmpty ? 'Không có nội dung mô tả.' : message,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        label: alertTypeLabel,
                        color: AppStateColors.infoBg,
                      ),
                      _InfoChip(
                        label: severityLabel,
                        color: severityColor.withValues(alpha: 0.14),
                      ),
                      _InfoChip(
                        label: readStatusText,
                        color: readStatusText == 'Đã đọc'
                            ? AppStateColors.successBg
                            : AppStateColors.warningBg,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (vitalInsight != null) ...[
              _NotificationDetailSection(
                title: 'Diễn biến chỉ số',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVitalInsightCard(vitalInsight),
                    if ((vitalInsight.trendText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgPrimary,
                          borderRadius: BorderRadius.circular(
                            AppRadii.radiusSm,
                          ),
                          border: Border.all(color: AppColors.strokeSoft),
                        ),
                        child: Text(
                          vitalInsight.trendText!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (relatedFields.isNotEmpty) ...[
              _NotificationDetailSection(
                title: 'Chỉ số và thông tin liên quan',
                child: Column(
                  children: relatedFields
                      .map(
                        (e) => _NotificationDetailRow(
                          label: e.key,
                          value: e.value,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _NotificationDetailSection(
              title: 'Thông tin chi tiết',
              child: Column(
                children: [
                  _NotificationDetailRow(
                    label: 'Mã thông báo',
                    value: notificationId,
                  ),
                  _NotificationDetailRow(label: 'Loại', value: alertTypeLabel),
                  _NotificationDetailRow(label: 'Mức độ', value: severityLabel),
                  _NotificationDetailRow(
                    label: 'Trạng thái',
                    value: readStatusText,
                  ),
                  _NotificationDetailRow(
                    label: 'Thời gian tạo',
                    value: createdAtText,
                  ),
                  _NotificationDetailRow(
                    label: 'Khoảng thời gian',
                    value: createdAgoText,
                  ),
                  if (readAtText != null)
                    _NotificationDetailRow(label: 'Đọc lúc', value: readAtText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationDetailSection extends StatelessWidget {
  const _NotificationDetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _NotificationDetailRow extends StatelessWidget {
  const _NotificationDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
