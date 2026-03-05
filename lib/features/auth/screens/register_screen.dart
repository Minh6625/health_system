import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/models/user_model.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/widgets/auth_text_field.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  
  String selectedRole = 'patient';  // patient | caregiver
  DateTime? selectedDate;  // ngày sinh
  late final DateTime _minDateOfBirth = DateTime.now().subtract(const Duration(days: 365 * 18)); // At least 18 years old

  Future<void> handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final email = emailController.text.trim();
    final fullName = fullNameController.text.trim();
    final password = passwordController.text.trim();
    final phone = phoneController.text.trim();

    final user = UserModel(
      email: email,
      fullName: fullName,
      password: password,
      role: selectedRole,
      dateOfBirth: selectedDate,
      phone: phone.isEmpty ? null : phone,
    );
    final success = await authProvider.register(user);

    if (!mounted) {
      return;
    }

    final message = authProvider.message ?? 'Đăng ký thất bại';

    if (success) {
      authProvider.clearMessage();
      // Navigate to verification waiting screen
      Navigator.pushReplacementNamed(
        context,
        AppRouter.verifyEmail,
        arguments: {'email': email},
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    fullNameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, String role) async {
    // Patient: past to now | Caregiver: must be >= 18 years old
    final DateTime lastDate = role == 'caregiver'
        ? DateTime.now().subtract(const Duration(days: 365 * 18))
        : DateTime.now();
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? (role == 'caregiver' ? _minDateOfBirth : DateTime.now().subtract(const Duration(days: 365 * 20))),
      firstDate: DateTime(1900),
      lastDate: lastDate,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Xác nhận',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                AuthTextField(
                  label: 'Email',
                  icon: Icons.email,
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final input = value?.trim() ?? '';
                    if (input.isEmpty) return 'Vui lòng nhập email';
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!emailRegex.hasMatch(input)) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Họ tên',
                  icon: Icons.person,
                  controller: fullNameController,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final input = value?.trim() ?? '';
                    if (input.isEmpty) return 'Vui lòng nhập họ tên';
                    if (input.length < 2) {
                      return 'Họ tên phải có ít nhất 2 ký tự';
                    }
                    if (input.length > 100) {
                      return 'Họ tên không thể vượt quá 100 ký tự';
                    }
                    // Validate: only letters, Vietnamese diacritics, and spaces
                    final nameRegex = RegExp(r'^[a-zA-ZÀ-ỿ\s]+$');
                    if (!nameRegex.hasMatch(input)) {
                      return 'Họ tên chỉ được chứa chữ cái. Không được phép dùng số hoặc ký tự đặc biệt';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Date of Birth Picker
                GestureDetector(
                  onTap: () => _selectDate(context, selectedRole),
                  child: FormField(
                    validator: (value) {
                      if (selectedDate == null) {
                        return 'Vui lòng chọn ngày sinh';
                      }
                      // Only check age requirement for caregiver role
                      if (selectedRole == 'caregiver') {
                        final age = DateTime.now().difference(selectedDate!).inDays ~/ 365;
                        if (age < 18) {
                          return 'Người chăm sóc phải đủ 18 tuổi để đăng ký';
                        }
                      }
                      return null;
                    },
                    builder: (FormFieldState state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Ngày sinh',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              errorText: state.errorText,
                            ),
                            child: Text(
                              selectedDate != null
                                  ? '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}'
                                  : 'Chọn ngày sinh',
                              style: TextStyle(
                                fontSize: 16,
                                color: selectedDate != null
                                    ? Colors.black87
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Phone Number Input
                AuthTextField(
                  label: 'Số điện thoại',
                  icon: Icons.phone,
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;  // Optional field
                    }
                    final phone = value.replaceAll(RegExp(r'[^\d]'), '');
                    if (phone.length < 10 || phone.length > 15) {
                      return 'Số điện thoại phải có từ 10 đến 15 chữ số';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Vai trò',
                    prefixIcon: const Icon(Icons.security),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'patient',
                      child: const Text('Bệnh nhân'),
                    ),
                    DropdownMenuItem(
                      value: 'caregiver',
                      child: const Text('Người chăm sóc'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value ?? 'patient';
                      // If switching to caregiver, reset date if person is younger than 18
                      if (selectedRole == 'caregiver' && selectedDate != null) {
                        final age = DateTime.now().difference(selectedDate!).inDays ~/ 365;
                        if (age < 18) {
                          selectedDate = _minDateOfBirth; // Reset to 18-year-old date
                        }
                      }
                    });
                  },
                  menuMaxHeight: 150,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Mật khẩu',
                  icon: Icons.lock,
                  controller: passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    if (value.length < 8) {
                      return 'Mật khẩu phải có ít nhất 8 ký tự';
                    }
                    if (!RegExp(r'[A-Z]').hasMatch(value)) {
                      return 'Mật khẩu phải chứa ít nhất 1 ký tự in hoa';
                    }
                    if (!RegExp(r'[a-z]').hasMatch(value)) {
                      return 'Mật khẩu phải chứa ít nhất 1 ký tự in thường';
                    }
                    if (!RegExp(r'\d').hasMatch(value)) {
                      return 'Mật khẩu phải chứa ít nhất 1 chữ số';
                    }
                    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                      return 'Mật khẩu phải chứa ít nhất 1 ký tự đặc biệt';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Xác nhận mật khẩu',
                  icon: Icons.lock_outline,
                  controller: confirmPasswordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng xác nhận mật khẩu';
                    }
                    if (value != passwordController.text) {
                      return 'Mật khẩu xác nhận không khớp';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('ĐĂNG KÝ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
