import 'package:flutter/material.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();

  DateTime? _selectedDate;
  String? _lastSyncedProfileKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileProvider>().fetchProfile();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  void _syncFormFromProfile(ProfileProvider profileProvider) {
    final profile = profileProvider.profile;
    if (profile == null) return;

    final currentKey =
        '${profile.userId}-${profile.updatedAt.toIso8601String()}';
    if (_lastSyncedProfileKey == currentKey) return;

    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phone ?? '';
    _avatarController.text = profile.avatarUrl ?? '';
    _selectedDate = profile.dateOfBirth;
    _dobController.text = _formatDate(profile.dateOfBirth);
    _lastSyncedProfileKey = currentKey;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate =
        _selectedDate ?? DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Chon ngay sinh',
      cancelText: 'Huy',
      confirmText: 'Chon',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _handleSave(ProfileProvider profileProvider) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await profileProvider.updateProfile(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      dateOfBirth: _selectedDate,
      avatarUrl: _avatarController.text.trim().isEmpty
          ? null
          : _avatarController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Cap nhat thong tin thanh cong'
              : (profileProvider.errorMessage ?? 'Cap nhat that bai'),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Xac nhan dang xuat'),
          content: const Text('Ban co chac chan muon dang xuat khong?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Huy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Dang xuat'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        _syncFormFromProfile(profileProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Thong tin ca nhan'),
            backgroundColor: Colors.blue.shade700,
            actions: [
              IconButton(
                onPressed: profileProvider.isLoading
                    ? null
                    : () => context.read<ProfileProvider>().fetchProfile(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _buildBody(profileProvider),
        );
      },
    );
  }

  Widget _buildBody(ProfileProvider profileProvider) {
    if (profileProvider.isLoading && profileProvider.profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(profileProvider: profileProvider),
            const SizedBox(height: 16),
            const Text(
              'Cai dat tai khoan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Ho va ten',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 2) return 'Ho ten phai tu 2 ky tu';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'So dien thoai',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text =
                    value?.replaceAll(RegExp(r'\s|-'), '').trim() ?? '';
                if (text.isEmpty) return null;
                if (text.length < 10 ||
                    text.length > 15 ||
                    RegExp(r'\D').hasMatch(text)) {
                  return 'So dien thoai phai tu 10 den 15 chu so';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dobController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Ngay sinh',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _avatarController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Avatar URL',
                border: OutlineInputBorder(),
              ),
            ),
            if (profileProvider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  profileProvider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: profileProvider.isSaving
                    ? null
                    : () => _handleSave(profileProvider),
                icon: profileProvider.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  profileProvider.isSaving
                      ? 'Dang cap nhat...'
                      : 'Luu thay doi',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Dang xuat',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ProfileProvider profileProvider;

  const _InfoCard({required this.profileProvider});

  @override
  Widget build(BuildContext context) {
    final profile = profileProvider.profile;
    if (profile == null) return const SizedBox.shrink();

    final avatar = profile.avatarUrl;
    final trimmedName = profile.fullName.trim();
    final initial = trimmedName.isNotEmpty
        ? trimmedName.substring(0, 1).toUpperCase()
        : 'U';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? NetworkImage(avatar)
                : null,
            child: avatar == null || avatar.isEmpty
                ? Text(
                    initial,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.95)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatusChip(
                      label: profile.role.toUpperCase(),
                      color: Colors.indigo.shade100,
                      textColor: Colors.indigo.shade900,
                    ),
                    _StatusChip(
                      label: profile.isVerified
                          ? 'Da xac minh'
                          : 'Chua xac minh',
                      color: profile.isVerified
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      textColor: profile.isVerified
                          ? Colors.green.shade900
                          : Colors.orange.shade900,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
