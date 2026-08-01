import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/admin_shell.dart';
import 'screens/dashboard_wall.dart';
import 'screens/doctor_shell.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'screens/splash.dart';
import 'services/app_session.dart';
import 'services/backend_api.dart';

/// The main entry point for the Moashir application.
void main() => runApp(MoashirApp(embeddedRole: _embeddedRoleFromUri()));

/// The root widget of the Moashir application.
///
/// This widget configures the [MaterialApp] with the application's
/// theme, including colors and typography.
class MoashirApp extends StatelessWidget {
  /// Creates an instance of [MoashirApp].
  const MoashirApp({super.key, this.embeddedRole});

  final String? embeddedRole;

  @override
  Widget build(BuildContext context) {
    // Application branding colors.
    const primary = Color(0xFF0B6B39);
    const surface = Color(0xFFF5F7F4);
    const card = Colors.white;

    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: card,
      ),
    );

    return MaterialApp(
      title: "MO'ASHIR",
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.manropeTextTheme(base.textTheme),
      ),
      builder: (context, child) => _IPhoneWebFrame(
        showDashboardWall: embeddedRole == null,
        child: child!,
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
      },
      home: embeddedRole == null
          ? const SplashScreen()
          : _EmbeddedRoleHome(role: embeddedRole!),
    );
  }
}

class _IPhoneWebFrame extends StatelessWidget {
  const _IPhoneWebFrame({
    required this.child,
    required this.showDashboardWall,
  });

  final Widget child;
  final bool showDashboardWall;

  static const _phoneSize = Size(430, 932);
  static const _framePadding = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (showDashboardWall && constraints.maxWidth >= 1100) {
          return const DashboardWall();
        }

        if (constraints.maxWidth <= 620) {
          return child;
        }

        final frameWidth = _phoneSize.width + (_framePadding * 2);
        final frameHeight = _phoneSize.height + (_framePadding * 2);
        return ColoredBox(
          color: const Color(0xFFE9ECEF),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: frameWidth,
                height: frameHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(58),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .28),
                        blurRadius: 36,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(_framePadding),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(44),
                      child: SizedBox.fromSize(
                        size: _phoneSize,
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: _phoneSize,
                            padding: EdgeInsets.zero,
                            viewPadding: EdgeInsets.zero,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmbeddedRoleHome extends StatefulWidget {
  const _EmbeddedRoleHome({required this.role});

  final String role;

  @override
  State<_EmbeddedRoleHome> createState() => _EmbeddedRoleHomeState();
}

class _EmbeddedRoleHomeState extends State<_EmbeddedRoleHome> {
  late final Future<void> _sessionReady;

  @override
  void initState() {
    super.initState();
    _sessionReady = _seedSession(widget.role);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _sessionReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _EmbeddedRoleError(error: snapshot.error);
        }

        return switch (widget.role) {
          'doctor' => const DoctorShell(),
          'admin' => const AdminShell(),
          _ => const AppShell(),
        };
      },
    );
  }
}

class _EmbeddedRoleError extends StatelessWidget {
  const _EmbeddedRoleError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "Could not connect to the Mo'Ashir API.\n$error",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF0B6B39)),
          ),
        ),
      ),
    );
  }
}

String? _embeddedRoleFromUri() {
  final role = Uri.base.queryParameters['moashirEmbeddedRole'];
  return switch (role) {
    'doctor' || 'patient' || 'admin' => role,
    _ => null,
  };
}

Future<void> _seedSession(String role) async {
  if (role == 'doctor') {
    final doctors = await BackendApi.listDoctors();
    final doctor = doctors.firstWhere(
      (item) => item.fullName == 'Dr. Moashir Demo',
      orElse: () => doctors.first,
    );
    AppSession.set(
      AuthSession(
        user: {
          'id': 'embedded-doctor-user',
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
    return;
  }

  if (role == 'patient') {
    final patients = await BackendApi.listPatients();
    final patient = patients.firstWhere(
      (item) => item.fullName == 'Fahad Alsaber',
      orElse: () => patients.first,
    );
    AppSession.set(
      AuthSession(
        user: {
          'id': 'embedded-patient-user',
          'role': 'patient',
          'patient_id': patient.id,
          'email': patient.email,
        },
        profile: {
          'id': patient.id,
          'full_name': patient.fullName,
          'email': patient.email,
          'phone': patient.phone,
          'national_id': patient.nationalId,
          'gender': patient.gender,
          'date_of_birth': patient.dateOfBirth,
          'blood_type': patient.bloodType,
        },
      ),
    );
    try {
      final appointment =
          await BackendApi.getUpcomingAppointment(patientId: patient.id);
      if (appointment != null) {
        AppSession.setLatestAppointment(appointment);
      }
    } on BackendApiException {
      // Leave the patient home without a cached upcoming appointment.
    }
    return;
  }

  AppSession.set(
    const AuthSession(
      user: {
        'id': 'embedded-admin-user',
        'role': 'admin',
        'email': 'admin@example.com',
      },
      profile: {
        'id': 'embedded-admin',
        'full_name': "Mo'Ashir Administrator",
        'email': 'admin@example.com',
      },
    ),
  );
}
