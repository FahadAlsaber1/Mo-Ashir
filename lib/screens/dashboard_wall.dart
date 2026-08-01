import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/backend_api.dart';
import 'dashboard_wall_frame_stub.dart'
    if (dart.library.js_interop) 'dashboard_wall_frame_web.dart';
import 'doctor_shell.dart';

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
                  child: role == 'doctor'
                      ? const _DoctorPhoneApp()
                      : PhoneAppFrame(role: role),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DoctorPhoneApp extends StatefulWidget {
  const _DoctorPhoneApp();

  @override
  State<_DoctorPhoneApp> createState() => _DoctorPhoneAppState();
}

class _DoctorPhoneAppState extends State<_DoctorPhoneApp> {
  late Future<void> _sessionReady;

  @override
  void initState() {
    super.initState();
    _sessionReady = _seedDoctorSession();
  }

  Future<void> _seedDoctorSession() async {
    final doctors = await BackendApi.listDoctors();
    if (doctors.isEmpty) {
      throw BackendApiException('No doctors found.');
    }
    final doctor = doctors.firstWhere(
      (item) => item.fullName == 'Dr. Moashir Demo',
      orElse: () => doctors.first,
    );
    AppSession.set(
      AuthSession(
        user: {
          'id': 'wall-doctor-user',
          'role': 'doctor',
          'doctor_id': doctor.id,
          'email': 'doctor@example.com',
        },
        profile: {
          'id': doctor.id,
          'full_name': doctor.fullName,
          'specialty': doctor.specialty,
          'degree': doctor.degree,
          'clinic_name': doctor.clinicName,
          'email': 'doctor@example.com',
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _sessionReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0xFFEFFFF5),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _DoctorPhoneError(
            message: "Could not load Mo'Ashir doctor.\n${snapshot.error}",
            onRetry: () => setState(() {
              _sessionReady = _seedDoctorSession();
            }),
          );
        }
        return Navigator(
          onGenerateRoute: (settings) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: _PhonePanel._contentSize,
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                ),
                child: const DoctorShell(),
              ),
            );
          },
        );
      },
    );
  }
}

class _DoctorPhoneError extends StatelessWidget {
  const _DoctorPhoneError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFFFF5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF0B6B39)),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
