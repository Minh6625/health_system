
$content = @"
import `'dart:async`';
import `'package:flutter/material.dart`';
import `'package:provider/provider.dart`';

import `'../models/relationship.dart`';
import `'../models/user_search_result.dart`';
import `'../providers/target_profile_provider.dart`';
import `'package:healthguard/features/profile/providers/profile_provider.dart`';

class UserSearchTab extends StatefulWidget {
  const UserSearchTab({Key? key}) : super(key: key);

  @override
  State<UserSearchTab> createState() => _UserSearchTabState();
}

class _UserSearchTabState extends State<UserSearchTab> {
  Timer? _debounce;
  final _searchController = TextEditingController();
  List<UserSearchResult> _searchResults = [];
  bool _isSearching = false;
  final Set<int> _sentRequestUserIds = {};
  
  // Trạng thái cục bộ cho nút Xóa
  final Set<int> _deletedRelationshipIds = {};
  final Set<int> _acceptedRelationshipIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = query.trim().isNotEmpty;
    });

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final familyProvider = Provider.of<TargetProfileProvider>(context, listen: false);
      final dynamicResults = await familyProvider.searchUsers(query);
      final List<UserSearchResult> results = List<UserSearchResult>.from(dynamicResults);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi tìm kiếm: `$e')));
      }
    }
  }

  void _sendRequest(UserSearchResult user) async {
    setState(() {
      _sentRequestUserIds.add(user.id);
    });

    try {
      final familyProvider = Provider.of<TargetProfileProvider>(context, listen: false);
      final success = await familyProvider.requestAccess(user.email, background: true);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu theo dõi')));
          familyProvider.fetchProfiles();
        } else {
          setState(() {
            _sentRequestUserIds.remove(user.id);
          });
          final error = familyProvider.errorMessage ?? 'Gửi yêu cầu thất bại';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sentRequestUserIds.remove(user.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: `$e')));
      }
    }
  }

  Widget _buildPendingInItem(Relationship relationship, TargetProfileProvider provider) {
    final bool isAccepted = _acceptedRelationshipIds.contains(relationship.id);
    final bool isDeleted = _deletedRelationshipIds.contains(relationship.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade100,
          child: Text(
            relationship.caregiverName.isNotEmpty ? relationship.caregiverName[0].toUpperCase() : 'U',
            style: TextStyle(color: Colors.teal.shade800),
          ),
        ),
        title: Text(relationship.caregiverName),
        subtitle: Text('`${relationship.caregiverEmail} muốn xem thông tin y tế của bạn'),
        trailing: isDeleted
            ? const Text('Đã xóa', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            : isAccepted
                ? const Text('Đã đồng ý', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () async {
                          setState(() {
                            _acceptedRelationshipIds.add(relationship.id);
                          });
                          await provider.acceptRequest(relationship.id, background: true);
                        },
                      ),
                      TextButton(
                        onPressed: () async {
                          setState(() {
                            _deletedRelationshipIds.add(relationship.id);
                          });
                          await provider.removeRelationship(relationship.id, background: true);
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Xóa'),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPendingOutItem(Relationship relationship, TargetProfileProvider provider) {
    final bool isDeleted = _deletedRelationshipIds.contains(relationship.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Text(
            relationship.patientName.isNotEmpty ? relationship.patientName[0].toUpperCase() : 'U',
            style: TextStyle(color: Colors.orange.shade800),
          ),
        ),
        title: Text(relationship.patientName),
        subtitle: Text('Đang chờ xác nhận từ `${relationship.patientEmail}...'),
        trailing: isDeleted
            ? const Text('Đã xóa', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            : TextButton(
                onPressed: () async {
                  setState(() {
                    _deletedRelationshipIds.add(relationship.id);
                  });
                  await provider.removeRelationship(relationship.id, background: true);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final targetProvider = Provider.of<TargetProfileProvider>(context);
    
    final myId = profileProvider.profile?.userId;
    final pendingIn = targetProvider.relationships
        .where((r) => r.status == 'pending' && r.patientId == myId)
        .toList();
    final pendingOut = targetProvider.relationships
        .where((r) => r.status == 'pending' && r.caregiverId == myId)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Nhập email, SDT, hoặc tên...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            ),
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
          ),
        ),
        Expanded(
          child: _isSearching
              ? _searchResults.isEmpty
                  ? const Center(child: Text('Không tìm thấy người dùng nào.'))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        String initials = '?';
                        if (user.fullName != null && user.fullName!.isNotEmpty) {
                          initials = user.fullName![0].toUpperCase();
                        } else if (user.email.isNotEmpty) {
                          initials = user.email[0].toUpperCase();
                        }
                        return ListTile(
                          leading: CircleAvatar(child: Text(initials)),
                          title: Text(user.fullName ?? user.email),
                          subtitle: Text([if (user.phone != null) user.phone, user.email].join(' • ')),
                          trailing: ElevatedButton(
                            onPressed: _sentRequestUserIds.contains(user.id) ? null : () => _sendRequest(user),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(_sentRequestUserIds.contains(user.id) ? 'Đã gửi' : 'Gửi liên kết'),
                          ),
                        );
                      },
                    )
              : RefreshIndicator(
                  onRefresh: () => targetProvider.fetchProfiles(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (pendingIn.isNotEmpty) ...[
                        const Text('Yêu cầu chờ xác nhận', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                        const SizedBox(height: 8),
                        ...pendingIn.map((r) => _buildPendingInItem(r, targetProvider)),
                        const SizedBox(height: 24),
                      ],
                      if (pendingOut.isNotEmpty) ...[
                        const Text('Yêu cầu bạn đã gửi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                        const SizedBox(height: 8),
                        ...pendingOut.map((r) => _buildPendingOutItem(r, targetProvider)),
                        const SizedBox(height: 24),
                      ],
                      if (pendingIn.isEmpty && pendingOut.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('Không có yêu cầu liên kết nào'),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
"@
Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\search_user_screen.dart" -Value $content

