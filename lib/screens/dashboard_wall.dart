import 'package:flutter/material.dart';

import '../services/backend_api.dart';
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
  late Future<_DoctorWallData> _future;
  _DoctorWallPatient? _historyPatient;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DoctorWallData> _load() async {
    final doctors = await BackendApi.listDoctors();
    if (doctors.isEmpty) {
      throw BackendApiException('No doctors found.');
    }
    final doctor = doctors.firstWhere(
      (item) => item.fullName == 'Dr. Moashir Demo',
      orElse: () => doctors.first,
    );
    try {
      final appointments =
          await BackendApi.listDoctorAppointments(doctorId: doctor.id);
      final List<BackendPatient> fallbackPatients =
          appointments.isEmpty ? await BackendApi.listPatients() : const [];
      return _DoctorWallData(
        doctor: doctor,
        appointments: appointments,
        fallbackPatients: fallbackPatients,
      );
    } catch (_) {
      final patients = await BackendApi.listPatients();
      return _DoctorWallData(
        doctor: doctor,
        appointments: const [],
        fallbackPatients: patients,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyPatient = _historyPatient;
    if (historyPatient != null) {
      return _DoctorWallHistory(
        patient: historyPatient,
        onBack: () => setState(() => _historyPatient = null),
      );
    }

    return FutureBuilder<_DoctorWallData>(
      future: _future,
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
              _future = _load();
            }),
          );
        }
        return _DoctorWallHome(
          data: snapshot.requireData,
          onOpenHistory: (patient) => setState(() => _historyPatient = patient),
        );
      },
    );
  }
}

class _DoctorWallData {
  const _DoctorWallData({
    required this.doctor,
    required this.appointments,
    required this.fallbackPatients,
  });

  final BackendDoctor doctor;
  final List<BackendAppointment> appointments;
  final List<BackendPatient> fallbackPatients;
}

class _DoctorWallPatient {
  const _DoctorWallPatient({
    required this.patientId,
    required this.name,
    required this.initials,
    required this.reason,
    required this.time,
    required this.status,
    required this.gender,
    required this.dateOfBirth,
    required this.bloodType,
    required this.ctasLabel,
    required this.allergies,
  });

  final String patientId;
  final String name;
  final String initials;
  final String reason;
  final String time;
  final String status;
  final String gender;
  final String dateOfBirth;
  final String bloodType;
  final String ctasLabel;
  final List<String> allergies;
}

class _DoctorWallHome extends StatelessWidget {
  const _DoctorWallHome({
    required this.data,
    required this.onOpenHistory,
  });

  final _DoctorWallData data;
  final ValueChanged<_DoctorWallPatient> onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final patients = data.appointments.isNotEmpty
        ? data.appointments.map(_patientFromAppointment).toList()
        : data.fallbackPatients.map(_patientFromProfile).toList();
    final upcoming =
        patients.where((patient) => patient.status == 'Upcoming').toList();
    final previous =
        patients.where((patient) => patient.status == 'Previous').toList();
    final nextPatient = upcoming.isEmpty ? null : upcoming.first;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F4),
      bottomNavigationBar: const _DoctorWallNav(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome back,',
                          style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(
                        data.doctor.fullName,
                        style: TextStyle(
                          color: primary,
                          fontSize: 28,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.medical_services_outlined,
                              size: 15, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(data.doctor.specialty,
                              style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primary.withValues(alpha: .12),
                  child: Icon(Icons.notifications_none, color: primary),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primary.withValues(alpha: .12),
                  child: Text(
                    _initials(data.doctor.fullName),
                    style:
                        TextStyle(color: primary, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          color: Colors.white70, size: 16),
                      SizedBox(width: 7),
                      Text('Next Patient',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    nextPatient?.name ?? 'No upcoming patient',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nextPatient?.reason ?? 'New bookings will appear here.',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 18),
                  Text(nextPatient?.time ?? '',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DoctorWallMetric(
                    icon: Icons.groups_outlined,
                    value: '${upcoming.length}',
                    label: 'Upcoming patients',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DoctorWallMetric(
                    icon: Icons.assignment_outlined,
                    value: '${previous.length}',
                    label: 'Previous patients',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Patients',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (patients.isEmpty)
              const _DoctorWallEmpty('No patients yet.')
            else
              for (final patient in patients)
                _DoctorWallPatientCard(
                  patient: patient,
                  onOpenHistory: () => onOpenHistory(patient),
                ),
          ],
        ),
      ),
    );
  }

  _DoctorWallPatient _patientFromAppointment(BackendAppointment appointment) {
    final patient = appointment.patient ?? const <String, dynamic>{};
    final name = _stringValue(patient['full_name'], fallback: 'Patient');
    final date =
        appointment.displayDate.isEmpty ? 'Scheduled' : appointment.displayDate;
    final time =
        appointment.timeLabel.isEmpty ? '' : ' - ${appointment.timeLabel}';
    return _DoctorWallPatient(
      patientId: appointment.patientId,
      name: name,
      initials: _initials(name),
      reason: appointment.reason.isEmpty ? 'Visit' : appointment.reason,
      time: '$date$time',
      status:
          appointment.status == 'completed' || appointment.status == 'cancelled'
              ? 'Previous'
              : 'Upcoming',
      gender: _stringValue(patient['gender']),
      dateOfBirth: _stringValue(patient['date_of_birth']),
      bloodType: _stringValue(patient['blood_type']),
      ctasLabel: appointment.ctasLevel == null
          ? 'CTAS 5'
          : 'CTAS ${appointment.ctasLevel}',
      allergies: _allergiesForPatient(name),
    );
  }

  _DoctorWallPatient _patientFromProfile(BackendPatient patient) {
    return _DoctorWallPatient(
      patientId: patient.id,
      name: patient.fullName,
      initials: patient.initials,
      reason: 'Medical history review',
      time: 'From patient record',
      status: 'Upcoming',
      gender: patient.gender,
      dateOfBirth: patient.dateOfBirth,
      bloodType: patient.bloodType,
      ctasLabel: 'CTAS 5',
      allergies: _allergiesForPatient(patient.fullName),
    );
  }
}

class _DoctorWallHistory extends StatefulWidget {
  const _DoctorWallHistory({
    required this.patient,
    required this.onBack,
  });

  final _DoctorWallPatient patient;
  final VoidCallback onBack;

  @override
  State<_DoctorWallHistory> createState() => _DoctorWallHistoryState();
}

class _DoctorWallHistoryState extends State<_DoctorWallHistory> {
  late Future<_DoctorWallHistoryData> _future = _load();

  Future<_DoctorWallHistoryData> _load() async {
    if (widget.patient.patientId.isEmpty) {
      return const _DoctorWallHistoryData(vitals: [], medications: []);
    }
    final results = await Future.wait([
      BackendApi.listVitals(patientId: widget.patient.patientId),
      BackendApi.listMedications(patientId: widget.patient.patientId),
    ]);
    return _DoctorWallHistoryData(
      vitals: results[0] as List<BackendVital>,
      medications: results[1] as List<BackendMedication>,
    );
  }

  Future<void> _setApproval(BackendVital vital, String status) async {
    try {
      await BackendApi.updateVitalApproval(
        vitalId: vital.id,
        approvalStatus: status,
      );
      if (!mounted) return;
      setState(() => _future = _load());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update vital approval.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFFFF5),
      body: SafeArea(
        child: FutureBuilder<_DoctorWallHistoryData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.chevron_left),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Medical History',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 18),
                _DoctorWallHistoryHeader(patient: widget.patient),
                const SizedBox(height: 22),
                const _DoctorWallSectionTitle(
                  icon: Icons.badge_outlined,
                  title: 'Patient Details',
                ),
                const SizedBox(height: 12),
                _DoctorWallPatientDetails(patient: widget.patient),
                const SizedBox(height: 22),
                const _DoctorWallSectionTitle(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Vitals review - doctor approval',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Confirm each latest vital sign or request a retake.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 14),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  _DoctorWallRetry(
                    message: 'Could not load medical history.',
                    onRetry: () => setState(() => _future = _load()),
                  )
                else if (data == null || data.vitals.isEmpty)
                  const _DoctorWallEmpty('No vitals recorded yet.')
                else
                  for (final vital in _latestVitals(data.vitals))
                    _DoctorWallVitalCard(
                      vital: vital,
                      onConfirm: () => _setApproval(vital, 'confirmed'),
                      onRetake: () => _setApproval(vital, 'retake_requested'),
                    ),
                const SizedBox(height: 18),
                const _DoctorWallSectionTitle(
                  icon: Icons.medication_outlined,
                  title: 'Current Medications',
                ),
                const SizedBox(height: 12),
                if (data == null || data.medications.isEmpty)
                  const _DoctorWallEmpty('No medications recorded.')
                else
                  for (final medication in data.medications)
                    _DoctorWallMedicationCard(medication: medication),
              ],
            );
          },
        ),
      ),
    );
  }

  List<BackendVital> _latestVitals(List<BackendVital> vitals) {
    final grouped = <String, BackendVital>{};
    for (final vital in vitals) {
      final key = _normalizeVitalName(vital.vitalType);
      grouped.putIfAbsent(key, () => vital);
    }
    const order = [
      'temperature',
      'height',
      'weight',
      'bloodpressure',
      'heartrate',
      'oxygen',
      'breathingrate',
    ];
    return [
      for (final key in order)
        if (grouped[key] != null) grouped[key]!,
      ...grouped.entries
          .where((entry) => !order.contains(entry.key))
          .map((entry) => entry.value),
    ];
  }
}

class _DoctorWallHistoryData {
  const _DoctorWallHistoryData({
    required this.vitals,
    required this.medications,
  });

  final List<BackendVital> vitals;
  final List<BackendMedication> medications;
}

class _DoctorWallMetric extends StatelessWidget {
  const _DoctorWallMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            backgroundColor: primary.withValues(alpha: .16),
            child: Icon(icon, color: primary),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              Text(label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoctorWallPatientCard extends StatelessWidget {
  const _DoctorWallPatientCard({
    required this.patient,
    required this.onOpenHistory,
  });

  final _DoctorWallPatient patient;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final upcoming = patient.status == 'Upcoming';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFD4F5DE),
                child: Text(patient.initials,
                    style:
                        TextStyle(color: primary, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(patient.reason,
                        style: TextStyle(
                            color: primary, fontWeight: FontWeight.w800)),
                    Text(patient.time,
                        style: const TextStyle(
                            color: Colors.black45, fontSize: 12)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DoctorWallPatientInfoChip(
                    icon: Icons.priority_high_rounded,
                    label: patient.ctasLabel,
                    color: _ctasColor(patient.ctasLabel),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: upcoming
                          ? const Color(0xFFD4F5DE)
                          : const Color(0xFFE9F1EC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      patient.status,
                      style: TextStyle(
                        color: upcoming ? primary : Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: onOpenHistory,
              icon: const Icon(Icons.assignment_outlined, size: 16),
              label: const Text('Medical History'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD4F5DE),
                foregroundColor: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorWallHistoryHeader extends StatelessWidget {
  const _DoctorWallHistoryHeader({required this.patient});

  final _DoctorWallPatient patient;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: primary.withValues(alpha: .15),
            child: Text(
              patient.initials,
              style: TextStyle(color: primary, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (patient.dateOfBirth.isNotEmpty) patient.dateOfBirth,
                    if (patient.gender.isNotEmpty) patient.gender,
                    if (patient.bloodType.isNotEmpty) patient.bloodType,
                  ].join(' - '),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(patient.reason,
                    style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorWallPatientDetails extends StatelessWidget {
  const _DoctorWallPatientDetails({required this.patient});

  final _DoctorWallPatient patient;

  @override
  Widget build(BuildContext context) {
    final allergies =
        patient.allergies.isEmpty ? const ['None recorded'] : patient.allergies;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _DoctorWallDetailTile(
                  icon: Icons.water_drop_outlined,
                  label: 'Blood Type',
                  value: patient.bloodType.isEmpty
                      ? 'Not recorded'
                      : patient.bloodType,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DoctorWallDetailTile(
                  icon: Icons.priority_high_rounded,
                  label: 'Triage',
                  value: patient.ctasLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Allergies',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final allergy in allergies)
                _DoctorWallAllergyChip(label: allergy),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoctorWallDetailTile extends StatelessWidget {
  const _DoctorWallDetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFFF5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary, size: 18),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _DoctorWallAllergyChip extends StatelessWidget {
  const _DoctorWallAllergyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D6),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFFE7A323).withValues(alpha: .35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF7B4A00),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DoctorWallPatientInfoChip extends StatelessWidget {
  const _DoctorWallPatientInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorWallVitalCard extends StatelessWidget {
  const _DoctorWallVitalCard({
    required this.vital,
    required this.onConfirm,
    required this.onRetake,
  });

  final BackendVital vital;
  final VoidCallback onConfirm;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final status = switch (vital.approvalStatus) {
      'confirmed' => 'Confirmed',
      'retake_requested' => 'Retake requested',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_displayVitalTitle(vital.vitalType),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              _DoctorWallStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F8E8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primary.withValues(alpha: .18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_sourceIcon(vital.source),
                        size: 15, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(_sourceLabel(vital.source),
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 7),
                Text(_displayValue(vital.value),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Confirm'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: onRetake,
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Retake'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoctorWallMedicationCard extends StatelessWidget {
  const _DoctorWallMedicationCard({required this.medication});

  final BackendMedication medication;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        '${medication.name}\n${_displayValue(medication.dose)} - ${_displayValue(medication.schedule)}',
        style: const TextStyle(height: 1.35),
      ),
    );
  }
}

class _DoctorWallSectionTitle extends StatelessWidget {
  const _DoctorWallSectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, color: primary, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _DoctorWallStatusBadge extends StatelessWidget {
  const _DoctorWallStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status == 'Confirmed'
            ? const Color(0xFFD4F5DE)
            : const Color(0xFFE9F1EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: status == 'Confirmed' ? primary : Colors.black54,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DoctorWallEmpty extends StatelessWidget {
  const _DoctorWallEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(message, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _DoctorWallRetry extends StatelessWidget {
  const _DoctorWallRetry({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _DoctorWallNav extends StatelessWidget {
  const _DoctorWallNav();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 78,
      color: const Color(0xFFEFF4EE),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.home, color: primary, size: 22),
                ),
                const SizedBox(height: 3),
                Text('Home', style: TextStyle(color: primary, fontSize: 12)),
              ],
            ),
          ),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.black54),
                SizedBox(height: 3),
                Text('Chat',
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, color: Colors.black54),
                SizedBox(height: 3),
                Text('Profile',
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _stringValue(dynamic value, {String fallback = ''}) {
  return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}

String _initials(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'DR';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _normalizeVitalName(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _displayVitalTitle(String value) {
  final normalized = _normalizeVitalName(value);
  return switch (normalized) {
    'bloodpressure' => 'Blood Pressure',
    'heartrate' => 'Heart Rate',
    'breathingrate' => 'Breathing Rate',
    'bodytemperature' || 'temperature' => 'Temperature',
    'height' => 'Height',
    'weight' => 'Weight',
    'oxygen' => 'Oxygen',
    _ => value.trim().isEmpty ? 'Vital sign' : value.trim(),
  };
}

String _sourceLabel(String source) {
  return switch (source.toLowerCase()) {
    'camera' => 'From camera',
    'manual' => 'Manual entry',
    'device' => 'From device',
    _ => 'From app',
  };
}

IconData _sourceIcon(String source) {
  return switch (source.toLowerCase()) {
    'camera' => Icons.photo_camera_outlined,
    'manual' => Icons.edit_note_outlined,
    _ => Icons.monitor_heart_outlined,
  };
}

Color _ctasColor(String ctasLabel) {
  final level = int.tryParse(ctasLabel.replaceAll(RegExp(r'[^0-9]'), ''));
  return switch (level) {
    1 => const Color(0xFFB00020),
    2 => const Color(0xFFC75B00),
    3 => const Color(0xFF946200),
    4 => const Color(0xFF006D9C),
    _ => const Color(0xFF0B6B39),
  };
}

List<String> _allergiesForPatient(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('fahad')) {
    return const ['Penicillin', 'Dust'];
  }
  if (normalized.contains('noura')) {
    return const ['Seasonal pollen'];
  }
  return const ['None recorded'];
}

String _displayValue(String value) {
  return value.trim().isEmpty ? 'Not recorded' : value.trim();
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
