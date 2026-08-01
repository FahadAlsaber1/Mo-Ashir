import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/backend_api.dart';

class DashboardWall extends StatefulWidget {
  const DashboardWall({super.key});

  @override
  State<DashboardWall> createState() => _DashboardWallState();
}

class _DashboardWallState extends State<DashboardWall> {
  late Future<_WallData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WallData> _load() async {
    final doctors = await BackendApi.listDoctors();
    final patients = await BackendApi.listPatients();
    final patient = _preferredPatient(patients);
    final doctor = doctors.isEmpty ? null : doctors.first;
    final patientAppointments = patient == null
        ? const <BackendAppointment>[]
        : await BackendApi.listPatientAppointments(patientId: patient.id);
    final doctorAppointments = doctor == null
        ? const <BackendAppointment>[]
        : await BackendApi.listDoctorAppointments(doctorId: doctor.id);
    final medications = patient == null
        ? const <BackendMedication>[]
        : await BackendApi.listMedications(patientId: patient.id);
    return _WallData(
      doctors: doctors,
      patients: patients,
      patient: patient,
      doctor: doctor,
      patientAppointments: patientAppointments,
      doctorAppointments: doctorAppointments,
      medications: medications,
    );
  }

  BackendPatient? _preferredPatient(List<BackendPatient> patients) {
    for (final patient in patients) {
      if (patient.email.toLowerCase() == 'fahad1@hotmail.com') {
        return patient;
      }
    }
    return patients.isEmpty ? null : patients.first;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE9ECEF),
      child: SafeArea(
        child: FutureBuilder<_WallData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: FilledButton.icon(
                  onPressed: () => setState(() => _future = _load()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry dashboards'),
                ),
              );
            }
            final data = snapshot.data ?? const _WallData();
            return Stack(
              children: [
                Positioned(
                  top: 14,
                  right: 22,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: () => setState(() => _future = _load()),
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: () {
                          AppSession.clear();
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PhonePanel(
                          title: 'Doctor Dashboard',
                          child: _DoctorPreview(data: data),
                        ),
                        const SizedBox(width: 34),
                        _PhonePanel(
                          title: 'Patient Dashboard',
                          child: _PatientPreview(data: data),
                        ),
                        const SizedBox(width: 34),
                        _PhonePanel(
                          title: 'Admin Dashboard',
                          child: _AdminPreview(data: data),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PhonePanel extends StatelessWidget {
  const _PhonePanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 410,
      height: 850,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(54),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .24),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: ColoredBox(
              color: const Color(0xFFEFFFF5),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 76,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorPreview extends StatelessWidget {
  const _DoctorPreview({required this.data});

  final _WallData data;

  @override
  Widget build(BuildContext context) {
    final appointments = data.doctorAppointments;
    final upcoming =
        appointments.where((item) => item.status != 'completed').toList();
    return _PanelList(
      children: [
        _HeaderBlock(
          title: data.doctor?.fullName ?? 'Doctor',
          subtitle: data.doctor?.specialty ?? 'No doctor selected',
        ),
        Row(
          children: [
            Expanded(
              child: _MetricBlock(
                icon: Icons.groups_outlined,
                value: '${upcoming.length}',
                label: 'Upcoming',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricBlock(
                icon: Icons.history_outlined,
                value: '${appointments.length - upcoming.length}',
                label: 'Previous',
              ),
            ),
          ],
        ),
        const _SectionLabel('Patients'),
        if (appointments.isEmpty)
          const _SoftCard(title: 'No patients yet', subtitle: 'Queue is empty')
        else
          for (final appointment in appointments.take(5))
            _SoftCard(
              title: _patientName(appointment),
              subtitle: '${appointment.reason} - ${appointment.displayDate}',
              trailing:
                  appointment.status == 'completed' ? 'Previous' : 'Upcoming',
            ),
      ],
    );
  }
}

class _PatientPreview extends StatelessWidget {
  const _PatientPreview({required this.data});

  final _WallData data;

  @override
  Widget build(BuildContext context) {
    final appointment = data.patientAppointments.isEmpty
        ? null
        : data.patientAppointments.first;
    return _PanelList(
      children: [
        _HeaderBlock(
          title: data.patient?.fullName ?? 'Patient',
          subtitle: data.patient?.email ?? 'No patient selected',
        ),
        if (appointment == null)
          const _SoftCard(
            title: 'No upcoming appointment',
            subtitle: 'Book an appointment to begin',
          )
        else
          _SoftCard(
            title: appointment.reason,
            subtitle: '${appointment.displayDate} - ${appointment.timeLabel}',
            trailing: appointment.status,
          ),
        const _SectionLabel('Quick Actions'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: const [
            _ActionBlock(icon: Icons.calendar_month_outlined, label: 'Book'),
            _ActionBlock(icon: Icons.medication_outlined, label: 'Medicine'),
            _ActionBlock(icon: Icons.chat_bubble_outline, label: 'Chat'),
            _ActionBlock(icon: Icons.assignment_outlined, label: 'History'),
          ],
        ),
        const _SectionLabel('Medications'),
        if (data.medications.isEmpty)
          const _SoftCard(
              title: 'No medication', subtitle: 'No active delivery')
        else
          for (final medication in data.medications.take(3))
            _SoftCard(
              title: medication.name,
              subtitle: medication.deliveryStatusLabel,
              trailing: medication.statusLabel,
            ),
      ],
    );
  }
}

class _AdminPreview extends StatelessWidget {
  const _AdminPreview({required this.data});

  final _WallData data;

  @override
  Widget build(BuildContext context) {
    return _PanelList(
      children: [
        const _HeaderBlock(
          title: 'Hospitel',
          subtitle: 'Monitor doctors and patients',
        ),
        Row(
          children: [
            Expanded(
              child: _MetricBlock(
                icon: Icons.medical_services_outlined,
                value: '${data.doctors.length}',
                label: 'Doctors',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricBlock(
                icon: Icons.groups_outlined,
                value: '${data.patients.length}',
                label: 'Patients',
              ),
            ),
          ],
        ),
        const _SectionLabel('Doctors'),
        for (final doctor in data.doctors.take(4))
          _SoftCard(
            title: doctor.fullName,
            subtitle: '${doctor.specialty} - ${doctor.clinicName}',
          ),
        const _SectionLabel('Patients'),
        for (final patient in data.patients.take(4))
          _SoftCard(
            title: patient.fullName,
            subtitle: patient.email.isEmpty ? 'No email' : patient.email,
          ),
      ],
    );
  }
}

class _PanelList extends StatelessWidget {
  const _PanelList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        for (final child in children) ...[
          child,
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: TextStyle(
                color: primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionBlock extends StatelessWidget {
  const _ActionBlock({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: primary),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _WallData {
  const _WallData({
    this.doctors = const [],
    this.patients = const [],
    this.patient,
    this.doctor,
    this.patientAppointments = const [],
    this.doctorAppointments = const [],
    this.medications = const [],
  });

  final List<BackendDoctor> doctors;
  final List<BackendPatient> patients;
  final BackendPatient? patient;
  final BackendDoctor? doctor;
  final List<BackendAppointment> patientAppointments;
  final List<BackendAppointment> doctorAppointments;
  final List<BackendMedication> medications;
}

String _patientName(BackendAppointment appointment) {
  final patient = appointment.patient;
  final name = patient == null ? null : patient['full_name'];
  return name is String && name.trim().isNotEmpty ? name.trim() : 'Patient';
}
