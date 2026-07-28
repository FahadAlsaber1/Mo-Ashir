import 'package:flutter/material.dart';
import 'package:moashir/height_weight_scanner/height_weight_scanner_page.dart';

import '../data/mock.dart';
import '../data/vital_signs_data.dart';
import '../services/app_session.dart';
import '../services/backend_api.dart';
import 'remote_vitals_measurement_screen.dart';
import 'shell.dart';

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key, this.initialDoctor});

  final Doctor? initialDoctor;

  @override
  State<AppointmentBookingScreen> createState() =>
      _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  static const _titles = [
    'Book For',
    'Choose Specialty',
    'Choose Insurance',
    'Choose City',
    'Select Doctor',
    'Appointment Details',
    'Visit Details',
    'Height & Weight',
    'Vital Signs',
    'Review Appointment',
    'Payment',
    'Appointment Confirmed',
  ];
  static const _specialties = [
    ('General Medicine', Icons.health_and_safety_outlined),
    ('Cardiology', Icons.favorite_outline),
    ('Dermatology', Icons.face_retouching_natural_outlined),
    ('Pediatrics', Icons.child_care_outlined),
    ('Dentistry', Icons.medical_services_outlined),
    ('Neurology', Icons.psychology_outlined),
  ];
  static const _insurers = [
    'No insurance / Self-pay',
    'Bupa Arabia',
    'Tawuniya',
    'Medgulf',
    'Al Rajhi Takaful',
    'Gulf Union',
  ];
  static const _cities = [
    'Riyadh',
    'Jeddah',
    'Dammam',
    'Khobar',
    'Makkah',
    'Madinah',
  ];
  static const _dates = [
    'Today\n15 Jul',
    'Thu\n16 Jul',
    'Sun\n19 Jul',
    'Mon\n20 Jul',
    'Tue\n21 Jul'
  ];
  static const _times = [
    '9:00 AM',
    '9:30 AM',
    '10:30 AM',
    '11:00 AM',
    '2:30 PM',
    '4:00 PM'
  ];
  static const _noneOfThese = 'None of these';
  static const _configuredRegion = 'SA';
  static const _emergencyNumbersByRegion = {
    'SA': '997',
    'US': '911',
    'GB': '999',
    'EU': '112',
  };
  static const _ctasQuestions = [
    _CtasQuestion(
      level: 2,
      heading: 'Are you currently experiencing any of these symptoms?',
      options: [
        'Severe difficulty breathing or inability to breathe normally',
        'Severe chest pain, pressure, or tightness',
        'Chest pain spreading to the arm, shoulder, back, neck, or jaw',
        'Chest pain accompanied by sweating, dizziness, nausea, or weakness',
        'Heavy or continuous bleeding that cannot be controlled',
        'Symptoms that are becoming worse very quickly',
        'Sudden severe weakness or feeling that you may lose consciousness',
        'Severe swelling or an allergic reaction affecting breathing',
        'Extremely severe or unbearable pain',
        _noneOfThese,
      ],
    ),
    _CtasQuestion(
      level: 3,
      heading: 'Are you currently experiencing any of these symptoms?',
      options: [
        'Severe or persistent abdominal pain while remaining conscious and stable',
        'Repeated vomiting or diarrhoea with signs of dehydration',
        'Severe thirst, dry mouth, dizziness, or reduced urination',
        'A possible fracture without severe bleeding or a major deformity',
        'Moderate pain that limits movement or normal activities',
        'A noticeably high temperature with persistent symptoms',
        'Persistent dizziness while remaining conscious and stable',
        'Symptoms that are not immediately life-threatening but require prompt medical attention',
        _noneOfThese,
      ],
    ),
    _CtasQuestion(
      level: 4,
      heading: 'Are you currently experiencing any of these symptoms?',
      options: [
        'A minor injury, such as a mild sprain or bruise',
        'Mild shortness of breath without severe breathing difficulty',
        'A mild infection, such as a minor sore throat or ear infection',
        'A superficial wound or small cut with controlled bleeding',
        'Mild to moderate pain that does not prevent normal activities',
        'A small and minor burn',
        'Mild swelling or redness without rapid deterioration',
        'A stable condition that still requires medical evaluation',
        _noneOfThese,
      ],
    ),
    _CtasQuestion(
      level: 5,
      heading:
          'Is your reason for seeking medical care related to any of the following?',
      options: [
        'A mild cold, runny nose, or minor congestion',
        'A mild skin rash without breathing difficulty or severe swelling',
        'A routine medical review or check-up',
        'A prescription renewal',
        'A stable chronic condition with no significant recent change',
        'Mild symptoms that began some time ago and have not become worse',
        'A consultation about a test result, medication, or general health concern',
        'No severe pain, breathing difficulty, uncontrolled bleeding, or rapid deterioration',
        _noneOfThese,
      ],
    ),
  ];

  late int _step;
  String? _appointmentFor;
  String? _familyMember;
  String? _specialty;
  String? _insurance;
  String? _city;
  Doctor? _doctor;
  String? _date;
  String? _time;
  String? _paymentMethod;
  RemoteVitalResult? _remoteVitalsResult;
  ScanResult? _heightWeightResult;
  late final Map<int, Set<String>> _ctasAnswers = {
    for (final question in _ctasQuestions) question.level: <String>{},
  };
  bool _urgentWarningAcknowledged = false;
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  String _query = '';
  bool _savingAppointment = false;
  String? _saveError;
  late Future<List<Doctor>> _doctorsFuture;

  int get _confirmedStep => _titles.length - 1;

  int get _totalSteps => _confirmedStep;

  @override
  void initState() {
    super.initState();
    _doctor = widget.initialDoctor;
    _specialty = widget.initialDoctor?.specialty;
    _insurance = widget.initialDoctor == null ? null : _insurers.first;
    _city = widget.initialDoctor?.city;
    _doctorsFuture = _loadDoctors();
    _step = 0;
  }

  Future<List<Doctor>> _loadDoctors() async {
    final backendDoctors = await BackendApi.listDoctors();
    if (backendDoctors.isEmpty) return doctors;
    return backendDoctors
        .map((doctor) => Doctor(
              doctor.id,
              doctor.fullName,
              doctor.specialty,
              doctor.degree,
              doctor.rating,
              doctor.yearsExperience,
              clinicOverride: doctor.clinicName,
              languagesOverride:
                  doctor.languages.isEmpty ? null : doctor.languages.join(', '),
              cityOverride: 'Riyadh',
              consultationFeeSar: consultationFeeForSpecialty(doctor.specialty),
            ))
        .toList();
  }

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _step == _confirmedStep;
    final emergency = _step == 6 && _hasLevel1Emergency;
    return PopScope(
      canPop: _step == 0 || confirmed || emergency,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: Scaffold(
        appBar: confirmed || emergency
            ? null
            : AppBar(
                title: Text(_titles[_step]),
                leading: IconButton(
                    icon: const Icon(Icons.arrow_back), onPressed: _back),
              ),
        body: SafeArea(
          child: Column(children: [
            if (!confirmed && !emergency) _progress(),
            Expanded(
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _body())),
            if (_showContinue) _continueButton(),
          ]),
        ),
      ),
    );
  }

  bool get _showContinue =>
      _step < _confirmedStep &&
      _step != 4 &&
      !(_step == 6 && _hasLevel1Emergency);

  bool get _allCtasQuestionsAnswered =>
      _ctasAnswers.values.every((answers) => answers.isNotEmpty);

  bool get _hasLevel1Emergency => _selectedSymptomsForLevel(1).isNotEmpty;

  int? get _preliminaryCtasLevel {
    for (final question in _ctasQuestions) {
      if (_selectedSymptomsForLevel(question.level).isNotEmpty) {
        return question.level;
      }
    }
    return null;
  }

  String get _preliminaryCtasText {
    final level = _preliminaryCtasLevel;
    return switch (level) {
      1 => 'Preliminary CTAS Level 1 - Resuscitation',
      2 => 'Preliminary CTAS Level 2 - Emergent',
      3 => 'Preliminary CTAS Level 3 - Urgent',
      4 => 'Preliminary CTAS Level 4 - Less Urgent',
      5 => 'Preliminary CTAS Level 5 - Non-Urgent',
      _ => 'Clinical review required',
    };
  }

  String get _emergencyNumber =>
      _emergencyNumbersByRegion[_configuredRegion] ??
      'your local emergency number';

  List<String> _selectedSymptomsForLevel(int level) {
    final answers = _ctasAnswers[level] ?? const <String>{};
    return answers.where((answer) => answer != _noneOfThese).toList();
  }

  Widget _progress() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(children: [
          Row(children: [
            Text('Step ${(_step + 1).clamp(1, _totalSteps)} of $_totalSteps',
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const Spacer(),
            Text(
                '${(((_step + 1).clamp(1, _totalSteps)) / _totalSteps * 100).round()}%',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
          const SizedBox(height: 7),
          LinearProgressIndicator(
              value: (_step + 1).clamp(1, _totalSteps) / _totalSteps,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8)),
        ]),
      );

  Widget _body() {
    if (_step == 6 && _hasLevel1Emergency) return _emergencyAlert();

    return switch (_step) {
      0 => _chooseAppointmentFor(),
      1 => _chooseSpecialty(),
      2 => _chooseInsurance(),
      3 => _chooseCity(),
      4 => _chooseDoctor(),
      5 => _appointmentDetails(),
      6 => _visitDetails(),
      7 => _bodyMeasurements(),
      8 => _vitalSigns(),
      9 => _review(),
      10 => _payment(),
      _ => _confirmed(),
    };
  }

  Widget _chooseAppointmentFor() => _page([
        const _Heading('Who is this appointment for?',
            'Choose whether you are booking for yourself or a family member.'),
        _OptionTile(
          label: 'For me - Noura',
          icon: Icons.person_outline,
          selected: _appointmentFor == 'Me',
          onTap: () => setState(() {
            _appointmentFor = 'Me';
            _familyMember = null;
          }),
        ),
        _OptionTile(
          label: 'For my family',
          icon: Icons.family_restroom_outlined,
          selected: _appointmentFor == 'Family',
          onTap: () => setState(() => _appointmentFor = 'Family'),
        ),
        if (_appointmentFor == 'Family') ...[
          const SizedBox(height: 10),
          const Text('Choose family member',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...['Ahmed', 'Sara', 'Maha'].map((name) => _OptionTile(
                label: name,
                icon: Icons.person_add_alt_outlined,
                selected: _familyMember == name,
                onTap: () => setState(() => _familyMember = name),
              )),
        ],
      ]);

  Widget _chooseSpecialty() => _page([
        const _Heading('What kind of doctor do you need?',
            'Select a specialty to see matching doctors.'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _specialties.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.45,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12),
          itemBuilder: (_, i) {
            final item = _specialties[i];
            return _SelectCard(
                label: item.$1,
                icon: item.$2,
                selected: _specialty == item.$1,
                onTap: () => setState(() => _specialty = item.$1));
          },
        ),
      ]);

  Widget _chooseInsurance() => _page([
        const _Heading('How will you pay?',
            'Choose your insurer to find covered doctors.'),
        ..._insurers.map((item) => _OptionTile(
              label: item,
              icon: item.startsWith('No insurance')
                  ? Icons.payments_outlined
                  : Icons.shield_outlined,
              selected: _insurance == item,
              onTap: () => setState(() => _insurance = item),
            )),
      ]);

  Widget _chooseCity() => _page([
        const _Heading(
            'Choose your city', 'Select where you want to book the visit.'),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
              hintText: 'Search city',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 14),
        ..._cities
            .where((city) =>
                _query.isEmpty ||
                city.toLowerCase().contains(_query.toLowerCase()))
            .map((city) => _OptionTile(
                  label: city,
                  icon: Icons.location_city_outlined,
                  selected: _city == city,
                  onTap: () => setState(() {
                    _city = city;
                    _query = '';
                  }),
                )),
      ]);

  Widget _chooseDoctor() {
    return _page([
      TextField(
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
            hintText: 'Search by doctor name, specialty, or clinic',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none)),
      ),
      const SizedBox(height: 14),
      FutureBuilder<List<Doctor>>(
        future: _doctorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final source = snapshot.data ?? doctors;
          final results = source
              .where((d) =>
                  (_city == null || d.city == _city) &&
                  (_query.isEmpty ||
                      '${d.name} ${d.specialty} ${d.clinic}'
                          .toLowerCase()
                          .contains(_query.toLowerCase())))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${results.length} doctors available',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (results.isEmpty)
                const _EmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No doctors found',
                    subtitle: 'Try another city or search term.'),
              ...results.map((doctor) => _DoctorTile(
                  doctor: doctor,
                  onTap: () => setState(() {
                        _doctor = doctor;
                        _step = 5;
                      }))),
            ],
          );
        },
      ),
    ]);
  }

  Widget _appointmentDetails() {
    final doctor = _doctor!;
    final primary = Theme.of(context).colorScheme.primary;
    return _page([
      Center(
          child: CircleAvatar(
              radius: 50,
              backgroundColor: primary.withValues(alpha: .12),
              child: Icon(Icons.person_outline, size: 58, color: primary))),
      const SizedBox(height: 14),
      Text(doctor.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      Text(doctor.specialty,
          textAlign: TextAlign.center,
          style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
      Text(doctor.credential,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
            child: _Metric(
                icon: Icons.star_rounded,
                value: '${doctor.rating}',
                label: 'Rating')),
        const SizedBox(width: 10),
        Expanded(
            child: _Metric(
                icon: Icons.workspace_premium_outlined,
                value: '${doctor.years} years',
                label: 'Experience')),
        const SizedBox(width: 10),
        Expanded(
            child: _Metric(
                icon: Icons.payments_outlined,
                value: doctor.consultationFeeLabel,
                label: 'Consultation')),
      ]),
      const SizedBox(height: 12),
      _SummaryRow(
          icon: Icons.local_hospital_outlined,
          label: 'Clinic',
          value: doctor.clinic),
      _SummaryRow(
          icon: Icons.language, label: 'Languages', value: doctor.languages),
      _SummaryRow(
          icon: Icons.event_available_outlined,
          label: 'Next available',
          value: doctor.nextAvailable),
      const SizedBox(height: 14),
      const _Heading(
          'Select a date', 'Available days for your selected doctor.'),
      ..._dates.map((date) => _OptionTile(
          label: date.replaceFirst('\n', ' - '),
          icon: Icons.calendar_today_outlined,
          selected: _date == date,
          onTap: () => setState(() => _date = date))),
      const SizedBox(height: 10),
      const _Heading('Select a time', 'All times are shown in Riyadh time.'),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _times.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10),
        itemBuilder: (_, i) => _TimeButton(
            label: _times[i],
            selected: _time == _times[i],
            onTap: () => setState(() => _time = _times[i])),
      ),
    ]);
  }

  Widget _visitDetails() => _page([
        const _Heading('Tell us about your visit',
            'This information helps your doctor prepare.'),
        _ctasQuestionnaire(),
        const SizedBox(height: 18),
        TextField(
            controller: _reason,
            onChanged: (_) => setState(() {}),
            decoration: _input('Reason for visit *', Icons.edit_note_outlined)),
        const SizedBox(height: 12),
        TextField(
            controller: _notes,
            maxLines: 4,
            decoration:
                _input('Symptoms or notes (optional)', Icons.notes_outlined)),
      ]);

  Widget _ctasQuestionnaire() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Preliminary safety screening',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text(
          'Please select all options that describe your current condition.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 14),
        for (final question in _ctasQuestions) ...[
          _CtasQuestionBlock(
            question: question,
            selectedAnswers: _ctasAnswers[question.level]!,
            noneLabel: _noneOfThese,
            onChanged: (answer) => _toggleCtasAnswer(question, answer),
          ),
          const SizedBox(height: 16),
        ],
        _ScreeningResultBanner(
          text: _allCtasQuestionsAnswered
              ? _preliminaryCtasText
              : 'Complete the screening questions before continuing.',
        ),
        const SizedBox(height: 6),
        const Text(
          'This screening supports preliminary prioritization only. It does not provide a medical diagnosis.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _emergencyAlert() {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: SingleChildScrollView(
        key: const ValueKey('emergency-alert'),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.emergency_outlined, size: 76, color: primary),
            const SizedBox(height: 18),
            const Text(
              'Immediate emergency help is required',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            const Text(
              'The selected symptom may indicate an immediate threat to life. Contact emergency services now or alert nearby medical staff.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 16),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: const Text(
                'Do not use this application as a substitute for emergency medical assistance.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _contactEmergencyServices,
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Contact emergency services'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.medical_information_outlined),
                label: const Text('I am already with medical staff'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bodyMeasurements() {
    return HeightWeightScannerPage(
      key: const ValueKey('height-weight-scanner-step'),
      embedded: true,
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _heightWeightResult = result;
          if (_step == 7) _step = 8;
        });
      },
    );
  }

  Widget _vitalSigns() {
    return RemoteVitalsMeasurementScreen(
      key: const ValueKey('remote-vitals-step'),
      embedded: true,
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _remoteVitalsResult = result;
          if (_step == 8) _step = 9;
        });
      },
    );
  }

  Widget _review() => _page([
        const _Heading(
            'Review your appointment', 'Check the details before confirming.'),
        if (_saveError != null) ...[
          Text(
            _saveError!,
            style: const TextStyle(
              color: Color(0xFFB42318),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _SummaryRow(
            icon: Icons.account_circle_outlined,
            label: 'Patient',
            value: _appointmentFor == 'Family'
                ? _familyMember!
                : AppSession.firstName),
        _SummaryRow(
            icon: Icons.person_outline, label: 'Doctor', value: _doctor!.name),
        _SummaryRow(
            icon: Icons.medical_services_outlined,
            label: 'Specialty',
            value: _doctor!.specialty),
        _SummaryRow(
            icon: Icons.shield_outlined,
            label: 'Insurance',
            value: _insurance!),
        _SummaryRow(
            icon: Icons.payments_outlined,
            label: 'Consultation fee',
            value: _doctor!.consultationFeeLabel),
        _SummaryRow(
            icon: Icons.location_city_outlined, label: 'City', value: _city!),
        _SummaryRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: _date!.replaceFirst('\n', ', ')),
        _SummaryRow(icon: Icons.schedule, label: 'Time', value: _time!),
        _SummaryRow(
            icon: Icons.edit_note_outlined,
            label: 'Reason',
            value: _reason.text),
        _SummaryRow(
            icon: Icons.assignment_turned_in_outlined,
            label: 'Preliminary screening',
            value: _preliminaryCtasText),
        _SummaryRow(
            icon: Icons.height_rounded,
            label: 'Height',
            value: '${_heightWeightResult!.heightCm.toStringAsFixed(1)} cm'),
        _SummaryRow(
            icon: Icons.monitor_weight_outlined,
            label: 'Weight',
            value: '${_heightWeightResult!.weightKg.toStringAsFixed(1)} kg'),
        _SummaryRow(
            icon: Icons.monitor_heart_outlined,
            label: 'Heart beat',
            value: '${_remoteVitalsResult!.heartRateBpm} bpm'),
        _SummaryRow(
            icon: Icons.air_rounded,
            label: 'Breathing',
            value: '${_remoteVitalsResult!.breathingRateRpm} rpm'),
        _SummaryRow(
            icon: Icons.health_and_safety_outlined,
            label: 'Blood pressure',
            value:
                '${_remoteVitalsResult!.systolic}/${_remoteVitalsResult!.diastolic} mmHg'),
        _SummaryRow(
            icon: Icons.water_drop_outlined,
            label: 'Oxygen',
            value: '${_remoteVitalsResult!.oxygenPercent}%'),
      ]);

  Widget _payment() => _page([
        const _Heading(
            'Payment', 'Choose how you want to pay for this appointment.'),
        if (_saveError != null) ...[
          Text(
            _saveError!,
            style: const TextStyle(
              color: Color(0xFFB42318),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _PaymentTotalCard(
          doctor: _doctor!,
          insurance: _insurance!,
        ),
        const SizedBox(height: 16),
        const Text('Payment method',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ...[
          ('Mada card', Icons.credit_card_outlined),
          ('Apple Pay', Icons.phone_iphone_outlined),
          ('Pay at clinic', Icons.local_hospital_outlined),
        ].map((method) => _OptionTile(
              label: method.$1,
              icon: method.$2,
              selected: _paymentMethod == method.$1,
              onTap: () => setState(() => _paymentMethod = method.$1),
            )),
      ]);

  Widget _confirmed() {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                      color: primary.withValues(alpha: .12),
                      shape: BoxShape.circle),
                  child: Icon(Icons.check_circle, color: primary, size: 72)),
              const SizedBox(height: 22),
              const Text('Appointment Confirmed',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Your appointment has been booked successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              _SummaryRow(
                  icon: Icons.person_outline,
                  label: _doctor!.name,
                  value: _doctor!.specialty),
              _SummaryRow(
                  icon: Icons.event_outlined,
                  label: _date!.replaceFirst('\n', ', '),
                  value: _time!),
              _SummaryRow(
                  icon: Icons.payments_outlined,
                  label: 'Payment',
                  value: '${_doctor!.consultationFeeLabel} - $_paymentMethod'),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AppShell()),
                          (route) => false),
                      child: const Text('Back to Home',
                          style: TextStyle(fontWeight: FontWeight.w800)))),
            ])));
  }

  InputDecoration _input(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none));

  Widget _page(List<Widget> children) => ListView(
      key: ValueKey(_step),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: children);

  Widget _continueButton() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
                onPressed: _canContinue && !_savingAppointment ? _next : null,
                child: _savingAppointment
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(_continueLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800)))),
      );

  String get _continueLabel => switch (_step) {
        9 => 'Continue to Payment',
        10 => 'Confirm & Pay',
        _ => 'Continue',
      };

  bool get _canContinue => switch (_step) {
        0 => _appointmentFor == 'Me' ||
            _appointmentFor == 'Family' && _familyMember != null,
        1 => _specialty != null,
        2 => _insurance != null,
        3 => _city != null,
        5 => _date != null && _time != null,
        6 => _reason.text.trim().isNotEmpty &&
            _allCtasQuestionsAnswered &&
            !_hasLevel1Emergency,
        7 => _heightWeightResult != null,
        8 => _remoteVitalsResult != null,
        10 => _paymentMethod != null,
        _ => true,
      };

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else if (widget.initialDoctor != null && _step == 5) {
      setState(() => _step = 0);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _next() async {
    if (_step == 10) {
      await _saveAppointment();
      return;
    }

    if (_step == 6 &&
        _preliminaryCtasLevel == 2 &&
        !_urgentWarningAcknowledged) {
      _showUrgentWarning();
      return;
    }

    _advanceStep();
  }

  Future<void> _saveAppointment() async {
    final patientId = AppSession.patientId;
    if (patientId == null) {
      setState(() => _saveError = 'Please sign in again before booking.');
      return;
    }

    setState(() {
      _savingAppointment = true;
      _saveError = null;
    });

    try {
      final appointment = await BackendApi.createAppointment(
        patientId: patientId,
        doctorName: _doctor!.name,
        dateLabel: _date!.replaceFirst('\n', ', '),
        timeLabel: _time!,
        reason: _reason.text.trim(),
        notes: _notes.text.trim(),
        ctasLevel: _preliminaryCtasLevel,
      );
      await _saveVitals(patientId: patientId, appointmentId: appointment.id);
      AppSession.setLatestAppointment(appointment);
      if (!mounted) return;
      setState(() => _step = _confirmedStep);
    } on BackendApiException catch (error) {
      if (!mounted) return;
      setState(() => _saveError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveError = 'Could not save the appointment.');
    } finally {
      if (mounted) {
        setState(() => _savingAppointment = false);
      }
    }
  }

  Future<void> _saveVitals({
    required String patientId,
    required String appointmentId,
  }) async {
    final heightWeight = _heightWeightResult;
    final remoteVitals = _remoteVitalsResult;
    if (heightWeight == null || remoteVitals == null) return;

    final vitals = [
      {
        'vital_type': 'Height',
        'value': '${heightWeight.heightCm.toStringAsFixed(1)} cm',
        'source': 'camera',
      },
      {
        'vital_type': 'Weight',
        'value': '${heightWeight.weightKg.toStringAsFixed(1)} kg',
        'source': 'camera',
      },
      {
        'vital_type': 'Heart Rate',
        'value': '${remoteVitals.heartRateBpm} bpm',
        'source': 'app',
      },
      {
        'vital_type': 'Blood Pressure',
        'value': '${remoteVitals.systolic}/${remoteVitals.diastolic} mmHg',
        'source': 'app',
      },
      {
        'vital_type': 'Oxygen',
        'value': '${remoteVitals.oxygenPercent}%',
        'source': 'app',
      },
      {
        'vital_type': 'Breathing Rate',
        'value': '${remoteVitals.breathingRateRpm} rpm',
        'source': 'app',
      },
    ];

    if (remoteVitals.hasVerifiedTemperature) {
      vitals.add({
        'vital_type': 'Temperature',
        'value': '${remoteVitals.temperatureC!.toStringAsFixed(1)} C',
        'source': 'camera',
      });
    }

    await BackendApi.createVitals(
      patientId: patientId,
      appointmentId: appointmentId,
      vitals: vitals,
    );
  }

  void _advanceStep() {
    setState(() {
      if (_step == 0 && widget.initialDoctor != null) {
        _step = 5;
      } else {
        _step++;
      }
    });
  }

  void _toggleCtasAnswer(_CtasQuestion question, String answer) {
    setState(() {
      final answers = _ctasAnswers[question.level]!;
      if (answer == _noneOfThese) {
        answers
          ..clear()
          ..add(answer);
      } else if (answers.contains(answer)) {
        answers.remove(answer);
      } else {
        answers
          ..remove(_noneOfThese)
          ..add(answer);
      }
      _urgentWarningAcknowledged = false;
    });
  }

  void _contactEmergencyServices() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Call emergency services: $_emergencyNumber'),
      ),
    );
  }

  Future<void> _showUrgentWarning() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Urgent medical assessment may be required'),
        content: const Text(
          'Your answers suggest that you may require rapid medical attention. Do not wait for a routine appointment if your symptoms are severe, worsening, or you feel unsafe.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showUrgentCareInstructions();
            },
            child: const Text('View urgent-care instructions'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              setState(() => _urgentWarningAcknowledged = true);
              _advanceStep();
            },
            child: const Text('Continue and send answers'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUrgentCareInstructions() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Urgent-care instructions'),
        content: const Text(
          'If symptoms are severe, worsening, or you feel unsafe, seek urgent medical care now or contact local emergency services. This app does not provide a diagnosis.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _CtasQuestion {
  const _CtasQuestion({
    required this.level,
    required this.heading,
    required this.options,
  });

  final int level;
  final String heading;
  final List<String> options;
}

class _CtasQuestionBlock extends StatelessWidget {
  const _CtasQuestionBlock({
    required this.question,
    required this.selectedAnswers,
    required this.noneLabel,
    required this.onChanged,
  });

  final _CtasQuestion question;
  final Set<String> selectedAnswers;
  final String noneLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.heading,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        for (final option in question.options)
          _CtasOptionCard(
            text: option,
            selected: selectedAnswers.contains(option),
            isNoneOption: option == noneLabel,
            onTap: () => onChanged(option),
          ),
      ],
    );
  }
}

class _CtasOptionCard extends StatelessWidget {
  const _CtasOptionCard({
    required this.text,
    required this.selected,
    required this.isNoneOption,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool isNoneOption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? primary.withValues(alpha: .1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? primary : Colors.black12,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: selected ? primary : Colors.black45,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontWeight: selected || isNoneOption
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
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

class _ScreeningResultBanner extends StatelessWidget {
  const _ScreeningResultBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety_outlined, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child:
                Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: Colors.black54))
      ]));
}

class _SelectCard extends StatelessWidget {
  const _SelectCard(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
        color: selected ? primary.withValues(alpha: .1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: selected ? primary : Colors.black12,
                        width: selected ? 2 : 1),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: primary),
                      const SizedBox(height: 7),
                      Text(label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800))
                    ]))));
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
            side: BorderSide(
                color: selected ? primary : Colors.transparent, width: 2),
            borderRadius: BorderRadius.circular(18)),
        child: ListTile(
            onTap: onTap,
            leading: Icon(icon, color: primary),
            title: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? primary : Colors.black26),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18))));
  }
}

class _DoctorTile extends StatelessWidget {
  const _DoctorTile({required this.doctor, required this.onTap});
  final Doctor doctor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: Colors.white,
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  CircleAvatar(
                      radius: 31,
                      backgroundColor: primary.withValues(alpha: .12),
                      child:
                          Icon(Icons.person_outline, color: primary, size: 34)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(doctor.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        Text(doctor.specialty,
                            style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        Text(doctor.clinic,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                            '${doctor.city} - ${doctor.rating} rating - ${doctor.years} years',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.payments_outlined,
                                color: primary, size: 15),
                            const SizedBox(width: 4),
                            Text(
                              doctor.consultationFeeLabel,
                              style: TextStyle(
                                  color: primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ])),
                  const Icon(Icons.chevron_right)
                ]))));
  }
}

class _PaymentTotalCard extends StatelessWidget {
  const _PaymentTotalCard({required this.doctor, required this.insurance});

  final Doctor doctor;
  final String insurance;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: primary),
              const SizedBox(width: 10),
              const Text('Amount due',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Consultation fee',
                  style: TextStyle(
                      color: Colors.black54, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(doctor.consultationFeeLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Insurance',
                  style: TextStyle(
                      color: Colors.black54, fontWeight: FontWeight.w700)),
              const Spacer(),
              Flexible(
                child: Text(
                  insurance,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(doctor.consultationFeeLabel,
                  style: TextStyle(
                      color: primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: primary),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
          backgroundColor:
              selected ? Theme.of(context).colorScheme.primary : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.black87),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12))
      ]));
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(value,
              style: const TextStyle(color: Colors.black54, fontSize: 13))
        ]))
      ]));
}
