import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TechTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isObscure;
  final Function(String)? onSubmitted;
  final Function(String)? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final String? suffixText;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  const TechTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isObscure = false,
    this.onSubmitted,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.suffix,
    this.suffixText,
    this.validator,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      style: GoogleFonts.poppins(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87, 
          fontSize: 14),
      decoration: decoration(context, icon: icon, label: label, suffix: suffix, suffixText: suffixText),
      validator: validator ?? (v) => v!.isEmpty ? 'Required' : null,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
    );
  }

  static InputDecoration decoration(
    BuildContext context, {
    IconData? icon,
    String? label,
    Widget? suffix,
    String? suffixText,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color primaryColor = Color(0xFF6366F1);
    final Color surfaceColor = isDark ? const Color(0xFF0F1218) : Colors.white;
    final Color borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return InputDecoration(
      prefixIcon: icon != null
          ? Icon(icon, color: primaryColor.withValues(alpha: 0.8), size: 18)
          : null,
      suffixText: suffixText,
      suffixStyle: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5)),
      suffixIcon: suffix,
      labelText: label,
      filled: true,
      fillColor: surfaceColor,
      labelStyle: TextStyle(
          color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
          fontSize: 13.0,
          fontWeight: FontWeight.w600),
      floatingLabelStyle:
          const TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.0), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.0),
          borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.0),
          borderSide: const BorderSide(color: primaryColor, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
