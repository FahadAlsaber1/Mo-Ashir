import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../services/backend_api.dart';
import 'appointment_booking.dart';
import 'chat.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  String _query = '';
  late Future<List<Doctor>> _doctorsFuture;

  @override
  void initState() {
    super.initState();
    _doctorsFuture = _loadDoctors();
  }

  Future<List<Doctor>> _loadDoctors() async {
    final backendDoctors = await BackendApi.listDoctors();
    if (backendDoctors.isEmpty) return doctors;
    return backendDoctors.map(_doctorFromBackend).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Doctors',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search doctors',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Doctor>>(
          future: _doctorsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final source = snapshot.data ?? doctors;
            final results = source
                .where((doctor) =>
                    _query.isEmpty ||
                    '${doctor.name} ${doctor.specialty} ${doctor.credential} ${doctor.clinic} ${doctor.city}'
                        .toLowerCase()
                        .contains(_query.toLowerCase()))
                .toList();
            if (results.isEmpty) return const _NoDoctorsFound();
            return Column(
              children: [
                ...results.map((d) => _DoctorListCard(
                      doctor: d,
                      primary: primary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DoctorDetailsScreen(doctor: d),
                        ),
                      ),
                    )),
              ],
            );
          },
        ),
      ],
    );
  }

  Doctor _doctorFromBackend(BackendDoctor doctor) {
    return Doctor(
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
    );
  }
}

class DoctorDetailsScreen extends StatelessWidget {
  const DoctorDetailsScreen({super.key, required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFFEFFFF5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withValues(alpha: .12),
                        border: Border.all(
                          color: const Color(0xFFCBEFD9),
                          width: 4,
                        ),
                      ),
                      child: Icon(Icons.person, size: 68, color: primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    doctor.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    doctor.specialty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF65756D),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _credentialText(doctor),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF65756D)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 5),
                      Text('${doctor.rating}',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      const Text('(128 reviews)',
                          style: TextStyle(color: Color(0xFF65756D))),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      const Expanded(
                        child: _InfoCard(
                          icon: Icons.access_time,
                          label: 'Working hours',
                          value: '09:00 AM - 05:00 PM',
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: _InfoCard(
                          icon: Icons.calendar_month_outlined,
                          label: 'Working days',
                          value: 'Sun - Mon - Tue - Wed - Thu',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.payments_outlined,
                          label: 'Consultation fee',
                          value: doctor.consultationFeeLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('About'),
                  const SizedBox(height: 10),
                  Text(
                    _aboutText(doctor),
                    style: const TextStyle(
                      color: Color(0xFF65756D),
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('Languages',
                      icon: Icons.language_outlined),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: doctor.languages
                        .split(', ')
                        .map((language) => _LanguageChip(language))
                        .toList(),
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('Certificates',
                      icon: Icons.workspace_premium_outlined),
                  const SizedBox(height: 10),
                  ..._certificates(doctor).map((certificate) =>
                      _CertificateTile(certificate: certificate)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              body: SafeArea(
                                child: ChatScreen(initialDoctor: doctor),
                              ),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Chat'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AppointmentBookingScreen(initialDoctor: doctor),
                          ),
                        ),
                        child: const Text('Book Appointment'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _credentialText(Doctor doctor) => switch (doctor.id) {
        'ahmed' => 'MBBS, MD - Internal Medicine',
        'sara' => 'MBBS, DM - Cardiology',
        'yusuf' => 'MBBS, MD - Dermatology',
        'layla' => 'MBBS, MD - Pediatrics',
        _ => doctor.credential,
      };

  String _aboutText(Doctor doctor) => switch (doctor.id) {
        'sara' =>
          'Cardiologist focused on preventive heart care, hypertension management, and follow-up for chronic cardiac conditions.',
        'yusuf' =>
          'Dermatologist experienced in skin conditions, acne treatment, rash evaluation, and long-term skin health.',
        'layla' =>
          'Pediatrician focused on child wellness, growth monitoring, vaccinations, and family-centered care.',
        _ =>
          'General physician with a focus on preventive care, chronic disease management, and family medicine.',
      };

  List<String> _certificates(Doctor doctor) => switch (doctor.id) {
        'sara' => const [
            'MBBS, DM - Cardiology',
            'Board Certified - Cardiology (SCFHS)',
            'Advanced Cardiac Life Support (ACLS)',
          ],
        'yusuf' => const [
            'MBBS, MD - Dermatology',
            'Board Certified - Dermatology (SCFHS)',
            'Clinical Dermatology Fellowship',
          ],
        'layla' => const [
            'MBBS, MD - Pediatrics',
            'Board Certified - Pediatrics (SCFHS)',
            'Pediatric Advanced Life Support (PALS)',
          ],
        _ => const [
            'MBBS, MD - Internal Medicine',
            'Board Certified - Family Medicine (SCFHS)',
            'Advanced Life Support (ACLS)',
          ],
      };
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primary, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: primary, size: 20),
          const SizedBox(width: 7),
        ],
        Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFD4F5DE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFF007F3D), fontWeight: FontWeight.w700)),
    );
  }
}

class _CertificateTile extends StatelessWidget {
  const _CertificateTile({required this.certificate});

  final String certificate;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined, color: primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(certificate,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _DoctorListCard extends StatelessWidget {
  const _DoctorListCard({
    required this.doctor,
    required this.primary,
    required this.onTap,
  });

  final Doctor doctor;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: primary.withValues(alpha: 0.15),
                  child: Icon(Icons.person, color: primary, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        doctor.specialty,
                        style: TextStyle(
                          color: primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        doctor.credential,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text('${doctor.rating}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        Text('${doctor.years} yrs exp',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.payments_outlined, size: 14, color: primary),
                        const SizedBox(width: 3),
                        Text(doctor.consultationFeeLabel,
                            style: TextStyle(
                                color: primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w900)),
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoDoctorsFound extends StatelessWidget {
  const _NoDoctorsFound();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_outlined, color: primary, size: 38),
          const SizedBox(height: 8),
          const Text('No doctors found',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Try another name, specialty, clinic, or city.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
