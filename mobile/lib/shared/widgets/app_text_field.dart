import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? labelText;
  final String? hint;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool isObscure;
  final int? maxLength;
  final double borderRadius;
  final String? Function(String?)? validator;
  final String? helperText;
  final TextAlign textAlign;
  final TextStyle? style;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.labelText,
    this.hint,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.isObscure = false,
    this.maxLength,
    this.borderRadius = 12.0,
    this.validator,
    this.helperText,
    this.textAlign = TextAlign.start,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = labelText ?? label;
    final effectiveHint = hintText ?? hint;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isObscure,
      maxLength: maxLength,
      validator: validator,
      textAlign: textAlign,
      style: style,
      decoration: InputDecoration(
        labelText: effectiveLabel,
        hintText: effectiveHint,
        helperText: helperText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}
