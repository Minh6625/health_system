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
    extends State<EmergencySOSReceivedListScreen> {
  bool _isInitialized = false;
  String _selectedStatus = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
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
      // Fetch initial data immediately
      context.read<EmergencyCaregiverProvider>().fetchSOSAlerts('all');
    }
  }

  void _onStatusChanged(String status) {
    setState(() {
      _selectedStatus = status;
    });
    context.read<EmergencyCaregiverProvider>().fetchSOSAlerts(status);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      appBar: AppBar(
        title: const Text('Danh sách SOS nhận được'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên bệnh nhân...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[600],
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.cancel,
                            size: 20,
                            color: Colors.grey[500],
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'Tất cả', Icons.medication),
                  const SizedBox(width: 8),
                  _buildFilterChip('active', 'Khẩn cấp', Icons.warning_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('resolved', 'Đã xử lý', Icons.check_circle),
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
      if (!isSelected) return Colors.white;
      switch (value) {
        case 'active':
          return const Color(0xFFE53935); // Red for active
        case 'resolved':
          return const Color(0xFF43A047); // Green for resolved
        default:
          return const Color(0xFF1976D2); // Blue for all
      }
    }

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ],
      ),
      onSelected: (selected) => _onStatusChanged(value),
      backgroundColor: Colors.white,
      selectedColor: getChipColor(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? getChipColor() : Colors.grey.shade300,
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
        // Loading state
        if (provider.isLoadingList) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (provider.listErrorMessage != null) {
          return _buildErrorState(provider.listErrorMessage!);
        }

        // Filter list based on status and search query
        final filteredList = _filterList(
          provider.sosList,
          _selectedStatus,
          _searchQuery,
        );

        // Empty state
        if (filteredList.isEmpty) {
          return _buildEmptyState();
        }

        // Success state
        return RefreshIndicator(
          onRefresh: () => provider.refreshSOSAlerts(_selectedStatus),
          child: ListView.builder(
            itemCount: filteredList.length,
            padding: const EdgeInsets.symmetric(vertical: 12),
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

  List _filterList(List sosList, String status, String searchQuery) {
    // Filter by status
    List filtered;
    if (status == 'all') {
      filtered = sosList;
    } else {
      filtered = sosList.where((sos) => sos.status == status).toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((sos) {
        final patientName = sos.patient.name.toLowerCase();
        final address = (sos.location.address ?? '').toLowerCase();
        return patientName.contains(searchQuery) ||
            address.contains(searchQuery);
      }).toList();
    }

    // Sort: Active SOS first, then by trigger time (newest first)
    filtered.sort((a, b) {
      // Priority 1: Active status first
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      // Priority 2: Newest first
      return b.triggerTime.compareTo(a.triggerTime);
    });

    return filtered;
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
              context.read<EmergencyCaregiverProvider>().fetchSOSAlerts(
                _selectedStatus,
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
