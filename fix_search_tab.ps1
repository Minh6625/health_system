
$content = @"
import `'dart:async`';
import `'package:flutter/material.dart`';
import `'package:provider/provider.dart`';

import `'../models/user_search_result.dart`';
import `'../providers/target_profile_provider.dart`';

class UserSearchTab extends StatefulWidget {
  const UserSearchTab({Key? key}) : super(key: key);

  @override
  State<UserSearchTab> createState() => _UserSearchTabState();
}

class _UserSearchTabState extends State<UserSearchTab> {
  Timer? _debounce;

  final _searchController = TextEditingController();
  List<UserSearchResult> _searchResults = [];
  bool _isLoading = false;
  final Set<int> _sentRequestUserIds = {};

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
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

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
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tìm kiếm: `$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sendRequest(UserSearchResult user) async {
    try {
      final familyProvider = Provider.of<TargetProfileProvider>(
        context,
        listen: false,
      );
      final success = await familyProvider.requestAccess(user.email);
      if (mounted) {
        if (success) {
          setState(() {
            _sentRequestUserIds.add(user.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi yêu cầu theo dõi')),
          );
        } else {
          final error = familyProvider.errorMessage ?? 'Gửi yêu cầu thất bại';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: `$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 0,
              ),
            ),
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
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
                          subtitle: Text(
                            [
                              if (user.phone != null) user.phone,
                              user.email,
                            ].join(' • '),
                          ),
                          trailing: ElevatedButton(
                            onPressed: _sentRequestUserIds.contains(user.id)
                                ? null
                                : () => _sendRequest(user),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              _sentRequestUserIds.contains(user.id)
                                  ? 'Đã gửi'
                                  : 'Gửi liên kết',
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
"@
Set-Content "C:\Dev\Project2\health_system\lib\features\family\screens\search_user_screen.dart" -Value $content

