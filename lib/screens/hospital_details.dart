import 'package:flutter/material.dart';
import '../data/mock.dart';
import 'quick_questions.dart';

class HospitalDetailsScreen extends StatelessWidget {
  const HospitalDetailsScreen({super.key, required this.hospital});
  final Hospital hospital;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Hospital'), backgroundColor: Colors.transparent),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Hero(
                  tag: 'hospital-${hospital.id}',
                  child: Container(
                      height: 210,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [primary.withOpacity(.22), Colors.white]),
                          borderRadius: BorderRadius.circular(28)),
                      child: Icon(Icons.local_hospital_outlined,
                          size: 88, color: primary))),
              const SizedBox(height: 18),
              Text(hospital.name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _info(Icons.location_on_outlined,
                  '${hospital.location} · ${hospital.distance}'),
              const SizedBox(height: 8),
              _info(Icons.star_rounded, '${hospital.rating} rating',
                  iconColor: Colors.amber),
              const SizedBox(height: 8),
              _info(Icons.phone_outlined, hospital.phone),
              const SizedBox(height: 26),
              const Text('Doctors at this hospital',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...doctors.take(3).map((doctor) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  QuickQuestionsScreen(doctor: doctor))),
                      child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Row(children: [
                            CircleAvatar(
                                radius: 31,
                                backgroundColor: primary.withOpacity(.12),
                                child: Icon(Icons.person_outline,
                                    color: primary, size: 34)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(doctor.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  Text(doctor.specialty,
                                      style: TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  const SizedBox(height: 4),
                                  const Text('Sun–Thu · 09:00 AM–05:00 PM',
                                      style: TextStyle(
                                          color: Colors.black54, fontSize: 11))
                                ])),
                            const Icon(Icons.chevron_right_rounded,
                                color: Colors.black38),
                          ]))))),
            ]));
  }

  Widget _info(IconData icon, String text, {Color? iconColor}) =>
      Row(children: [
        Icon(icon, size: 19, color: iconColor ?? const Color(0xFF0B6B39)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black54)))
      ]);
}
