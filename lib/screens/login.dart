import 'package:flutter/material.dart';

import 'admin_shell.dart';
import 'create_account.dart';
import 'doctor_create_account.dart';
import 'doctor_shell.dart';
import 'shell.dart';
import '../services/app_session.dart';
import '../services/backend_api.dart';

enum LoginRole { patient, doctor, admin }

enum LoginMethod { mobile, email, nationalId }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  LoginRole _role = LoginRole.patient;
  LoginMethod _method = LoginMethod.mobile;
  bool _obscurePassword = true;
  bool _isSigningIn = false;
  String? _errorMessage;
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF007F3D);
    const background = Color(0xFFEFFFF5);
    const segmentBackground = Color(0xFFD9F7E1);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 58),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandMark(),
                      const SizedBox(height: 22),
                      const Text(
                        'Hello',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _subtitleForRole(_role),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF65756D),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _RoleSelector(
                        selected: _role,
                        backgroundColor: segmentBackground,
                        onChanged: (role) => setState(() => _role = role),
                      ),
                      const SizedBox(height: 14),
                      _MethodSelector(
                        selected: _method,
                        backgroundColor: segmentBackground,
                        onChanged: (method) => setState(() => _method = method),
                      ),
                      const SizedBox(height: 28),
                      _InputLabel(_labelForMethod(_method)),
                      const SizedBox(height: 10),
                      _AuthInput(
                        method: _method,
                        controller: _identifierController,
                      ),
                      const SizedBox(height: 22),
                      const _InputLabel('Password'),
                      const SizedBox(height: 10),
                      _PasswordInput(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onToggleVisibility: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: primary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 58,
                        child: FilledButton(
                          onPressed: _isSigningIn ? null : _openApp,
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: _isSigningIn
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 26),
                      const _DividerLabel(),
                      const SizedBox(height: 26),
                      SizedBox(
                        height: 58,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.verified_user_outlined,
                              size: 20),
                          label: const Text('Sign in with Nafath (نفاذ)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                            side: const BorderSide(
                                color: Color(0xFF75C895), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(top: 34, bottom: 14),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: Color(0xFF65756D),
                                fontSize: 15,
                              ),
                            ),
                            if (_role == LoginRole.admin)
                              const Text(
                                'Ask an existing Hospitel user to create access.',
                                style: TextStyle(
                                  color: Color(0xFF65756D),
                                  fontSize: 15,
                                ),
                              )
                            else
                              TextButton(
                                onPressed: _openCreateAccount,
                                style: TextButton.styleFrom(
                                  foregroundColor: primary,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Create account',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openApp() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your sign in details.');
      return;
    }

    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      await BackendApi.login(
        role: _role.name,
        method: _method.name,
        identifier: identifier,
        password: password,
      ).then(AppSession.set);
      if (!mounted) return;
      final destination = switch (_role) {
        LoginRole.patient => const AppShell(),
        LoginRole.doctor => const DoctorShell(),
        LoginRole.admin => const AdminShell(),
      };
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } on BackendApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not connect to the backend.');
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _openCreateAccount() async {
    final destination = _role == LoginRole.doctor
        ? const DoctorCreateAccountScreen()
        : const CreateAccountScreen();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => destination),
    );
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created. Please sign in.')),
    );
  }

  String _labelForMethod(LoginMethod method) {
    switch (method) {
      case LoginMethod.mobile:
        return 'Mobile';
      case LoginMethod.email:
        return 'Email';
      case LoginMethod.nationalId:
        return 'National ID';
    }
  }

  String _subtitleForRole(LoginRole role) {
    return switch (role) {
      LoginRole.patient => 'Sign in to manage your health',
      LoginRole.doctor => 'Sign in to manage your patients',
      LoginRole.admin => 'Sign in to manage the Hospitel platform',
    };
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF007F3D),
          borderRadius: BorderRadius.circular(23),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007F3D).withOpacity(0.16),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const Icon(
          Icons.favorite_border_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selected,
    required this.backgroundColor,
    required this.onChanged,
  });

  final LoginRole selected;
  final Color backgroundColor;
  final ValueChanged<LoginRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SegmentShell(
      backgroundColor: backgroundColor,
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              active: selected == LoginRole.patient,
              icon: Icons.person_outline,
              label: 'Patient',
              onTap: () => onChanged(LoginRole.patient),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              active: selected == LoginRole.doctor,
              icon: Icons.medical_services_outlined,
              label: 'Doctor',
              onTap: () => onChanged(LoginRole.doctor),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              active: selected == LoginRole.admin,
              icon: Icons.admin_panel_settings_outlined,
              label: 'Hospitel',
              onTap: () => onChanged(LoginRole.admin),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({
    required this.selected,
    required this.backgroundColor,
    required this.onChanged,
  });

  final LoginMethod selected;
  final Color backgroundColor;
  final ValueChanged<LoginMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SegmentShell(
      backgroundColor: backgroundColor,
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              active: selected == LoginMethod.mobile,
              icon: Icons.phone_android_outlined,
              label: 'Mobile',
              onTap: () => onChanged(LoginMethod.mobile),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              active: selected == LoginMethod.email,
              icon: Icons.mail_outline,
              label: 'Email',
              onTap: () => onChanged(LoginMethod.email),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              active: selected == LoginMethod.nationalId,
              icon: Icons.badge_outlined,
              label: 'National ID',
              onTap: () => onChanged(LoginMethod.nationalId),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentShell extends StatelessWidget {
  const _SegmentShell({
    required this.backgroundColor,
    required this.child,
  });

  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF007F3D);

    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: primary,
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AuthInput extends StatelessWidget {
  const _AuthInput({
    required this.method,
    required this.controller,
  });

  final LoginMethod method;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _PillTextField(
      controller: controller,
      icon: _iconForMethod(method),
      keyboardType: _keyboardForMethod(method),
      hintText: _hintForMethod(method),
    );
  }

  IconData _iconForMethod(LoginMethod method) {
    switch (method) {
      case LoginMethod.mobile:
        return Icons.phone_android_outlined;
      case LoginMethod.email:
        return Icons.mail_outline;
      case LoginMethod.nationalId:
        return Icons.badge_outlined;
    }
  }

  TextInputType _keyboardForMethod(LoginMethod method) {
    switch (method) {
      case LoginMethod.mobile:
        return TextInputType.phone;
      case LoginMethod.email:
        return TextInputType.emailAddress;
      case LoginMethod.nationalId:
        return TextInputType.number;
    }
  }

  String _hintForMethod(LoginMethod method) {
    switch (method) {
      case LoginMethod.mobile:
        return '+966 5X XXX XXXX';
      case LoginMethod.email:
        return 'name@example.com';
      case LoginMethod.nationalId:
        return '1XXXXXXXXX';
    }
  }
}

class _PasswordInput extends StatelessWidget {
  const _PasswordInput({
    required this.controller,
    required this.obscureText,
    required this.onToggleVisibility,
  });

  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return _PillTextField(
      controller: controller,
      icon: Icons.lock_outline,
      hintText: 'Password',
      obscureText: obscureText,
      trailing: IconButton(
        onPressed: onToggleVisibility,
        color: const Color(0xFF6F7B75),
        icon: Icon(
          obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 21,
        ),
      ),
    );
  }
}

class _PillTextField extends StatelessWidget {
  const _PillTextField({
    this.controller,
    required this.icon,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
  });

  final TextEditingController? controller;
  final IconData icon;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: const Color(0xFF6F7B75), size: 21),
          suffixIcon: trailing,
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF809088),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0xFFD5E3DA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0xFF007F3D), width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0xFFD1DED6), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: TextStyle(
              color: Color(0xFF65756D),
              fontSize: 15,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD1DED6), height: 1)),
      ],
    );
  }
}
