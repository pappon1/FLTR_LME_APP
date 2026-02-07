import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for TextInputFormatter
import '../../../../../utils/app_theme.dart';
import '../ui_constants.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType keyboardType;
  final int? maxLines;
  final int? maxLength;
  final bool readOnly;
  final bool alignTop;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final double bottomPadding;
  final bool hasError;
  final double? verticalPadding;
  final Widget? suffixWidget;
  final List<TextInputFormatter>? inputFormatters; // Added

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.alignTop = false,
    this.onChanged,
    this.focusNode,
    this.bottomPadding = 20.0,
    this.hasError = false,
    this.verticalPadding,
    this.suffixWidget,
    this.inputFormatters, // Added to constructor
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        readOnly: readOnly,
        onChanged: onChanged,
        inputFormatters: inputFormatters, // Passed to TextFormField
        textAlignVertical: alignTop
            ? TextAlignVertical.top
            : TextAlignVertical.center,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffixWidget,
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          alignLabelWithHint: alignTop,
          prefixIcon: icon != null
              ? (alignTop
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Icon(icon, color: Colors.grey),
                          ),
                        ],
                      )
                    : Icon(icon, color: Colors.grey))
              : null,
          contentPadding: EdgeInsets.symmetric(
            vertical: verticalPadding ?? UIConstants.inputVerticalPadding,
            horizontal: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(UIConstants.globalRadius),
            borderSide: BorderSide(
              color: hasError
                  ? Colors.red
                  : Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: UIConstants.borderOpacity),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(UIConstants.globalRadius),
            borderSide: BorderSide(
              color: hasError ? Colors.red : AppTheme.primaryColor,
              width: 2,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(UIConstants.globalRadius),
          ),
          filled: true,
          fillColor: AppTheme.primaryColor.withValues(
            alpha: UIConstants.fillOpacity,
          ),
          counterText: maxLength != null ? null : '',
        ),
      ),
    );
  }
}
