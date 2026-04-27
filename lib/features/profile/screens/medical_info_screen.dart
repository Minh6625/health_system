import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:healthguard/features/profile/widgets/profile_widgets.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';

class MedicalInfoScreen extends StatefulWidget {
  const MedicalInfoScreen({super.key});

  @override
  State<MedicalInfoScreen> createState() => _MedicalInfoScreenState();
}

class _MedicalInfoScreenState extends State<MedicalInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _allergiesController = TextEditingController();

  String? _selectedBloodType;
  final Set<String> _selectedConditions = {};
  bool _initialized = false;

  static const _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  static const _medicalConditionLabels = {
    'hypertension': 'Cao huyết áp',
    'heart_disease': 'Bệnh tim mạch',
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
        _selectedBloodType = profile.bloodType;
        if (profile.heightCm != null) {
          // Whole-cm only (DB smallint).
          _heightController.text = profile.heightCm!.toString();
        }
        if (profile.weightKg != null) {
          _weightController.text = profile.weightKg!.toStringAsFixed(1);
        }
        _medicationsController.text = profile.medications.join(', ');
        _allergiesController.text = profile.allergies.join(', ');
        _selectedConditions.addAll(profile.medicalConditions);
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _medicationsController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  List<String> _parseCommaList(String text) {
    return text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    // Pull current profile data for unchanged fields
    final provider = context.read<ProfileProvider>();
    final existing = provider.profile;
    if (existing == null) return;

    final success = await provider.updateProfile(
      fullName: existing.fullName,
      phone: existing.phone,
      dateOfBirth: existing.dateOfBirth,
      avatarUrl: existing.avatarUrl,
      gender: existing.gender,
      bloodType: _selectedBloodType,
      heightCm: _heightController.text.trim().isEmpty
          ? null
          : int.tryParse(_heightController.text.trim()),
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
          content: Text('Đã lưu thông tin y tế'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Lưu thất bại. Vui lòng thử lại.'),
          backgroundColor: AppColors.critical,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Thử lại',
            textColor: AppColors.bgSurface,
            onPressed: _handleSave,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        // Show loading skeleton while profile is being fetched
        if (provider.isLoading && provider.profile == null) {
          return Scaffold(
            backgroundColor: AppColors.bgPrimary,
            appBar: _buildAppBar(provider),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: _buildAppBar(provider),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Warning Note ────────────────────────────────────
                  _WarningNote(
                    icon: Icons.verified_user_outlined,
                    text:
                        'Thông tin y tế chỉ được chia sẻ với bác sĩ hoặc người chăm sóc được bạn ủy quyền.',
                  ),
                  const SizedBox(height: 20),

                  // ── Chỉ số cơ thể ───────────────────────────────────
                  const ProfileSectionLabel('Chỉ số cơ thể'),
                  ProfileSectionCard(
                    child: Column(
                      children: [
                        _FormField(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedBloodType,
                            decoration:
                                _inputDecor('Nhóm máu', Icons.bloodtype_outlined),
                            style: const TextStyle(
                                fontSize: 16, color: AppColors.textPrimary),
                            items: _bloodTypes
                                .map((b) =>
                                    DropdownMenuItem(value: b, child: Text(b)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedBloodType = v),
                          ),
                        ),
                        _FormField(
                          child: TextFormField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 16),
                            // DB column is `smallint`; only whole-cm allowed.
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration:
                                _inputDecor('Chiều cao (cm)', Icons.height_outlined),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final val = int.tryParse(v.trim());
                              if (val == null) return 'Nhập số nguyên hợp lệ';
                              if (val < 50 || val > 250) {
                                return 'Chiều cao phải từ 50 – 250 cm';
                              }
                              return null;
                            },
                          ),
                        ),
                        _FormField(
                          isLast: true,
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 16),
                            decoration: _inputDecor(
                                'Cân nặng (kg)', Icons.monitor_weight_outlined),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final val = double.tryParse(v.trim());
                              if (val == null) return 'Nhập số hợp lệ';
                              if (val < 2 || val > 500) {
                                return 'Cân nặng phải từ 2 – 500 kg';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Thuốc & Dị ứng ──────────────────────────────────
                  const ProfileSectionLabel('Thuốc & Dị ứng'),
                  ProfileSectionCard(
                    child: Column(
                      children: [
                        _FormField(
                          child: TextFormField(
                            controller: _medicationsController,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 16),
                            decoration: _inputDecor(
                              'Thuốc đang dùng (phân cách bằng dấu phẩy)',
                              Icons.medication_outlined,
                            ),
                          ),
                        ),
                        _FormField(
                          isLast: true,
                          child: TextFormField(
                            controller: _allergiesController,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(fontSize: 16),
                            decoration: _inputDecor(
                              'Dị ứng (phân cách bằng dấu phẩy)',
                              Icons.warning_amber_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Tiền sử bệnh lý ─────────────────────────────────
                  const ProfileSectionLabel('Tiền sử bệnh lý'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppStateColors.warningBg,
                      borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                      border:
                          Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppColors.warning, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tiền sử bệnh lý ảnh hưởng đến điểm đánh giá rủi ro sức khoẻ AI.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.warning
                                    .withValues(alpha: 0.9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ProfileSectionCard(
                    child: Column(
                      children: _medicalConditionLabels.entries.map((e) {
                        return CheckboxListTile(
                          title: Text(e.value,
                              style: const TextStyle(fontSize: 15)),
                          value: _selectedConditions.contains(e.key),
                          activeColor: AppColors.brandPrimary,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selectedConditions.add(e.key);
                            } else {
                              _selectedConditions.remove(e.key);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Error message ────────────────────────────────────
                  if (provider.errorMessage != null && !provider.isSaving)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        provider.errorMessage!,
                        style: TextStyle(
                            color: AppColors.critical, fontSize: 13),
                      ),
                    ),

                  // ── Save CTA ─────────────────────────────────────────
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
                        provider.isSaving ? 'Đang lưu…' : 'Lưu thông tin',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.bgSurface,
                        disabledBackgroundColor: AppColors.brandPrimary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.radiusMd)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.strokeSoft),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.radiusMd)),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                            fontSize: 16, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(ProfileProvider provider) {
    return AppBar(
      title: const Text('Thông tin y tế'),
      backgroundColor: AppColors.brandPrimary,
      foregroundColor: AppColors.bgSurface,
      elevation: 0,
      actions: [
        if (provider.isSaving)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.bgSurface),
              ),
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.brandPrimary, size: 20),
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

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final Widget child;
  final bool isLast;

  const _FormField({required this.child, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, isLast ? 16 : 0),
      child: child,
    );
  }
}

class _WarningNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WarningNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppStateColors.infoBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.info.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );
  }
}
