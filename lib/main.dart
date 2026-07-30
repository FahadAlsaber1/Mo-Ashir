import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login.dart';
import 'screens/splash.dart';

/// The main entry point for the Moashir application.
void main() => runApp(const MoashirApp());

/// The root widget of the Moashir application.
///
/// This widget configures the [MaterialApp] with the application's
/// theme, including colors and typography.
class MoashirApp extends StatelessWidget {
  /// Creates an instance of [MoashirApp].
  const MoashirApp({super.key});

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
      builder: (context, child) => _IPhoneWebFrame(child: child!),
      routes: {
        '/login': (_) => const LoginScreen(),
      },
      home: const SplashScreen(),
    );
  }
}

class _IPhoneWebFrame extends StatelessWidget {
  const _IPhoneWebFrame({required this.child});

  final Widget child;

  static const _phoneSize = Size(430, 932);
  static const _framePadding = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
