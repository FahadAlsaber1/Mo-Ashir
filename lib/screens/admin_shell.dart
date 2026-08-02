import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/backend_api.dart';
import 'thermal_camera_feed_stub.dart'
    if (dart.library.html) 'thermal_camera_feed_web.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late Future<_AdminDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<_AdminDashboardData> _loadDashboard() async {
    final results = await Future.wait([
      BackendApi.listDoctors(),
      BackendApi.listPatients(),
      BackendApi.listDoctorReviews(),
    ]);
    final doctors = results[0] as List<BackendDoctor>;
    final appointmentsByDoctor = <String, List<BackendAppointment>>{};
    final appointmentResults = await Future.wait(
      doctors.map((doctor) async {
        try {
          return MapEntry(
            doctor.id,
            await BackendApi.listDoctorAppointments(doctorId: doctor.id),
          );
        } catch (_) {
          return MapEntry(doctor.id, const <BackendAppointment>[]);
        }
      }),
    );
    appointmentsByDoctor.addEntries(appointmentResults);
    return _AdminDashboardData(
      doctors: doctors,
      patients: results[1] as List<BackendPatient>,
      reviews: results[2] as List<BackendDoctorReview>,
      appointmentsByDoctor: appointmentsByDoctor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                setState(() => _dashboardFuture = _loadDashboard()),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () {
              AppSession.clear();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<_AdminDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _AdminEmptyState(
              title: 'Could not load Hospital dashboard.',
              onRetry: () =>
                  setState(() => _dashboardFuture = _loadDashboard()),
            );
          }

          final data = snapshot.data ?? _AdminDashboardData.empty();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Welcome, ${AppSession.firstName}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Monitor registered doctors and patients.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _AdminMetricCard(
                      icon: Icons.medical_services_outlined,
                      value: '${data.doctors.length}',
                      label: 'Doctors',
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdminMetricCard(
                      icon: Icons.groups_outlined,
                      value: '${data.patients.length}',
                      label: 'Patients',
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _ThermalCameraControlCard(),
              const SizedBox(height: 24),
              const _AdminSectionTitle('Doctors'),
              const SizedBox(height: 10),
              if (data.doctors.isEmpty)
                const _AdminPlainCard('No doctors registered.')
              else
                for (final doctor in data.doctors)
                  _AdminDoctorCard(
                    doctor: doctor,
                    appointments:
                        data.appointmentsByDoctor[doctor.id] ?? const [],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _AdminDoctorPatientsScreen(
                          doctor: doctor,
                          appointments:
                              data.appointmentsByDoctor[doctor.id] ?? const [],
                          patients: data.patients,
                          reviews: data.reviews
                              .where((review) => review.doctorId == doctor.id)
                              .toList(),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminDashboardData {
  const _AdminDashboardData({
    required this.doctors,
    required this.patients,
    required this.reviews,
    required this.appointmentsByDoctor,
  });

  factory _AdminDashboardData.empty() {
    return const _AdminDashboardData(
      doctors: [],
      patients: [],
      reviews: [],
      appointmentsByDoctor: {},
    );
  }

  final List<BackendDoctor> doctors;
  final List<BackendPatient> patients;
  final List<BackendDoctorReview> reviews;
  final Map<String, List<BackendAppointment>> appointmentsByDoctor;
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _AdminSectionTitle extends StatelessWidget {
  const _AdminSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _ThermalCameraControlCard extends StatefulWidget {
  const _ThermalCameraControlCard();

  @override
  State<_ThermalCameraControlCard> createState() =>
      _ThermalCameraControlCardState();
}

class _ThermalCameraControlCardState extends State<_ThermalCameraControlCard> {
  late Future<BackendThermalCameraStatus> _statusFuture;
  Timer? _refreshTimer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _statusFuture = BackendApi.getThermalCameraStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _busy) return;
      setState(() => _statusFuture = BackendApi.getThermalCameraStatus());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggle(BackendThermalCameraStatus status) async {
    setState(() => _busy = true);
    try {
      final updated = status.running
          ? await BackendApi.stopThermalCamera()
          : await BackendApi.startThermalCamera();
      if (!mounted) return;
      setState(() {
        _statusFuture = Future.value(updated);
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updated.message)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusFuture = BackendApi.getThermalCameraStatus();
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thermal camera control failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return FutureBuilder<BackendThermalCameraStatus>(
      future: _statusFuture,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final running = status?.running == true;
        final commandPending = status?.commandPending == true;
        final loading = snapshot.connectionState == ConnectionState.waiting ||
            _busy ||
            commandPending;
        final statusText = snapshot.hasError
            ? 'Status unavailable'
            : commandPending
                ? status?.desiredState == 'on'
                    ? 'Turning thermal camera on...'
                    : 'Turning thermal camera off...'
                : status?.online != true
                    ? 'Thermal camera station is offline'
                    : running
                        ? 'Thermal camera is on'
                        : 'Thermal camera is off';
        final statusColor = commandPending
            ? const Color(0xFF9A6700)
            : running
                ? const Color(0xFF167A3A)
                : Colors.black54;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.thermostat_outlined, color: primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Thermal camera',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    running
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      loading || status == null ? null : () => _toggle(status),
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          running
                              ? Icons.power_settings_new
                              : Icons.play_arrow_rounded,
                        ),
                  label: Text(
                    commandPending
                        ? 'Command pending'
                        : running
                            ? 'Turn thermal camera off'
                            : 'Turn thermal camera on',
                  ),
                ),
              ),
              if (running) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF101418),
                        border: Border.all(color: const Color(0xFFE3E7EA)),
                      ),
                      child: ThermalCameraFeed(streamUrl: status!.streamUrl),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AdminDoctorReviewCard extends StatelessWidget {
  const _AdminDoctorReviewCard({required this.review});

  final BackendDoctorReview review;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: primary.withValues(alpha: .12),
                child: Icon(Icons.star, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Reviewed by ${review.patientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _AdminRatingStars(rating: review.rating),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in review.tags.take(4))
                  _AdminReviewTag(label: tag),
              ],
            ),
          ],
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminRatingStars extends StatelessWidget {
  const _AdminRatingStars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star : Icons.star_border,
            color:
                i <= rating ? const Color(0xFFFFB703) : const Color(0xFFB8C2BB),
            size: 14,
          ),
      ],
    );
  }
}

class _AdminReviewTag extends StatelessWidget {
  const _AdminReviewTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AdminDoctorCard extends StatelessWidget {
  const _AdminDoctorCard({
    required this.doctor,
    required this.appointments,
    required this.onTap,
  });

  final BackendDoctor doctor;
  final List<BackendAppointment> appointments;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final activeAppointments = appointments
        .where(
            (item) => item.status != 'completed' && item.status != 'cancelled')
        .toList();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: primary.withValues(alpha: .12),
              child: Icon(Icons.person_outline, color: primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${doctor.specialty} - ${doctor.clinicName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _AdminStatusBadge(
              label: '${activeAppointments.length}',
              color: primary,
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: primary),
          ],
        ),
      ),
    );
  }
}

class _AdminDoctorPatientsScreen extends StatelessWidget {
  const _AdminDoctorPatientsScreen({
    required this.doctor,
    required this.appointments,
    required this.patients,
    required this.reviews,
  });

  final BackendDoctor doctor;
  final List<BackendAppointment> appointments;
  final List<BackendPatient> patients;
  final List<BackendDoctorReview> reviews;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final activeAppointments = appointments
        .where(
            (item) => item.status != 'completed' && item.status != 'cancelled')
        .toList();
    final visibleAppointments = activeAppointments.isEmpty
        ? appointments.take(5).toList()
        : activeAppointments;

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Patients')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primary.withValues(alpha: .12),
                  child: Icon(Icons.person_outline, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${doctor.specialty} - ${doctor.clinicName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _AdminStatusBadge(
                  label: '${activeAppointments.length}',
                  color: primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _AdminSectionTitle('Doctor reviews'),
          const SizedBox(height: 10),
          if (reviews.isEmpty)
            const _AdminPlainCard('No reviews for this doctor yet.')
          else
            for (final review in reviews.take(5))
              _AdminDoctorReviewCard(review: review),
          const SizedBox(height: 20),
          const _AdminSectionTitle('Patients'),
          const SizedBox(height: 10),
          if (visibleAppointments.isEmpty)
            const _AdminPlainCard('No patients assigned.')
          else
            for (final appointment in visibleAppointments)
              _AdminPatientAppointmentRow(
                patientName: _patientName(appointment),
                subtitle: _appointmentSubtitle(appointment),
                doctorName: doctor.fullName,
                status: _statusLabel(appointment.status),
                statusColor: _statusColor(appointment.status, primary),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _AdminPatientTimingScreen(
                      appointment: appointment,
                      patientName: _patientName(appointment),
                      doctorName: doctor.fullName,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _patientName(BackendAppointment appointment) {
    final patient = appointment.patient;
    final payloadName = patient?['full_name'];
    if (payloadName is String && payloadName.trim().isNotEmpty) {
      return payloadName.trim();
    }
    for (final item in patients) {
      if (item.id == appointment.patientId) return item.fullName;
    }
    return 'Patient';
  }

  String _appointmentSubtitle(BackendAppointment appointment) {
    final time = [
      if (appointment.displayDate.isNotEmpty) appointment.displayDate,
      if (appointment.timeLabel.isNotEmpty) appointment.timeLabel,
    ].join(' - ');
    final reason = appointment.reason.isEmpty ? 'Visit' : appointment.reason;
    return time.isEmpty ? reason : '$reason - $time';
  }

  String _statusLabel(String status) {
    return switch (status) {
      'checked_in' => 'Checked in',
      'in_clinic' => 'In clinic',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => 'Scheduled',
    };
  }

  Color _statusColor(String status, Color primary) {
    return switch (status) {
      'checked_in' || 'in_clinic' => primary,
      'completed' => Colors.black54,
      'cancelled' => const Color(0xFFB00020),
      _ => const Color(0xFFC75B00),
    };
  }
}

class _AdminPatientAppointmentRow extends StatelessWidget {
  const _AdminPatientAppointmentRow({
    required this.patientName,
    required this.subtitle,
    required this.doctorName,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  final String patientName;
  final String subtitle;
  final String doctorName;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.badge_outlined, color: primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  Text(
                    doctorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _AdminStatusBadge(label: status, color: statusColor),
          ],
        ),
      ),
    );
  }
}

class _AdminPatientTimingScreen extends StatefulWidget {
  const _AdminPatientTimingScreen({
    required this.appointment,
    required this.patientName,
    required this.doctorName,
  });

  final BackendAppointment appointment;
  final String patientName;
  final String doctorName;

  @override
  State<_AdminPatientTimingScreen> createState() =>
      _AdminPatientTimingScreenState();
}

class _AdminPatientTimingScreenState extends State<_AdminPatientTimingScreen> {
  late Future<List<BackendMedication>> _medicationsFuture;

  @override
  void initState() {
    super.initState();
    _medicationsFuture = _loadMedications();
  }

  Future<List<BackendMedication>> _loadMedications() {
    final patientId = widget.appointment.patientId.trim();
    if (patientId.isEmpty) return Future.value(const []);
    return BackendApi.listMedications(patientId: patientId);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Patient timing')),
      body: FutureBuilder<List<BackendMedication>>(
        future: _medicationsFuture,
        builder: (context, snapshot) {
          final medications = snapshot.data ?? const <BackendMedication>[];
          final pharmacyConfirmedAt = _pharmacyConfirmedAt(medications);
          final enteredAt = _enteredAt(widget.appointment);
          final elapsed = enteredAt == null || pharmacyConfirmedAt == null
              ? null
              : pharmacyConfirmedAt.difference(enteredAt);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primary.withValues(alpha: .12),
                      child: Text(
                        _initials(widget.patientName),
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.patientName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            widget.doctorName,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _AdminTimingCard(
                icon: Icons.login_outlined,
                title: 'Entered hospital',
                value: _formatDateTime(enteredAt),
              ),
              _AdminTimingCard(
                icon: Icons.local_pharmacy_outlined,
                title: 'Pharmacy confirmed',
                value: _formatDateTime(pharmacyConfirmedAt),
              ),
              _AdminTimingCard(
                icon: Icons.timer_outlined,
                title: 'Total time',
                value: elapsed == null
                    ? 'Not confirmed yet'
                    : _formatDuration(elapsed),
                highlight: true,
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Could not load pharmacy confirmation.',
                    style:
                        TextStyle(color: primary, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  DateTime? _enteredAt(BackendAppointment appointment) {
    if (appointment.status == 'checked_in' ||
        appointment.status == 'in_clinic') {
      return _parseDateTime(appointment.updatedAt) ??
          _parseDateTime(appointment.createdAt);
    }
    return _parseDateTime(appointment.createdAt);
  }

  DateTime? _pharmacyConfirmedAt(List<BackendMedication> medications) {
    if (medications.isEmpty) return null;
    final sorted = [...medications]..sort((a, b) {
        final aTime =
            _parseDateTime(a.updatedAt) ?? _parseDateTime(a.createdAt);
        final bTime =
            _parseDateTime(b.updatedAt) ?? _parseDateTime(b.createdAt);
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
    final medication = sorted.first;
    return _parseDateTime(medication.updatedAt) ??
        _parseDateTime(medication.createdAt);
  }

  DateTime? _parseDateTime(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Not recorded';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return 'Not available';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${duration.inMinutes} min';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'PT';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _AdminTimingCard extends StatelessWidget {
  const _AdminTimingCard({
    required this.icon,
    required this.title,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? primary : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: highlight ? Colors.white : primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: highlight ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStatusBadge extends StatelessWidget {
  const _AdminStatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AdminPlainCard extends StatelessWidget {
  const _AdminPlainCard(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings_outlined,
                color: Theme.of(context).colorScheme.primary, size: 48),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
