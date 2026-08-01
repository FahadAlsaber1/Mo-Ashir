import 'package:flutter/material.dart';

class PhoneAppFrame extends StatelessWidget {
  const PhoneAppFrame({
    super.key,
    required this.role,
    required this.refreshToken,
  });

  final String role;
  final int refreshToken;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F7F4),
      child: Center(
        child: Text(
          "Mo'Ashir $role",
          style: const TextStyle(
            color: Color(0xFF0B6B39),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
