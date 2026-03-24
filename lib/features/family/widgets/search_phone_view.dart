import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/family_repository.dart';
import '../models/user_search_model.dart';

class SearchPhoneView extends StatefulWidget {
  final Future<bool> Function(
    UserSearchModel user, {
    bool isCancel,
    bool isUnlink,
    bool isAccept,
    bool isReject,
  })
  onConnect;

  const SearchPhoneView({super.key, required this.onConnect});

  @override
  State<SearchPhoneView> createState() => _SearchPhoneViewState();
}

class _SearchPhoneViewState extends State<SearchPhoneView> {
  final TextEditingController _searchController = TextEditingController();
  final FamilyRepository _repository = FamilyRepository();

  Timer? _debounce;
  bool _isSearching = false;
  List<UserSearchModel> _results = [];
  final Set<int> _sentRequests =
      {}; // To track which users we've sent requests to

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _handleSearch();
    });
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    if (mounted) {
      setState(() {
        _isSearching = true;
        _results = [];
      });
    }

    try {
      final results = await _repository.searchUsers(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF5B7288)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Nhập số điện thoại cần tìm...',
                    hintStyle: TextStyle(
                      color: Color(0xFF90A3B6),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Loading Indicator (Skeleton)
        if (_isSearching) _buildSkeletonLoading(),

        // Search Result Card
        if (!_isSearching && _results.isNotEmpty)
          ..._results.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildResultCard(user),
            ),
          ),

        if (!_isSearching &&
            _results.isEmpty &&
            _searchController.text.trim().isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              'Không tìm thấy người dùng nào',
              style: TextStyle(color: Color(0xFF90A3B6)),
            ),
          ),
      ],
    );
  }

  Widget _buildSkeletonLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Skeleton Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Skeleton Name
                Container(
                  width: 120,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Skeleton Phone
                Container(
                  width: 80,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                // Skeleton Button
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(UserSearchModel user) {
    bool isPending =
        user.connectionStatus == 'pending' || _sentRequests.contains(user.id);
    bool isAccepted = user.connectionStatus == 'accepted';

    Color bgColor = const Color(0xFF0D92F4);
    Color fgColor = Colors.white;
    String btnText = 'Kết nối';

    if (isAccepted) {
      bgColor = Colors.red.shade50;
      fgColor = Colors.red.shade600;
      btnText = 'Đã kết nối';
    } else if (isPending) {
      bgColor = Colors.grey.shade300;
      fgColor = const Color(0xFF5B7288);
      btnText = 'Đã gửi (Hủy)';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFEEF4FF),
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(
                      fontSize: 28,
                      color: Color(0xFF2F80ED),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF12304A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.phone ?? user.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF90A3B6),
                  ),
                ),
                const SizedBox(height: 12),
                if (isPending && user.isIncoming)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final success = await widget.onConnect(
                              user,
                              isCancel: false,
                              isUnlink: false,
                              isAccept: true,
                              isReject: false,
                            );
                            if (success == true && mounted) {
                              _handleSearch();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D92F4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Xác nhận',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final success = await widget.onConnect(
                              user,
                              isCancel: false,
                              isUnlink: false,
                              isAccept: false,
                              isReject: true,
                            );
                            if (success == true && mounted) {
                              _handleSearch();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(color: Colors.red.shade600),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Từ chối',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (isAccepted) {
                          final success = await widget.onConnect(
                            user,
                            isCancel: false,
                            isUnlink: true,
                            isAccept: false,
                            isReject: false,
                          );
                          if (success == true && mounted) {
                            _handleSearch();
                          }
                        } else if (isPending) {
                          final success = await widget.onConnect(
                            user,
                            isCancel: true,
                            isUnlink: false,
                            isAccept: false,
                            isReject: false,
                          );
                          if (success == true && mounted) {
                            setState(() {
                              _sentRequests.remove(user.id);
                            });
                            _handleSearch();
                          }
                        } else {
                          final success = await widget.onConnect(
                            user,
                            isCancel: false,
                            isUnlink: false,
                            isAccept: false,
                            isReject: false,
                          );
                          if (success == true && mounted) {
                            setState(() {
                              _sentRequests.add(user.id);
                            });
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bgColor,
                        foregroundColor: fgColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        btnText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
