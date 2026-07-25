import 'package:flutter/material.dart';

import '../data/mock.dart';
import 'appointment_booking.dart';

class FamilyDoctorScreen extends StatelessWidget {
  const FamilyDoctorScreen(
      {super.key, this.doctor, this.hasAssignedDoctor = true});

  final Doctor? doctor;
  final bool hasAssignedDoctor;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final assigned = hasAssignedDoctor ? (doctor ?? doctors.first) : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Family Doctor')),
      body: assigned == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.medical_services_outlined,
                      size: 72, color: primary),
                  const SizedBox(height: 20),
                  const Text('You do not have a family doctor yet.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AppointmentBookingScreen()),
                    ),
                    child: const Text('Choose Family Doctor'),
                  ),
                ]),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 12)
                    ],
                  ),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: primary.withValues(alpha: .12),
                      child:
                          Icon(Icons.person_outline, size: 62, color: primary),
                    ),
                    const SizedBox(height: 16),
                    Text(assigned.name,
                        style: const TextStyle(
                            fontSize: 23, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(assigned.specialty,
                        style: TextStyle(
                            color: primary, fontWeight: FontWeight.w700)),
                    Text(assigned.clinic,
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 18),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _stat(Icons.star_rounded, '${assigned.rating}',
                              'Rating', Colors.amber),
                          _stat(Icons.workspace_premium_outlined,
                              '${assigned.years} yrs', 'Experience', primary),
                        ]),
                  ]),
                ),
                const SizedBox(height: 16),
                _info(Icons.language, 'Languages', assigned.languages, primary),
                _info(Icons.calendar_today_outlined, 'Next available',
                    assigned.nextAvailable, primary),
                _info(Icons.payments_outlined, 'Consultation fee',
                    assigned.consultationFeeLabel, primary),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Call'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'))),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AppointmentBookingScreen(
                              initialDoctor: assigned)),
                    ),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Book Appointment',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
    );
  }

  static Widget _stat(IconData icon, String value, String label, Color color) =>
      Column(children: [
        Icon(icon, color: color),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ]);

  static Widget _info(
          IconData icon, String label, String value, Color primary) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Icon(icon, color: primary),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ])),
        ]),
      );
}
