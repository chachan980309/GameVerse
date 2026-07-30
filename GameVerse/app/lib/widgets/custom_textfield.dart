import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextEditingController? controller;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.white54,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white70,
        ),
        filled: true,
        fillColor: const Color(0xFF211D2B),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 20,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF34304A),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF7B4DFF),
            width: 2,
          ),
        ),
      ),
    );
  }
}