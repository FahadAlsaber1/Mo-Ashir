import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _splashDuration = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_splashDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFEFFFF5),
      body: SafeArea(
        child: Center(
          child: Image(
            image: AssetImage('assets/images/moashir_badge.png'),
            width: 220,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
