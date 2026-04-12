import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

// Thông tin y tế và tiền sử bệnh lý đã được tách sang MedicalInfoScreen.
// EditProfileScreen chỉ quản lý thông tin cá nhân cơ bản.

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGender;
  bool _initialized = false;

  static const _genders = ['Nam', 'Nữ', 'Khác'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final profile = context.read<ProfileProvider>().profile;
      if (profile != null) {
        _fullNameController.text = profile.fullName;
        _phoneController.text = profile.phone ?? '';
        _avatarController.text = profile.avatarUrl ?? '';
        _selectedDate = profile.dateOfBirth;
        _dobController.text = _formatDate(profile.dateOfBirth);
        _selectedGender = profile.gender;
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _avatarController.dispose();
    super.dispose();
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
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Xác nhận',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProfileProvider>();
    final existing = provider.profile;

    final success = await provider.updateProfile(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      dateOfBirth: _selectedDate,
      avatarUrl: _avatarController.text.trim().isEmpty
          ? null
          : _avatarController.text.trim(),
      gender: _selectedGender,
      // Giữ nguyên thông tin y tế hiện có – không thay đổi từ màn này
      bloodType: existing?.bloodType,
      heightCm: existing?.heightCm,
      weightKg: existing?.weightKg,
      medications: existing?.medications ?? [],
      allergies: existing?.allergies ?? [],
      medicalConditions: existing?.medicalConditions ?? [],
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thông tin thành công'),
          backgroundColor: AppColors.brandPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Cập nhật thất bại'),
          backgroundColor: AppColors.critical,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            title: const Text('Chỉnh sửa thông tin'),
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.bgSurface,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Thông tin cá nhân ──
                  _buildSectionTitle('Thông tin cá nhân'),
                  const SizedBox(height: 12),
                  _buildCard([
                    _buildField(
                      child: TextFormField(
                        controller: _fullNameController,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 16),
                        decoration:
                            _inputDecoration('Họ và tên', Icons.person_outline),
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.isEmpty) return 'Vui lòng nhập họ tên';
                          if (text.length < 2) return 'Họ tên phải từ 2 ký tự';
                          if (!RegExp(r'^[a-zA-ZÀ-ỿ\s]+$').hasMatch(text)) {
                            return 'Họ tên chỉ được chứa chữ cái';
                          }
                          return null;
                        },
                      ),
                    ),
                    _buildField(
                      child: TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        style: const TextStyle(fontSize: 16),
                        onTap: _pickDate,
                        decoration: _inputDecoration(
                          'Ngày sinh',
                          Icons.cake_outlined,
                          suffixIcon: const Icon(Icons.calendar_today_outlined,
                              size: 18),
                        ),
                      ),
                    ),
                    _buildField(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 16),
                        decoration: _inputDecoration(
                            'Số điện thoại', Icons.phone_outlined),
                        validator: (v) {
                          final text =
                              v?.replaceAll(RegExp(r'[\s-]'), '').trim() ?? '';
                          if (text.isEmpty) return null;
                          if (!RegExp(r'^\d+$').hasMatch(text)) {
                            return 'Số điện thoại chỉ được chứa chữ số';
                          }
                          if (text.length < 10 || text.length > 11) {
                            return 'Số điện thoại phải có 10-11 chữ số';
                          }
                          if (!text.startsWith('0')) {
                            return 'Số điện thoại VN phải bắt đầu bằng 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    _buildField(
                      isLast: true,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration:
                            _inputDecoration('Giới tính', Icons.wc_outlined),
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.textPrimary),
                        items: _genders
                            .map((g) =>
                                DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedGender = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // ── Ảnh đại diện ──
                  _buildSectionTitle('Ảnh đại diện'),
                  const SizedBox(height: 12),
                  _buildCard([
                    _buildField(
                      child: TextFormField(
                        controller: _avatarController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(fontSize: 16),
                        decoration: _inputDecoration(
                            'Đường dẫn ảnh (URL)', Icons.image_outlined),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final uri = Uri.tryParse(v.trim());
                          if (uri == null ||
                              !uri.hasScheme ||
                              !['http', 'https'].contains(uri.scheme)) {
                            return 'URL không hợp lệ (cần bắt đầu bằng http/https)';
                          }
                          return null;
                        },
                      ),
                    ),
                    if (_avatarController.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                          child: Image.network(
                            _avatarController.text.trim(),
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            cacheHeight: 300,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 100,
                                width: 100,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              );
                            },
                            errorBuilder: (_, _, _) => Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                color: AppColors.strokeSoft,
                                borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                              ),
                              child: Icon(Icons.broken_image_outlined,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                  ]),

                  if (provider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        provider.errorMessage!,
                        style: TextStyle(color: AppColors.critical),
                      ),
                    ),
                  const SizedBox(height: 28),

                  // ── CTA Lưu ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: provider.isSaving ? null : _handleSave,
                      icon: provider.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.bgSurface),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        provider.isSaving ? 'Đang lưu…' : 'Lưu thay đổi',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.bgSurface,
                        disabledBackgroundColor:
                            AppColors.brandPrimary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.radiusMd)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.brandPrimary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildField({required Widget child, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, isLast ? 16 : 4),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.brandPrimary, size: 20),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.radiusSm)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        borderSide: const BorderSide(color: AppColors.brandPrimary, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
