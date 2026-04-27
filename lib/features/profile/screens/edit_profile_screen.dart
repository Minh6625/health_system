import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/core/services/avatar_storage_service.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  final AvatarStorageService _avatarStorage = AvatarStorageService();

  DateTime? _selectedDate;
  String? _selectedGender;
  bool _initialized = false;
  File? _pickedAvatarFile;
  bool _isUploadingAvatar = false;

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
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildAvatarPicker(),
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

  Widget _buildAvatarPicker() {
    final hasPicked = _pickedAvatarFile != null;
    final currentUrl = _avatarController.text.trim();
    final hasUrl = currentUrl.isNotEmpty;

    ImageProvider? avatarImage;
    if (hasPicked) {
      avatarImage = FileImage(_pickedAvatarFile!);
    } else if (hasUrl) {
      avatarImage = NetworkImage(currentUrl);
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: AppColors.strokeSoft,
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Icon(
                      Icons.person_outline_rounded,
                      size: 56,
                      color: AppColors.textSecondary,
                    )
                  : null,
            ),
            if (_isUploadingAvatar)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: AppColors.bgSurface,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              )
            else
              Material(
                color: AppColors.brandPrimary,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _showAvatarPickerSheet,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                      color: AppColors.bgSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          hasPicked
              ? 'Ảnh mới đã chọn — bấm "Lưu thay đổi" để cập nhật.'
              : (hasUrl
                  ? 'Bấm biểu tượng máy ảnh để đổi ảnh đại diện.'
                  : 'Chưa có ảnh đại diện. Bấm máy ảnh để tải lên.'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _showAvatarPickerSheet() async {
    if (_isUploadingAvatar) return;
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.brandPrimary),
                title: const Text('Chụp ảnh'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.brandPrimary),
                title: const Text('Chọn từ thư viện'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              if (_avatarController.text.trim().isNotEmpty ||
                  _pickedAvatarFile != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: AppColors.critical),
                  title: const Text('Xóa ảnh hiện tại',
                      style: TextStyle(color: AppColors.critical)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      _pickedAvatarFile = null;
                      _avatarController.text = '';
                    });
                  },
                ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;
    await _pickAndUploadAvatar(source);
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final file = File(picked.path);
      setState(() {
        _pickedAvatarFile = file;
        _isUploadingAvatar = true;
      });

      final user = context.read<AuthProvider>().currentUser;
      if (user == null) {
        throw Exception('Chưa đăng nhập — không thể tải ảnh.');
      }

      final url = await _avatarStorage.uploadAvatar(
        file: file,
        userId: user.userId.toString(),
      );

      if (!mounted) return;
      setState(() {
        _avatarController.text = url;
        _isUploadingAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tải ảnh lên. Bấm "Lưu thay đổi" để xác nhận.'),
          backgroundColor: AppColors.brandPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
      });
      final message = e is AvatarUploadException
          ? e.message
          : 'Không thể tải ảnh: ${e.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.critical,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
