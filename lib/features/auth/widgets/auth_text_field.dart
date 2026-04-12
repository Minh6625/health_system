import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';

class AuthTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Color? borderColor;
  final FocusNode? focusNode;
  final Color? fillColor;

  const AuthTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.borderColor,
    this.focusNode,
    this.fillColor,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.label,
        filled: true,
        fillColor: widget.fillColor ?? AppColors.bgSurface,
        prefixIcon: Icon(widget.icon, color: widget.borderColor),
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: widget.borderColor),
                onPressed: () {
                  setState(() {
                    _obscure = !_obscure;
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.radiusMd),
          borderSide: widget.borderColor != null
              ? BorderSide(color: widget.borderColor!, width: 1.5)
              : const BorderSide(),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.radiusMd),
          borderSide: widget.borderColor != null
              ? BorderSide(color: widget.borderColor!, width: 1.5)
              : BorderSide(color: AppColors.strokeSoft, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.radiusMd),
          borderSide: BorderSide(color: widget.borderColor ?? AppColors.brandPrimary, width: 2),
        ),
      ),
    );
  }
}
