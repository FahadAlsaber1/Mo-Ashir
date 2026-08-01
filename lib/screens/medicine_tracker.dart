import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/backend_api.dart';

class MedicineTrackerScreen extends StatefulWidget {
  const MedicineTrackerScreen({super.key});

  @override
  State<MedicineTrackerScreen> createState() => _MedicineTrackerScreenState();
}

class _MedicineTrackerScreenState extends State<MedicineTrackerScreen> {
  late Future<List<BackendMedication>> _medicationsFuture;

  @override
  void initState() {
    super.initState();
    _medicationsFuture = _loadMedications();
  }

  Future<List<BackendMedication>> _loadMedications() {
    final patientId = AppSession.patientId;
    if (patientId == null) return Future.value(const []);
    return BackendApi.listMedications(patientId: patientId);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text(
          'Medicine Tracker',
          style: TextStyle(
            color: primary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Track today\'s medicine and refill reminders.',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 22),
        FutureBuilder<List<BackendMedication>>(
          future: _medicationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _EmptyState(
                title: 'Could not load medications.',
                actionLabel: 'Retry',
                onTap: () => setState(
                  () => _medicationsFuture = _loadMedications(),
                ),
              );
            }
            final medications = snapshot.data ?? const <BackendMedication>[];
            if (medications.isEmpty) {
              return const _EmptyState(
                title: 'No medications added yet.',
                actionLabel: null,
                onTap: null,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Today',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('${medications.length} active medications',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(value: 0, minHeight: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text('Schedule',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                for (final medication in medications)
                  _MedicineDose(
                    name: medication.name,
                    dose: medication.dose.isEmpty
                        ? 'Dose not recorded'
                        : medication.dose,
                    time: medication.schedule.isEmpty
                        ? 'No schedule'
                        : medication.schedule,
                    deliveryStatus: medication.deliveryStatusLabel,
                    icon: Icons.medication_outlined,
                    color: primary,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.medication_outlined, color: primary, size: 42),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          if (actionLabel != null && onTap != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onTap, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _MedicineDose extends StatelessWidget {
  const _MedicineDose({
    required this.name,
    required this.dose,
    required this.time,
    required this.deliveryStatus,
    required this.icon,
    required this.color,
  });

  final String name;
  final String dose;
  final String time;
  final String deliveryStatus;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('$dose • $time',
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _DeliveryStatusBadge(label: deliveryStatus, color: color),
        ],
      ),
    );
  }
}

class _DeliveryStatusBadge extends StatelessWidget {
  const _DeliveryStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 138),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
