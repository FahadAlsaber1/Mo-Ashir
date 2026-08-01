import 'package:flutter/material.dart';

import 'dashboard_wall_frame_stub.dart'
    if (dart.library.js_interop) 'dashboard_wall_frame_web.dart';

class DashboardWall extends StatelessWidget {
  const DashboardWall({super.key});

  static const _background = Color(0xFFE9ECEF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.noScaling,
        ),
        child: const SafeArea(
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 26, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PhonePanel(
                    caption: "Logged in as Mo'Ashir doctor",
                    role: 'doctor',
                  ),
                  SizedBox(width: 34),
                  _PhonePanel(
                    caption: "Logged in as Mo'Ashir patient",
                    role: 'patient',
                  ),
                  SizedBox(width: 34),
                  _PhonePanel(
                    caption: "Logged in as Mo'Ashir administrator",
                    role: 'admin',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhonePanel extends StatelessWidget {
  const _PhonePanel({
    required this.caption,
    required this.role,
  });

  final String caption;
  final String role;

  static const _phoneSize = Size(430, 932);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          caption,
          style: const TextStyle(
            color: Color(0xFF0B6B39),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox.fromSize(
          size: _phoneSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(58),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .24),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(44),
                child: PhoneAppFrame(role: role),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
