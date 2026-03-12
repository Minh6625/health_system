import 'package:flutter/material.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

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
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedBloodType;
  final Set<String> _selectedConditions = {};
  bool _initialized = false;

  static const _genders = ['Nam', 'Nữ', 'Khác'];
  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _medicalHistoryLabels = {
    'hypertension': 'Cao huyết áp',
    'heart_disease': 'Tim mạch',
    'diabetes': 'Tiểu đường',
    'stroke': 'Đột quỵ',
    'other': 'Khác',
  };

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
        _selectedBloodType = profile.bloodType;
        if (profile.heightCm != null) {
          _heightController.text = profile.heightCm!.toStringAsFixed(1);
        }
        if (profile.weightKg != null) {
          _weightController.text = profile.weightKg!.toStringAsFixed(1);
        }
        _medicationsController.text = profile.medications.join(', ');
        _allergiesController.text = profile.allergies.join(', ');
        // Restore medical conditions checkboxes
        _selectedConditions.addAll(profile.medicalConditions);
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
    _heightController.dispose();
    _weightController.dispose();
    _medicationsController.dispose();
    _allergiesController.dispose();
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

  List<dynamic> _parseCommaList(String text) {
    return text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProfileProvider>();
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
      bloodType: _selectedBloodType,
      heightCm: _heightController.text.trim().isEmpty
          ? null
          : double.tryParse(_heightController.text.trim()),
      weightKg: _weightController.text.trim().isEmpty
          ? null
          : double.tryParse(_weightController.text.trim()),
      medications: _medicationsController.text.trim().isEmpty
          ? []
          : _parseCommaList(_medicationsController.text),
      allergies: _allergiesController.text.trim().isEmpty
          ? []
          : _parseCommaList(_allergiesController.text),
      medicalConditions: _selectedConditions.toList(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thông tin thành công'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Cập nhật thất bại'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          appBar: AppBar(
            title: const Text('Chỉnh sửa thông tin'),
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
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
                        decoration: _inputDecoration('Họ và tên', Icons.person_outline),
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.isEmpty) return 'Vui lòng nhập họ tên';
                          if (text.length < 2) return 'Họ tên phải từ 2 ký tự';
                          if (!RegExp(r'^[a-zA-ZÀ-ỿ\s]+$').hasMatch(text)) {
                            return 'Họ tên chỉ được chứa chữ cái và khoảng trắng';
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
                          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                        ),
                      ),
                    ),
                    _buildField(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 16),
                        decoration: _inputDecoration('Số điện thoại', Icons.phone_outlined),
                        validator: (v) {
                          final text = v?.replaceAll(RegExp(r'[\s-]'), '').trim() ?? '';
                          if (text.isEmpty) return null;
                          if (!RegExp(r'^\d+$').hasMatch(text)) {
                            return 'Số điện thoại chỉ được chứa chữ số';
                          }
                          if (text.length < 10 || text.length > 11) {
                            return 'Số điện thoại phải có 10-11 chữ số';
                          }
                          if (!text.startsWith('0')) {
                            return 'Số điện thoại Việt Nam phải bắt đầu bằng 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    _buildField(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: _inputDecoration('Giới tính', Icons.wc_outlined),
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                        items: _genders
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedGender = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // ── Thông tin y tế ──
                  _buildSectionTitle('Thông tin y tế'),
                  const SizedBox(height: 12),
                  _buildCard([
                    _buildField(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBloodType,
                        decoration: _inputDecoration('Nhóm máu', Icons.bloodtype_outlined),
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                        items: _bloodTypes
                            .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedBloodType = v),
                      ),
                    ),
                    _buildField(
                      child: TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 16),
                        decoration: _inputDecoration('Chiều cao (cm)', Icons.height_outlined),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final val = double.tryParse(v.trim());
                          if (val == null) return 'Vui lòng nhập số hợp lệ';
                          if (val < 50 || val > 250) return 'Chiều cao phải từ 50 đến 250 cm';
                          return null;
                        },
                      ),
                    ),
                    _buildField(
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 16),
                        decoration: _inputDecoration('Cân nặng (kg)', Icons.monitor_weight_outlined),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final val = double.tryParse(v.trim());
                          if (val == null) return 'Vui lòng nhập số hợp lệ';
                          if (val < 2 || val > 500) return 'Cân nặng phải từ 2 đến 500 kg';
                          return null;
                        },
                      ),
                    ),
                    _buildField(
                      child: TextFormField(
                        controller: _medicationsController,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 16),
                        decoration: _inputDecoration(
                          'Thuốc đang dùng (cách nhau bởi dấu phẩy)',
                          Icons.medication_outlined,
                        ),
                      ),
                    ),
                    _buildField(
                      child: TextFormField(
                        controller: _allergiesController,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(fontSize: 16),
                        decoration: _inputDecoration(
                          'Dị ứng (cách nhau bởi dấu phẩy)',
                          Icons.warning_amber_outlined,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // ── Tiền sử bệnh lý ──
                  _buildSectionTitle('Tiền sử bệnh lý'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Thông tin tiền sử bệnh ảnh hưởng đến điểm đánh giá rủi ro sức khỏe AI.',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildCard(
                    _medicalHistoryLabels.entries.map((entry) {
                      return CheckboxListTile(
                        title: Text(entry.value, style: const TextStyle(fontSize: 15)),
                        value: _selectedConditions.contains(entry.key),
                        activeColor: const Color(0xFF0F766E),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedConditions.add(entry.key);
                          } else {
                            _selectedConditions.remove(entry.key);
                          }
                        }),
                      );
                    }).toList(),
                  ),
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
                        decoration: _inputDecoration('Đường dẫn ảnh (URL)', Icons.image_outlined),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final uri = Uri.tryParse(v.trim());
                          if (uri == null ||
                              !uri.hasScheme ||
                              !['http', 'https'].contains(uri.scheme)) {
                            return 'URL không hợp lệ (phải bắt đầu bằng http:// hoặc https://)';
                          }
                          return null;
                        },
                      ),
                    ),
                    if (_avatarController.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _avatarController.text.trim(),
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
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
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: provider.isSaving ? null : _handleSave,
                      icon: provider.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        provider.isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F766E),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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

  Widget _buildField({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF0F766E), size: 20),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
