import 'package:flutter/material.dart';

import '../services/backend_api.dart';

class DoctorCreateAccountScreen extends StatefulWidget {
  const DoctorCreateAccountScreen({super.key});

  @override
  State<DoctorCreateAccountScreen> createState() =>
      _DoctorCreateAccountScreenState();
}

class _DoctorCreateAccountScreenState extends State<DoctorCreateAccountScreen> {
  static const _primary = Color(0xFF008B45);
  static const _background = Color(0xFFEFFFF5);

  final _fullName = TextEditingController();
  final _nationalId = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _specialty = TextEditingController(text: 'General Physician');
  final _degree = TextEditingController(text: 'MBBS, MD');
  final _years = TextEditingController(text: '8');
  final _clinic = TextEditingController();
  final _languageInput = TextEditingController();
  final _certificateInput = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _acceptingAppointments = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _startHour = '09';
  String _startMinute = '00';
  String _startPeriod = 'AM';
  String _endHour = '05';
  String _endMinute = '00';
  String _endPeriod = 'PM';
  final Set<String> _workingDays = {'Su', 'Mo', 'Tu', 'We', 'Th'};
  final List<String> _languages = ['English', 'Arabic'];
  final List<String> _certificates = [
    'MBBS, MD - Internal Medicine',
    'Board Certified - Family Medicine (SCFHS)',
    'Advanced Life Support (ACLS)',
  ];

  @override
  void dispose() {
    _fullName.dispose();
    _nationalId.dispose();
    _mobile.dispose();
    _email.dispose();
    _specialty.dispose();
    _degree.dispose();
    _years.dispose();
    _clinic.dispose();
    _languageInput.dispose();
    _certificateInput.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text('Doctor Sign Up',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: CircleAvatar(
                radius: 55,
                backgroundColor: const Color(0xFFCFEFDC),
                child: Icon(Icons.person, size: 66, color: _primary),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Required information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _TextInput(controller: _fullName, label: 'Full name *'),
            _TextInput(controller: _nationalId, label: 'National ID / Iqama *'),
            _TextInput(
                controller: _mobile,
                label: 'Mobile number *',
                keyboardType: TextInputType.phone),
            _TextInput(
                controller: _email,
                label: 'Email address *',
                keyboardType: TextInputType.emailAddress),
            _TextInput(controller: _specialty, label: 'Specialty *'),
            _TextInput(controller: _degree, label: 'Degree / qualification *'),
            _TextInput(
                controller: _years,
                label: 'Years of experience *',
                keyboardType: TextInputType.number),
            _TextInput(controller: _clinic, label: 'Clinic name'),
            _PasswordInput(
              controller: _password,
              label: 'Password *',
              obscure: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            _PasswordInput(
              controller: _confirmPassword,
              label: 'Confirm password *',
              obscure: _obscureConfirmPassword,
              onToggle: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            const SizedBox(height: 12),
            _AvailabilityCard(
              value: _acceptingAppointments,
              onChanged: (value) =>
                  setState(() => _acceptingAppointments = value),
            ),
            const SizedBox(height: 16),
            _WorkingHoursCard(
              startHour: _startHour,
              startMinute: _startMinute,
              startPeriod: _startPeriod,
              endHour: _endHour,
              endMinute: _endMinute,
              endPeriod: _endPeriod,
              onStartHour: (value) => setState(() => _startHour = value),
              onStartMinute: (value) => setState(() => _startMinute = value),
              onStartPeriod: (value) => setState(() => _startPeriod = value),
              onEndHour: (value) => setState(() => _endHour = value),
              onEndMinute: (value) => setState(() => _endMinute = value),
              onEndPeriod: (value) => setState(() => _endPeriod = value),
            ),
            const SizedBox(height: 16),
            _WorkingDaysCard(
              selectedDays: _workingDays,
              onToggle: (day) {
                setState(() {
                  if (_workingDays.contains(day)) {
                    _workingDays.remove(day);
                  } else {
                    _workingDays.add(day);
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            _ListEditor(
              title: 'Languages',
              icon: Icons.language_outlined,
              items: _languages,
              controller: _languageInput,
              hint: 'Add a language...',
              onAdd: () => _addItem(_languageInput, _languages),
              onRemove: (item) => setState(() => _languages.remove(item)),
            ),
            const SizedBox(height: 16),
            _ListEditor(
              title: 'Certificates',
              icon: Icons.workspace_premium_outlined,
              items: _certificates,
              controller: _certificateInput,
              hint: 'Add a certificate...',
              onAdd: () => _addItem(_certificateInput, _certificates),
              onRemove: (item) => setState(() => _certificates.remove(item)),
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
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _createDoctorAccount,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: const Text('Create Doctor Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addItem(TextEditingController controller, List<String> target) {
    final value = controller.text.trim();
    if (value.isEmpty || target.contains(value)) return;
    setState(() {
      target.add(value);
      controller.clear();
    });
  }

  Future<void> _createDoctorAccount() async {
    if (_password.text != _confirmPassword.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await BackendApi.registerDoctor(
        fullName: _fullName.text.trim(),
        nationalId: _nationalId.text.trim(),
        mobile: _mobile.text.trim(),
        email: _email.text.trim(),
        specialty: _specialty.text.trim(),
        degree: _degree.text.trim(),
        yearsExperience: int.tryParse(_years.text.trim()) ?? -1,
        clinicName: _clinic.text.trim(),
        workingStart: '$_startHour:$_startMinute $_startPeriod',
        workingEnd: '$_endHour:$_endMinute $_endPeriod',
        workingDays: _workingDays.toList(),
        languages: _languages,
        certificates: _certificates,
        acceptingAppointments: _acceptingAppointments,
        password: _password.text,
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

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _PasswordInput extends StatelessWidget {
  const _PasswordInput({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF008B45),
            foregroundColor: Colors.white,
            child: Icon(Icons.medical_services_outlined),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Availability',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                Text('You are accepting appointments',
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _WorkingHoursCard extends StatelessWidget {
  const _WorkingHoursCard({
    required this.startHour,
    required this.startMinute,
    required this.startPeriod,
    required this.endHour,
    required this.endMinute,
    required this.endPeriod,
    required this.onStartHour,
    required this.onStartMinute,
    required this.onStartPeriod,
    required this.onEndHour,
    required this.onEndMinute,
    required this.onEndPeriod,
  });

  final String startHour;
  final String startMinute;
  final String startPeriod;
  final String endHour;
  final String endMinute;
  final String endPeriod;
  final ValueChanged<String> onStartHour;
  final ValueChanged<String> onStartMinute;
  final ValueChanged<String> onStartPeriod;
  final ValueChanged<String> onEndHour;
  final ValueChanged<String> onEndMinute;
  final ValueChanged<String> onEndPeriod;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Working hours', Icons.access_time),
          const SizedBox(height: 14),
          const Text('Start time', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: _Dropdown(
                    value: startHour, values: _hours, onChanged: onStartHour)),
            const SizedBox(width: 10),
            Expanded(
                child: _Dropdown(
                    value: startMinute,
                    values: _minutes,
                    onChanged: onStartMinute)),
            const SizedBox(width: 10),
            Expanded(
                child: _Dropdown(
                    value: startPeriod,
                    values: const ['AM', 'PM'],
                    onChanged: onStartPeriod)),
          ]),
          const SizedBox(height: 12),
          const Text('End time', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: _Dropdown(
                    value: endHour, values: _hours, onChanged: onEndHour)),
            const SizedBox(width: 10),
            Expanded(
                child: _Dropdown(
                    value: endMinute,
                    values: _minutes,
                    onChanged: onEndMinute)),
            const SizedBox(width: 10),
            Expanded(
                child: _Dropdown(
                    value: endPeriod,
                    values: const ['AM', 'PM'],
                    onChanged: onEndPeriod)),
          ]),
          const SizedBox(height: 12),
          Text(
              'Current: $startHour:$startMinute $startPeriod - $endHour:$endMinute $endPeriod',
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }

  static const _hours = [
    '01',
    '02',
    '03',
    '04',
    '05',
    '06',
    '07',
    '08',
    '09',
    '10',
    '11',
    '12',
  ];
  static const _minutes = ['00', '15', '30', '45'];
}

class _WorkingDaysCard extends StatelessWidget {
  const _WorkingDaysCard({
    required this.selectedDays,
    required this.onToggle,
  });

  final Set<String> selectedDays;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    const days = ['Sa', 'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr'];
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Working days', Icons.calendar_month_outlined),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days)
                _DayChip(
                  label: day,
                  selected: selectedDays.contains(day),
                  onTap: () => onToggle(day),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListEditor extends StatelessWidget {
  const _ListEditor({
    required this.title,
    required this.icon,
    required this.items,
    required this.controller,
    required this.hint,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title, icon),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              Chip(
                label: Text(item),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => onRemove(item),
                backgroundColor: const Color(0xFFD4F5DE),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .65),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: onAdd,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, this.icon);

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF008B45), size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFE0F8E8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: CircleAvatar(
        radius: 20,
        backgroundColor:
            selected ? const Color(0xFF008B45) : const Color(0xFFE1F5E8),
        foregroundColor: selected ? Colors.white : Colors.black54,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
