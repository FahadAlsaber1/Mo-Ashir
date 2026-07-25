import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/mock.dart';
import '../services/app_session.dart';
import '../services/backend_api.dart';
import 'appointment_booking.dart';
import 'doctors.dart';
import 'family_doctor.dart';
import 'medicine_tracker.dart';
import 'profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<BackendAppointment?> _appointmentFuture;

  @override
  void initState() {
    super.initState();
    _appointmentFuture = _loadAppointment();
  }

  Future<BackendAppointment?> _loadAppointment() async {
    if (AppSession.latestAppointment != null) {
      return AppSession.latestAppointment;
    }
    final patientId = AppSession.patientId;
    if (patientId == null) return null;
    final appointment =
        await BackendApi.getUpcomingAppointment(patientId: patientId);
    if (appointment != null) {
      AppSession.setLatestAppointment(appointment);
    }
    return appointment;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final firstName = AppSession.firstName;
    final initials = AppSession.initials;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Good Morning,',
                      style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(firstName,
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: primary)),
                  const SizedBox(height: 4),
                  const Text('Take care of your health',
                      style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            Material(
              color: primary.withValues(alpha: 0.12),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _HomeRoutePage(
                      title: 'Profile',
                      child: ProfileScreen(),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FutureBuilder<BackendAppointment?>(
          future: _appointmentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _AppointmentLoadingCard();
            }
            if (snapshot.hasError) {
              return _NoAppointmentCard(
                message: 'Could not load appointment.',
                actionLabel: 'Retry',
                onTap: () {
                  setState(() => _appointmentFuture = _loadAppointment());
                },
              );
            }
            final appointment = snapshot.data;
            if (appointment == null) {
              return _NoAppointmentCard(
                message: 'No upcoming appointment yet.',
                actionLabel: 'Book Appointment',
                onTap: _openBooking,
              );
            }
            return _UpcomingAppointmentCard(
              appointment: appointment,
              primary: primary,
            );
          },
        ),
        const SizedBox(height: 24),
        const Text('Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 18,
          crossAxisSpacing: 10,
          childAspectRatio: .95,
          children: [
            _quick(context, Icons.calendar_month_outlined, 'Book Appointment',
                primary, const AppointmentBookingScreen()),
            _quick(context, Icons.health_and_safety_outlined, 'Family Doctor',
                primary, const FamilyDoctorScreen()),
            _quick(
              context,
              Icons.medical_services_outlined,
              'Doctors',
              primary,
              const _HomeRoutePage(title: 'Doctors', child: DoctorsScreen()),
            ),
            _quick(
                context,
                Icons.video_call_outlined,
                'Book Online Appointment',
                primary,
                const AppointmentBookingScreen()),
            _quick(
                context,
                Icons.medication_outlined,
                'My Medications',
                primary,
                Scaffold(
                  appBar: AppBar(title: const Text('My Medications')),
                  body: const SafeArea(child: MedicineTrackerScreen()),
                )),
            _quick(context, Icons.assignment_outlined, 'Medical History',
                primary, const MedicalHistoryScreen()),
          ],
        ),
      ],
    );
  }

  void _openBooking() {
    Navigator.of(context)
        .push(
            MaterialPageRoute(builder: (_) => const AppointmentBookingScreen()))
        .then((_) {
      if (mounted) {
        setState(() => _appointmentFuture = _loadAppointment());
      }
    });
  }

  Widget _quick(BuildContext context, IconData icon, String label,
          Color primary, Widget destination) =>
      Column(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => destination),
              ),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black12),
                ),
                child: Icon(icon, color: primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      );
}

class _HomeRoutePage extends StatelessWidget {
  const _HomeRoutePage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}

class _UpcomingAppointmentCard extends StatelessWidget {
  const _UpcomingAppointmentCard({
    required this.appointment,
    required this.primary,
  });

  final BackendAppointment appointment;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final location = _AppointmentHospitalLocation.fromAppointment(appointment);
    final date =
        appointment.displayDate.isEmpty ? 'Scheduled' : appointment.displayDate;
    final time =
        appointment.timeLabel.isEmpty ? '' : '  -  ${appointment.timeLabel}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: primary, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.white70),
            SizedBox(width: 6),
            Text('Upcoming Appointment',
                style: TextStyle(color: Colors.white70))
          ]),
          const SizedBox(height: 12),
          Text(appointment.doctorName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(appointment.doctorSpecialty,
              style: const TextStyle(color: Colors.white70)),
          if (location != null) ...[
            const SizedBox(height: 14),
            _AppointmentLocationCard(location: location),
          ],
          const SizedBox(height: 12),
          Text('$date$time', style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _AppointmentLocationCard extends StatelessWidget {
  const _AppointmentLocationCard({required this.location});

  final _AppointmentHospitalLocation location;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () async {
          final opened = await location.openInGoogleMaps();
          if (opened || !context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open maps.')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hospital location',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(location.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(location.addressLine,
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentHospitalLocation {
  const _AppointmentHospitalLocation({
    required this.name,
    required this.address,
    required this.distance,
  });

  final String name;
  final String address;
  final String distance;

  String get addressLine {
    if (distance.isEmpty) return address;
    if (address.isEmpty) return distance;
    return '$address - $distance';
  }

  Future<bool> openInGoogleMaps() async {
    final query =
        [name, address].where((part) => part.trim().isNotEmpty).join(', ');
    final uri = Uri.https(
        'www.google.com', '/maps/search/', {'api': '1', 'query': query});
    try {
      return launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }

  static _AppointmentHospitalLocation? fromAppointment(
      BackendAppointment appointment) {
    final clinicName = appointment.doctorClinicName.trim().isNotEmpty
        ? appointment.doctorClinicName.trim()
        : doctorByName(appointment.doctorName)?.clinic;
    if (clinicName == null || clinicName.isEmpty) return null;

    final hospital = hospitalForClinic(clinicName);
    if (hospital == null) {
      return _AppointmentHospitalLocation(
        name: clinicName,
        address: 'Riyadh',
        distance: '',
      );
    }
    return _AppointmentHospitalLocation(
      name: hospital.name,
      address: hospital.location,
      distance: hospital.distance,
    );
  }
}

class _AppointmentLoadingCard extends StatelessWidget {
  const _AppointmentLoadingCard();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 152,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: CircularProgressIndicator(color: primary),
    );
  }
}

class _NoAppointmentCard extends StatelessWidget {
  const _NoAppointmentCard({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: primary),
            const SizedBox(width: 8),
            const Text('Upcoming Appointment',
                style: TextStyle(fontWeight: FontWeight.w900))
          ]),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
