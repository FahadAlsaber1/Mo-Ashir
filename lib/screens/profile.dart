import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/backend_api.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final fullName = AppSession.fullName;
    final email = AppSession.email;
    final initials = AppSession.initials;
    const items = [
      _ProfileItem(
          Icons.person, 'Personal Information', PersonalInformationScreen()),
      _ProfileItem(Icons.location_on, 'Address', AddressScreen()),
      _ProfileItem(Icons.water_drop, 'Blood Type', BloodTypeScreen()),
      _ProfileItem(
          Icons.description, 'Medical History', MedicalHistoryScreen()),
      _ProfileItem(Icons.calendar_today, 'Appointments', AppointmentsScreen()),
      _ProfileItem(Icons.local_pharmacy, 'Pharmacy', PharmacyScreen()),
      _ProfileItem(Icons.settings, 'Settings', SettingsScreen()),
      _ProfileItem(Icons.help, 'Help', HelpScreen()),
      _ProfileItem(Icons.logout, 'Log out', LogOutScreen()),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
            child: Column(children: [
          CircleAvatar(
              radius: 44,
              backgroundColor: primary.withValues(alpha: 0.15),
              child: Text(initials,
                  style: TextStyle(
                      color: primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          Text(fullName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(email, style: TextStyle(color: Colors.black54)),
        ])),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              for (final it in items)
                ListTile(
                  leading: Icon(it.icon, color: primary),
                  title: Text(it.label),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.black38),
                  onTap: it.destination == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => it.destination!,
                            ),
                          ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileItem {
  const _ProfileItem(this.icon, this.label, [this.destination]);

  final IconData icon;
  final String label;
  final Widget? destination;
}

class PersonalInformationScreen extends StatelessWidget {
  const PersonalInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ProfileDetailPage(
      title: 'Personal Information',
      children: [
        _DetailTile(label: 'Full Name', value: _value(AppSession.fullName)),
        _DetailTile(label: 'Email', value: _value(AppSession.email)),
        _DetailTile(label: 'Mobile', value: _value(AppSession.mobile)),
        _DetailTile(label: 'National ID', value: _value(AppSession.nationalId)),
        _DetailTile(
            label: 'Date of Birth', value: _value(AppSession.dateOfBirth)),
        _DetailTile(label: 'Gender', value: _value(AppSession.gender)),
      ],
    );
  }
}

class AddressScreen extends StatelessWidget {
  const AddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfileDetailPage(
      title: 'Address',
      children: [
        _DetailTile(label: 'City', value: 'Riyadh'),
        _DetailTile(label: 'District', value: 'Al Olaya'),
        _DetailTile(label: 'Street', value: 'King Fahd Road'),
        _DetailTile(label: 'Building Number', value: '2457'),
        _DetailTile(label: 'Postal Code', value: '12214'),
        _DetailTile(label: 'Country', value: 'Saudi Arabia'),
      ],
    );
  }
}

class BloodTypeScreen extends StatelessWidget {
  const BloodTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ProfileDetailPage(
      title: 'Blood Type',
      children: [
        _DetailTile(label: 'Blood Type', value: _value(AppSession.bloodType)),
      ],
    );
  }
}

class MedicalHistoryScreen extends StatelessWidget {
  const MedicalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patientId = AppSession.patientId;
    if (patientId == null) {
      return const _ProfileDetailPage(
        title: 'Medical History',
        children: [_DetailTile(label: 'Status', value: 'No patient profile')],
      );
    }

    return _ProfileFuturePage<List<BackendMedication>>(
      title: 'Medical History',
      future: BackendApi.listMedications(patientId: patientId),
      builder: (medications) => [
        _DetailTile(label: 'Allergies', value: 'Not recorded'),
        _DetailTile(label: 'Chronic Conditions', value: 'Not recorded'),
        _DetailTile(label: 'Past Surgeries', value: 'Not recorded'),
        _DetailTile(
          label: 'Current Medications',
          value: medications.isEmpty
              ? 'No medications recorded'
              : medications.map((item) => item.name).join(', '),
        ),
      ],
    );
  }
}

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patientId = AppSession.patientId;
    if (patientId == null) {
      return const _ProfileDetailPage(
        title: 'Appointments',
        children: [_DetailTile(label: 'Status', value: 'No patient profile')],
      );
    }

    return _ProfileFuturePage<List<BackendAppointment>>(
      title: 'Appointments',
      future: BackendApi.listPatientAppointments(patientId: patientId),
      builder: (appointments) {
        if (appointments.isEmpty) {
          return const [
            _DetailTile(label: 'Upcoming', value: 'No appointments yet'),
          ];
        }
        return [
          for (final appointment in appointments)
            _DetailTile(
              label: appointment.doctorName,
              value:
                  '${appointment.displayDate} ${appointment.timeLabel} - ${appointment.status}',
            ),
        ];
      },
    );
  }
}

class PharmacyScreen extends StatelessWidget {
  const PharmacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patientId = AppSession.patientId;
    if (patientId == null) {
      return const _ProfileDetailPage(
        title: 'Pharmacy',
        children: [_DetailTile(label: 'Status', value: 'No patient profile')],
      );
    }

    return _ProfileFuturePage<List<BackendMedication>>(
      title: 'Pharmacy',
      future: BackendApi.listMedications(patientId: patientId),
      builder: (medications) {
        if (medications.isEmpty) {
          return const [
            _DetailTile(label: 'Active Prescriptions', value: 'None recorded'),
          ];
        }
        final activeCount = medications.where((item) => item.active).length;
        return [
          _DetailTile(label: 'Active Prescriptions', value: '$activeCount'),
          for (final medication in medications)
            _DetailTile(
              label: medication.name,
              value:
                  '${_value(medication.dose)} - ${_value(medication.schedule)} - ${medication.deliveryStatusLabel}',
            ),
        ];
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfileDetailPage(
      title: 'Settings',
      children: [
        _DetailTile(label: 'Notifications', value: 'Enabled'),
        _DetailTile(label: 'Medicine Reminders', value: 'Enabled'),
        _DetailTile(label: 'Language', value: 'English'),
        _DetailTile(label: 'Privacy', value: 'Profile visible to care team'),
        _DetailTile(label: 'Security', value: 'Password enabled'),
      ],
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfileDetailPage(
      title: 'Help',
      children: [
        _DetailTile(label: 'Support', value: 'support@moashir.example'),
        _DetailTile(label: 'Phone', value: '+966 9200 00000'),
        _DetailTile(label: 'FAQ', value: 'Appointments, medicine, payments'),
        _DetailTile(label: 'Emergency', value: 'Call local emergency services'),
        _DetailTile(label: 'App Version', value: '1.0.0'),
      ],
    );
  }
}

class LogOutScreen extends StatelessWidget {
  const LogOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Log out')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log out of MO\'ASHIR?',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text(
                    'You will return to the sign in screen. Your local demo data will remain available.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () {
                  AppSession.clear();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                },
                style: FilledButton.styleFrom(backgroundColor: primary),
                child: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailPage extends StatelessWidget {
  const _ProfileDetailPage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _ProfileFuturePage<T> extends StatelessWidget {
  const _ProfileFuturePage({
    required this.title,
    required this.future,
    required this.builder,
  });

  final String title;
  final Future<T> future;
  final List<Widget> Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<T>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load data.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: builder(snapshot.data as T)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(value),
    );
  }
}

String _value(String value) => value.trim().isEmpty ? 'Not recorded' : value;
