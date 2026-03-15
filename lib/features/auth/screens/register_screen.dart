import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final FocusNode _passwordFocusNode = FocusNode();
  
  DateTime? selectedDate;  // ngày sinh
  late final DateTime _minDateOfBirth = DateTime.now().subtract(const Duration(days: 365 * 16)); // At least 16 years old

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  
  bool _isPasswordComplete = false;
  bool _isConfirmPasswordMatch = true;
  bool _isConfirmPasswordPristine = true;
  
  bool _agreedToTerms = false;

  Future<void> handleRegister() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đồng ý với Điều khoản Sử dụng và Chính sách Bảo mật')),
      );
      return;
    }

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
  void initState() {
    super.initState();
    passwordController.addListener(_validatePassword);
    confirmPasswordController.addListener(_validateConfirmPassword);
    _passwordFocusNode.addListener(() {
      setState(() {});
    });
  }

  void _validatePassword() {
    final pass = passwordController.text;
    setState(() {
      _hasMinLength = pass.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(pass);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(pass);
      _hasNumber = RegExp(r'\d').hasMatch(pass);
      _hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass);
      
      _isPasswordComplete = _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSpecialChar;
    });
    if (!_isConfirmPasswordPristine) {
      _validateConfirmPassword();
    }
  }

  void _validateConfirmPassword() {
    final confirm = confirmPasswordController.text;
    setState(() {
      _isConfirmPasswordPristine = confirm.isEmpty;
      if (confirm.isEmpty) {
        _isConfirmPasswordMatch = true; 
      } else {
        _isConfirmPasswordMatch = confirm == passwordController.text;
      }
    });
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    emailController.dispose();
    fullNameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime lastDate = DateTime.now().subtract(const Duration(days: 365 * 16)); // Must be >= 16 years old
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? _minDateOfBirth,
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

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Điều khoản & Chính sách'),
          content: const SingleChildScrollView(
            child: Text(
              '1. Điều khoản Sử dụng:\n'
              '- Bạn phải cam kết sử dụng ứng dụng đúng mục đích y tế và không lạm dụng.\n'
              '- Thông tin của bạn cung cấp cần được đảm bảo là chính xác.\n\n'
              '2. Chính sách Bảo mật:\n'
              '- Chúng tôi cam kết bảo mật mọi dữ liệu cá nhân của bạn.\n'
              '- Dữ liệu sức khỏe chỉ được chia sẻ với những người chăm sóc mà bạn đã uỷ quyền.\n'
              '- Chúng tôi không bán dữ liệu của bạn cho bất kỳ bên thứ ba nào.\n\n'
              '(Đây là nội dung bản tóm tắt mẫu. Bạn có thể cập nhật chi tiết hơn trong tương lai.)',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Đóng'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isMet ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
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
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\p{L}\s]', unicode: true)),
                  ],
                  validator: (value) {
                    final input = value?.trim() ?? '';
                    if (input.isEmpty) return 'Vui lòng nhập họ tên';
                    if (input.length < 2) {
                      return 'Họ tên phải có ít nhất 2 ký tự';
                    }
                    if (input.length > 100) {
                      return 'Họ tên không thể vượt quá 100 ký tự';
                    }
                    // Validate: only letters, Unicode characters (for all VN diacritics), and spaces
                    final nameRegex = RegExp(r'^[\p{L}\s]+$', unicode: true);
                    if (!nameRegex.hasMatch(input)) {
                      return 'Họ tên chỉ được chứa chữ cái. Không được phép dùng số hoặc ký tự đặc biệt';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Date of Birth Picker
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: FormField(
                    validator: (value) {
                      if (selectedDate == null) {
                        return 'Vui lòng chọn ngày sinh';
                      }
                      final age = DateTime.now().difference(selectedDate!).inDays ~/ 365;
                      if (age < 16) {
                        return 'Bạn phải đủ 16 tuổi để đăng ký';
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
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;  // Optional field
                    }
                    final phone = value.trim();
                    if (!RegExp(r'^\d+$').hasMatch(phone)) {
                      return 'Số điện thoại chỉ được chứa ký tự số';
                    }
                    if (phone.length < 10 || phone.length > 11) {
                      return 'Số điện thoại phải có từ 10 đến 11 chữ số';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                AuthTextField(
                  label: 'Mật khẩu',
                  icon: Icons.lock,
                  controller: passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  borderColor: _isPasswordComplete ? Colors.green : null,
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
                const SizedBox(height: 8),
                if (_passwordFocusNode.hasFocus)
                  Column(
                    children: [
                       _buildRequirementRow('Ít nhất 8 ký tự', _hasMinLength),
                       _buildRequirementRow('Ít nhất 1 chữ in hoa', _hasUppercase),
                       _buildRequirementRow('Ít nhất 1 chữ in thường', _hasLowercase),
                       _buildRequirementRow('Ít nhất 1 chữ số', _hasNumber),
                       _buildRequirementRow('Ít nhất 1 ký tự đặc biệt', _hasSpecialChar),
                    ],
                  ),
                if (_passwordFocusNode.hasFocus)
                  const SizedBox(height: 16),
                AuthTextField(
                  label: 'Xác nhận mật khẩu',
                  icon: Icons.lock_outline,
                  controller: confirmPasswordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  borderColor: _isConfirmPasswordPristine ? null : (_isConfirmPasswordMatch ? Colors.green : Colors.red),
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
                if (!_isConfirmPasswordPristine && !_isConfirmPasswordMatch)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, left: 12.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Mật khẩu xác nhận không khớp',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (bool? value) {
                        setState(() {
                          _agreedToTerms = value ?? false;
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showTermsDialog(context),
                        child: Text.rich(
                          TextSpan(
                            text: 'Tôi đồng ý với ',
                            style: const TextStyle(fontSize: 14),
                            children: [
                              TextSpan(
                                text: 'Điều khoản Sử dụng',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' và '),
                              TextSpan(
                                text: 'Chính sách Bảo mật',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'ĐĂNG KÝ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
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
