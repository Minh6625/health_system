import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthguard/features/family/screens/user_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/relationship.dart';
import '../models/user_search_result.dart';
import '../providers/target_profile_provider.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';

class UserSearchTab extends StatefulWidget {
  final VoidCallback? onSwitchTab;
  const UserSearchTab({Key? key, this.onSwitchTab}) : super(key: key);

  @override
  State<UserSearchTab> createState() => _UserSearchTabState();
}

class _UserSearchTabState extends State<UserSearchTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Timer? _debounce;
  final _searchController = TextEditingController();
  List<UserSearchResult> _searchResults = [];
  bool _isSearching = false;
  final Set<int> _sentRequestUserIds = {};

  final Set<int> _deletedRelationshipIds = {};
  final Set<int> _acceptedRelationshipIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<ProfileProvider>().profile == null) {
        context.read<ProfileProvider>().fetchProfile();
      }
    });
  }

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
      final familyProvider = Provider.of<TargetProfileProvider>(
        context,
        listen: false,
      );
      final dynamicResults = await familyProvider.searchUsers(query);
      final List<UserSearchResult> results = List<UserSearchResult>.from(
        dynamicResults,
      );
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tìm kiếm: $e')));
      }
    }
  }

  void _sendRequest(UserSearchResult user) async {
    setState(() {
      _sentRequestUserIds.add(user.id);
    });

    try {
      final familyProvider = Provider.of<TargetProfileProvider>(
        context,
        listen: false,
      );
      final success = await familyProvider.requestAccess(
        user.email,
        background: true,
      );
      if (mounted) {
                if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi yêu cầu theo dõi')),
          );
          setState(() { 
            _sentRequestUserIds.remove(user.id); 
            _searchResults.clear();
            _isSearching = false;
          });
          _searchController.clear();
          context.read<TargetProfileProvider>().fetchProfiles(background: true);
        } else {
          setState(() {
            _sentRequestUserIds.remove(user.id);
          });
          final error = familyProvider.errorMessage ?? 'Gửi yêu cầu thất bại';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sentRequestUserIds.remove(user.id);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Widget _buildPendingInItem(
    Relationship relationship,
    TargetProfileProvider provider,
  ) {
    final bool isAccepted = _acceptedRelationshipIds.contains(relationship.id);
    final bool isDeleted = _deletedRelationshipIds.contains(relationship.id);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(
              userId: relationship.caregiverId,
              name: relationship.caregiverName,
              email: relationship.caregiverEmail,
            ),
            ),
          );
          if (result == true && mounted) {
            widget.onSwitchTab?.call();
          }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  relationship.caregiverName.isNotEmpty
                      ? relationship.caregiverName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relationship.caregiverName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      relationship.caregiverEmail,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isDeleted)
                      const Text(
                        'Đã xóa',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (isAccepted)
                      const Text(
                        'Đã đồng ý',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                setState(() {
                                  _deletedRelationshipIds.add(relationship.id);
                                });
                                await provider.removeRelationship(
                                  relationship.id,
                                  background: true,
                                );
                              if (mounted) { setState(() { _deletedRelationshipIds.remove(relationship.id); }); widget.onSwitchTab?.call(); }
                                },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(
                                  color: Colors.grey.shade400,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                widget.onSwitchTab?.call();
                                setState(() {
                                  _acceptedRelationshipIds.add(relationship.id);
                                });
                                provider.acceptRequest(
                                  relationship.id,
                                  background: false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Xác nhận',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingOutItem(
    Relationship relationship,
    TargetProfileProvider provider,
  ) {
    final bool isDeleted = _deletedRelationshipIds.contains(relationship.id);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(
              userId: relationship.patientId,
              name: relationship.patientName,
              email: relationship.patientEmail,
            ),
            ),
          );
          if (result == true && mounted) {
            widget.onSwitchTab?.call();
          }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.orange.shade100,
                child: Text(
                  relationship.patientName.isNotEmpty
                      ? relationship.patientName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relationship.patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      relationship.patientEmail,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isDeleted)
                      const Text(
                        'Đã xóa',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                setState(() {
                                  _deletedRelationshipIds.add(relationship.id);
                                });
                                await provider.removeRelationship(
                                  relationship.id,
                                  background: true,
                                );
                              if (mounted) { setState(() { _deletedRelationshipIds.remove(relationship.id); }); widget.onSwitchTab?.call(); }
                                },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(
                                  color: Colors.grey.shade400,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Hủy yêu cầu',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final targetProvider = Provider.of<TargetProfileProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final currentUserId = profileProvider.profile?.userId;

    if (currentUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendingIn = targetProvider.relationships
        .where((r) => r.status == 'pending' && r.patientId == currentUserId)
        .toList();
    final pendingOut = targetProvider.relationships
        .where((r) => r.status == 'pending' && r.caregiverId == currentUserId)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm qua email...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
          if (_isSearching && _searchResults.isEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: 4,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(height: 16, width: 140, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Container(height: 14, width: 100, color: Colors.grey.shade300),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 36,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(16)
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: Colors.white54);
                },
              ),
            ),
        Expanded(
          child:
              _searchController.text.trim().isNotEmpty &&
                  _searchResults.isNotEmpty
              ? ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final initials = user.fullName?.isNotEmpty == true
                        ? user.fullName![0].toUpperCase()
                        : 'U';

                    Widget buildAction() {
                      final isSentLocal = _sentRequestUserIds.contains(user.id);
                      final existingRels = targetProvider.relationships
                          .where(
                            (r) =>
                                (r.patientId == currentUserId &&
                                    r.caregiverId == user.id) ||
                                (r.caregiverId == currentUserId &&
                                    r.patientId == user.id),
                          )
                          .toList();

                      if (existingRels.isNotEmpty) {
                        final rel = existingRels.first;
                        
                        if (_deletedRelationshipIds.contains(rel.id) || _acceptedRelationshipIds.contains(rel.id)) {
                          return const Text(
                            'Đang xử lý...',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }

                        if (rel.status == 'accepted') {
                          return const Text(
                            'Đã liên kết',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        if (rel.status == 'pending') {
                          if (rel.caregiverId == currentUserId) {
                            return OutlinedButton(
                              onPressed: () async {
                                setState(() {
                                  _deletedRelationshipIds.add(rel.id);
                                });
                                await targetProvider.removeRelationship(
                                  rel.id,
                                  background: true,
                                );
                              if (mounted) { setState(() { _deletedRelationshipIds.remove(rel.id); }); widget.onSwitchTab?.call(); }
                                      },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(
                                  color: Colors.grey.shade400,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Hủy yêu cầu',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      setState(() {
                                        _deletedRelationshipIds.add(rel.id);
                                      });
                                      await targetProvider.removeRelationship(
                                        rel.id,
                                        background: true,
                                      );
                                    if (mounted) { setState(() { _deletedRelationshipIds.remove(rel.id); }); widget.onSwitchTab?.call(); }
                                      },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey.shade700,
                                      side: BorderSide(
                                        color: Colors.grey.shade400,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text(
                                      'Hủy',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                widget.onSwitchTab?.call();
                                setState(() {
                                  _acceptedRelationshipIds.add(rel.id);
                                });
                                targetProvider.acceptRequest(
                                  rel.id,
                                  background: false,
                                );
                              },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Xác nhận',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                        }
                      }

                      if (isSentLocal) {
                        return const Text(
                          'Đang xử lý...',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }

                      return ElevatedButton(
                        onPressed: () => _sendRequest(user),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Gửi liên kết',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }

                    return GestureDetector(
                      onTap: () async {
        final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(
                              userId: user.id,
                              name: user.fullName ?? user.email,
                              email: user.email,
                              phone: user.phone,
                              avatarUrl: user.avatarUrl,
                            ),
            ),
          );
          if (result == true && mounted) {
            widget.onSwitchTab?.call();
          }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName ?? user.email,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: buildAction()),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
                        const Text(
                          'Yêu cầu chờ xác nhận',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...pendingIn.map(
                          (r) => _buildPendingInItem(r, targetProvider),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (pendingOut.isNotEmpty) ...[
                        const Text(
                          'Yêu cầu bạn đã gửi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...pendingOut.map(
                          (r) => _buildPendingOutItem(r, targetProvider),
                        ),
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
