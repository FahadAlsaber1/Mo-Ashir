import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/backend_api.dart';

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
      appointmentsByDoctor: appointmentsByDoctor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospitel'),
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
              title: 'Could not load Hospitel dashboard.',
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
              const _AdminSectionTitle('Doctors with patients'),
              const SizedBox(height: 10),
              if (data.doctors.isEmpty)
                const _AdminPlainCard('No doctors registered.')
              else
                for (final doctor in data.doctors)
                  _AdminDoctorPatientCard(
                    doctor: doctor,
                    appointments:
                        data.appointmentsByDoctor[doctor.id] ?? const [],
                    patients: data.patients,
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
    required this.appointmentsByDoctor,
  });

  factory _AdminDashboardData.empty() {
    return const _AdminDashboardData(
      doctors: [],
      patients: [],
      appointmentsByDoctor: {},
    );
  }

  final List<BackendDoctor> doctors;
  final List<BackendPatient> patients;
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

class _AdminListTile extends StatelessWidget {
  const _AdminListTile({
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDoctorPatientCard extends StatelessWidget {
  const _AdminDoctorPatientCard({
    required this.doctor,
    required this.appointments,
    required this.patients,
  });

  final BackendDoctor doctor;
  final List<BackendAppointment> appointments;
  final List<BackendPatient> patients;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final activeAppointments = appointments
        .where(
            (item) => item.status != 'completed' && item.status != 'cancelled')
        .toList();
    final visibleAppointments = activeAppointments.isEmpty
        ? appointments.take(3).toList()
        : activeAppointments;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12),
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
          const SizedBox(height: 12),
          if (visibleAppointments.isEmpty)
            const Text(
              'No patients assigned.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            )
          else
            for (final appointment in visibleAppointments)
              _AdminPatientAppointmentRow(
                patientName: _patientName(appointment),
                subtitle: _appointmentSubtitle(appointment),
                status: _statusLabel(appointment.status),
                statusColor: _statusColor(appointment.status, primary),
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
    required this.status,
    required this.statusColor,
  });

  final String patientName;
  final String subtitle;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          _AdminStatusBadge(label: status, color: statusColor),
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
