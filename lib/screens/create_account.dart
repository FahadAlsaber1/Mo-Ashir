import 'package:flutter/material.dart';

import '../services/backend_api.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  static const _primary = Color(0xFF008B45);
  static const _border = Color(0xFFE7E9E8);
  static const _muted = Color(0xFF8C9290);

  bool _maleSelected = true;
  bool _insuranceEnabled = false;
  bool _agree = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  final _fullNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _nationalIdController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _dateOfBirthController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            _Header(onBack: () => Navigator.pop(context)),
            const SizedBox(height: 26),
            _AccountField(
              icon: Icons.person_outline,
              label: 'Full Name',
              hint: 'Enter your full name',
              required: true,
              keyboardType: TextInputType.name,
              controller: _fullNameController,
            ),
            const SizedBox(height: 14),
            _AccountField(
              icon: Icons.badge_outlined,
              label: 'National ID / Iqama Number',
              hint: 'Enter your national ID or iqama number',
              required: true,
              keyboardType: TextInputType.number,
              controller: _nationalIdController,
            ),
            const SizedBox(height: 14),
            _PhoneField(controller: _mobileController),
            const SizedBox(height: 14),
            _AccountField(
              icon: Icons.mail_outline,
              label: 'Email Address',
              hint: 'Enter your email address',
              required: true,
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
            ),
            const SizedBox(height: 14),
            _AccountField(
              icon: Icons.calendar_today_outlined,
              label: 'Date of Birth',
              hint: 'DD / MM / YYYY',
              required: true,
              trailing: Icon(Icons.calendar_today_outlined, color: _muted),
              keyboardType: TextInputType.datetime,
              controller: _dateOfBirthController,
            ),
            const SizedBox(height: 14),
            _GenderField(
              maleSelected: _maleSelected,
              onChanged: (value) => setState(() => _maleSelected = value),
            ),
            const SizedBox(height: 14),
            _AccountField(
              icon: Icons.lock_outline,
              label: 'Password',
              hint: 'Enter your password',
              required: true,
              obscureText: _obscurePassword,
              controller: _passwordController,
              trailing: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _muted,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _AccountField(
              icon: Icons.lock_outline,
              label: 'Confirm Password',
              hint: 'Confirm your password',
              required: true,
              obscureText: _obscureConfirmPassword,
              controller: _confirmPasswordController,
              trailing: IconButton(
                onPressed: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _muted,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _InsuranceField(
              enabled: _insuranceEnabled,
              onChanged: (value) => setState(() => _insuranceEnabled = value),
            ),
            const SizedBox(height: 14),
            _TermsField(
              checked: _agree,
              onChanged: (value) => setState(() => _agree = value),
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
            const SizedBox(height: 24),
            SizedBox(
              height: 58,
              child: FilledButton(
                onPressed: _agree && !_isSubmitting ? _createAccount : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: _primary.withValues(alpha: .38),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAccount() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await BackendApi.registerPatient(
        fullName: _fullNameController.text.trim(),
        nationalId: _nationalIdController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _dateOfBirthController.text.trim(),
        gender: _maleSelected ? 'male' : 'female',
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on BackendApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not connect to the backend.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 30),
          ),
        ),
        const Column(
          children: [
            SizedBox(height: 6),
            Text(
              'Create Account',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Create your account to get started',
              style: TextStyle(
                color: Color(0xFF8C9290),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(right: 6),
            child: _MiniLogo(),
          ),
        ),
      ],
    );
  }
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.monitor_heart_outlined, color: Color(0xFF008B45), size: 52),
        Text(
          "MO'ASHIR",
          style: TextStyle(
            color: Color(0xFF008B45),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.icon,
    required this.label,
    required this.hint,
    this.required = false,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.controller,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool required;
  final Widget? trailing;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RequiredLabel(label: label, required: required),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(
                color: _CreateAccountScreenState._muted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              suffixIcon: trailing,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 32,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      icon: Icons.phone_outlined,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 26,
            decoration: BoxDecoration(
              color: _CreateAccountScreenState._primary,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: const Text(
              'SA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '+966',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8C9290)),
          const SizedBox(width: 18),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number *',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: '5XXXXXXXX',
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(
                  color: _CreateAccountScreenState._muted,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                labelStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderField extends StatelessWidget {
  const _GenderField({
    required this.maleSelected,
    required this.onChanged,
  });

  final bool maleSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      icon: Icons.person_outline,
      minHeight: 126,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RequiredLabel(label: 'Gender', required: true),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GenderButton(
                  selected: maleSelected,
                  icon: Icons.male_rounded,
                  label: 'Male',
                  onTap: () => onChanged(true),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _GenderButton(
                  selected: !maleSelected,
                  icon: Icons.female_rounded,
                  label: 'Female',
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  const _GenderButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: selected ? const Color(0xFFF8FBF9) : Colors.white,
        side: BorderSide(
          color: selected
              ? _CreateAccountScreenState._primary
              : _CreateAccountScreenState._border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class _InsuranceField extends StatelessWidget {
  const _InsuranceField({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      icon: Icons.health_and_safety_outlined,
      minHeight: 182,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Insurance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add your medical insurance details (optional)',
                      style: TextStyle(
                        color: _CreateAccountScreenState._muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 94,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF8FD4AE)),
            ),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_moderator_outlined,
                  color: _CreateAccountScreenState._primary,
                  size: 34,
                ),
                SizedBox(height: 10),
                Text(
                  'Enable to add your insurance information',
                  style: TextStyle(
                    color: _CreateAccountScreenState._muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsField extends StatelessWidget {
  const _TermsField({
    required this.checked,
    required this.onChanged,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onChanged(!checked),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _CreateAccountScreenState._border),
          ),
          child: Row(
            children: [
              Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                color: _CreateAccountScreenState._primary,
                size: 30,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to the ',
                    children: [
                      TextSpan(
                        text: 'Terms and Conditions',
                        style: TextStyle(
                            color: _CreateAccountScreenState._primary),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                            color: _CreateAccountScreenState._primary),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.icon,
    required this.child,
    this.minHeight = 94,
  });

  final IconData icon;
  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.fromLTRB(20, 16, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _CreateAccountScreenState._border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: _CreateAccountScreenState._primary, size: 34),
          const SizedBox(width: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.label, required this.required});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
              ]
            : const [],
      ),
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
