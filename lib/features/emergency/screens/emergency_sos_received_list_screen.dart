import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/features/emergency/widgets/sos_card.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

/// SOS Received List screen for Caregiver
class EmergencySOSReceivedListScreen extends StatefulWidget {
  const EmergencySOSReceivedListScreen({
    super.key,
    this.autoRefreshInterval = const Duration(seconds: 2),
    this.enableAutoRefresh = true,
  });

  final Duration autoRefreshInterval;
  final bool enableAutoRefresh;

  @override
  State<EmergencySOSReceivedListScreen> createState() =>
      _EmergencySOSReceivedListScreenState();
}

class _EmergencySOSReceivedListScreenState
    extends State<EmergencySOSReceivedListScreen>
    with WidgetsBindingObserver {
  bool _isInitialized = false;
  String _selectedStatus = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _autoRefreshTimer;
  bool _isAutoRefreshing = false;
  bool _pendingRefresh = false;

  Future<void> _refreshCurrentStatus({bool silent = true}) async {
    if (!mounted) return;

    if (_isAutoRefreshing) {
      _pendingRefresh = true;
      return;
    }

    _isAutoRefreshing = true;
    try {
      await context.read<EmergencyCaregiverProvider>().fetchSOSAlerts(
            _selectedStatus,
            silent: silent,
          );
    } finally {
      _isAutoRefreshing = false;
      if (_pendingRefresh && mounted) {
        _pendingRefresh = false;
        unawaited(_refreshCurrentStatus(silent: silent));
      }
    }
  }

  void _startAutoRefresh() {
    if (!widget.enableAutoRefresh) {
      return;
    }
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(widget.autoRefreshInterval, (_) {
      _refreshCurrentStatus(silent: true);
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      Future.microtask(() {
        if (mounted) {
          context.read<EmergencyCaregiverProvider>().fetchSOSAlerts('all');
          _startAutoRefresh();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.enableAutoRefresh) {
        _startAutoRefresh();
      }
      _refreshCurrentStatus(silent: true);
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopAutoRefresh();
    }
  }

  void _onStatusChanged(String status) {
    setState(() {
      _selectedStatus = status;
    });
    _refreshCurrentStatus(silent: false);
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('emergency-sos-list-screen'),
      backgroundColor: AppColors.bgPrimary,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gapLg,
              AppSpacing.gapLg,
              AppSpacing.gapLg,
              AppSpacing.gapMd,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppRadii.radiusMd),
              ),
              child: TextField(
                key: const ValueKey('sos-search-field'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên bệnh nhân...',
                  hintStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.cancel,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gapLg,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.gapLg,
              right: AppSpacing.gapLg,
              bottom: AppSpacing.gapMd,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'Tất cả', Icons.medication),
                  const SizedBox(width: AppSpacing.gapSm),
                  _buildFilterChip(
                      'active', 'Khẩn cấp', Icons.warning_rounded),
                  const SizedBox(width: AppSpacing.gapSm),
                  _buildFilterChip(
                      'resolved', 'Đã xử lý', Icons.check_circle),
                ],
              ),
            ),
          ),

          // SOS List
          Expanded(child: _buildSOSList()),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final bool isSelected = _selectedStatus == value;

    Color getChipColor() {
      if (!isSelected) return AppColors.bgSurface;
      switch (value) {
        case 'active':
          return AppColors.critical;
        case 'resolved':
          return AppColors.success;
        default:
          return AppColors.brandPrimary;
      }
    }

    return FilterChip(
      key: ValueKey('sos-filter-$value'),
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.bgSurface : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? AppColors.bgSurface
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
      onSelected: (selected) => _onStatusChanged(value),
      backgroundColor: AppColors.bgSurface,
      selectedColor: getChipColor(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.radiusXl),
        side: BorderSide(
          color: isSelected ? getChipColor() : AppColors.strokeSoft,
          width: isSelected ? 0 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      showCheckmark: false,
    );
  }

  Widget _buildSOSList() {
    return Consumer<EmergencyCaregiverProvider>(
      builder: (context, provider, child) {
        final filteredList = _filterList(
          provider.sosList,
          _selectedStatus,
          _searchQuery,
        );

        if (provider.isLoadingList && filteredList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.listErrorMessage != null && filteredList.isEmpty) {
          return _buildErrorState(provider.listErrorMessage!);
        }

        if (filteredList.isEmpty) {
          return _buildEmptyState();
        }

        final listView = RefreshIndicator(
          key: const ValueKey('sos-list-refresh'),
          onRefresh: () => provider.refreshSOSAlerts(_selectedStatus),
          child: ListView.builder(
            key: const ValueKey('sos-list-view'),
            itemCount: filteredList.length,
            padding:
                const EdgeInsets.symmetric(vertical: AppSpacing.gapMd),
            itemBuilder: (context, index) {
              final sos = filteredList[index];
              return SOSCard(
                key: ValueKey('sos-card-${sos.id}'),
                sos: sos,
                onTap: () async {
                  await Navigator.pushNamed(
                    context,
                    AppRouter.emergencySosDetail,
                    arguments: {'sosId': sos.id},
                  );
                  if (!mounted) return;
                  await _refreshCurrentStatus(silent: false);
                },
                onCallPressed: () =>
                    provider.makePhoneCall(sos.patient.phone),
                onMapPressed: () => provider.openMapNavigation(
                  sos.location.latitude,
                  sos.location.longitude,
                ),
              );
            },
          ),
        );

        if (!provider.isLoadingList) {
          return listView;
        }

        return Stack(
          children: [
            listView,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ],
        );
      },
    );
  }

  List _filterList(List sosList, String status, String searchQuery) {
    List filtered;
    if (status == 'all') {
      filtered = sosList;
    } else {
      filtered = sosList.where((sos) => sos.status == status).toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((sos) {
        final patientName = sos.patient.name.toLowerCase();
        final address = (sos.location.address ?? '').toLowerCase();
        return patientName.contains(searchQuery) ||
            address.contains(searchQuery);
      }).toList();
    }

    filtered.sort((a, b) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      return b.triggerTime.compareTo(a.triggerTime);
    });

    return filtered;
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: const ValueKey('sos-list-empty'),
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.gapLg),
                  Text(
                    'Không có SOS nào trong 30 ngày qua',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: const ValueKey('sos-list-error'),
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.critical),
                  const SizedBox(height: AppSpacing.gapLg),
                  Text(
                    message,
                    style: AppTextStyles.body.copyWith(color: AppColors.critical),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.gapLg),
                  ElevatedButton.icon(
                    onPressed: () {
                      context
                          .read<EmergencyCaregiverProvider>()
                          .fetchSOSAlerts(_selectedStatus);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
