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
    return _AdminDashboardData(
      doctors: results[0] as List<BackendDoctor>,
      patients: results[1] as List<BackendPatient>,
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

          final data = snapshot.data ??
              const _AdminDashboardData(doctors: [], patients: []);
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
              const _AdminSectionTitle('Doctors'),
              const SizedBox(height: 10),
              if (data.doctors.isEmpty)
                const _AdminPlainCard('No doctors registered.')
              else
                for (final doctor in data.doctors)
                  _AdminListTile(
                    icon: Icons.person_outline,
                    title: doctor.fullName,
                    subtitle: '${doctor.specialty} - ${doctor.clinicName}',
                  ),
              const SizedBox(height: 24),
              const _AdminSectionTitle('Patients'),
              const SizedBox(height: 10),
              if (data.patients.isEmpty)
                const _AdminPlainCard('No patients registered.')
              else
                for (final patient in data.patients)
                  _AdminListTile(
                    icon: Icons.badge_outlined,
                    title: patient.fullName,
                    subtitle: patient.email.isEmpty
                        ? 'No email recorded'
                        : patient.email,
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
  });

  final List<BackendDoctor> doctors;
  final List<BackendPatient> patients;
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
