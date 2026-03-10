import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/features/emergency/widgets/sos_card.dart';
import 'package:healthguard/features/emergency/screens/emergency_sos_detail_screen.dart';

/// SOS Received List screen for Caregiver
class EmergencySOSReceivedListScreen extends StatefulWidget {
  const EmergencySOSReceivedListScreen({super.key});

  @override
  State<EmergencySOSReceivedListScreen> createState() =>
      _EmergencySOSReceivedListScreenState();
}

class _EmergencySOSReceivedListScreenState
    extends State<EmergencySOSReceivedListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmergencyCaregiverProvider>().fetchSOSAlerts('all');
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final status = _getStatusFromTabIndex(_tabController.index);
      context.read<EmergencyCaregiverProvider>().fetchSOSAlerts(status);
    }
  }

  String _getStatusFromTabIndex(int index) {
    switch (index) {
      case 0:
        return 'all';
      case 1:
        return 'active';
      case 2:
        return 'resolved';
      default:
        return 'all';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách SOS nhận được'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Đang hoạt động'),
            Tab(text: 'Đã xử lý'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSOSList(status: 'all'),
          _buildSOSList(status: 'active'),
          _buildSOSList(status: 'resolved'),
        ],
      ),
    );
  }

  Widget _buildSOSList({required String status}) {
    return Consumer<EmergencyCaregiverProvider>(
      builder: (context, provider, child) {
        // Loading state
        if (provider.isLoadingList) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (provider.listErrorMessage != null) {
          return _buildErrorState(provider.listErrorMessage!);
        }

        // Filter list based on current tab
        final filteredList = _filterList(provider.sosList, status);

        // Empty state
        if (filteredList.isEmpty) {
          return _buildEmptyState();
        }

        // Success state
        return RefreshIndicator(
          onRefresh: () => provider.refreshSOSAlerts(status),
          child: ListView.builder(
            itemCount: filteredList.length,
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemBuilder: (context, index) {
              final sos = filteredList[index];
              return SOSCard(
                sos: sos,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EmergencySOSDetailScreen(sosId: sos.id),
                  ),
                ),
                onCallPressed: () => provider.makePhoneCall(sos.patient.phone),
                onMapPressed: () => provider.openMapNavigation(
                  sos.location.latitude,
                  sos.location.longitude,
                ),
              );
            },
          ),
        );
      },
    );
  }

  List _filterList(List sosList, String status) {
    if (status == 'all') return sosList;
    return sosList.where((sos) => sos.status == status).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Không có SOS nào trong 30 ngày qua',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final status = _getStatusFromTabIndex(_tabController.index);
              context.read<EmergencyCaregiverProvider>().fetchSOSAlerts(status);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
