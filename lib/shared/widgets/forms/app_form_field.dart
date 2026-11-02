import 'package:flutter/material.dart';

/// バリデーション付きの標準フォームフィールド
class AppFormField extends StatelessWidget {
  const AppFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.enabled,
    this.obscureText = false,
    this.maxLength,
    this.autofocus = false,
    this.validator,
  }) : assert(
         controller == null || initialValue == null,
         'controller と initialValue は同時に指定できません',
       );

  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool? enabled;
  final bool obscureText;
  final int? maxLength;
  final bool autofocus;
  final String? Function(String? value)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: enabled,
      maxLength: maxLength,
      autofocus: autofocus,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
    );
  }
}
