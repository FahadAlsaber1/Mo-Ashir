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
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: const Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
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
              );
            },
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

  static const _contentSize = Size(430, 932);
  static const _framePadding = 12.0;
  static const _phoneSize = Size(454, 956);

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
              padding: const EdgeInsets.all(_framePadding),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(44),
                child: SizedBox.fromSize(
                  size: _contentSize,
                  child: PhoneAppFrame(role: role),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
