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
                MedicationDeliveryMapCard(medications: medications),
                if (_hasTrackableDelivery(medications))
                  const SizedBox(height: 22),
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

  bool _hasTrackableDelivery(List<BackendMedication> medications) {
    return medications.any(
      (item) => item.deliveryStatus == 'out_for_delivery',
    );
  }
}

class MedicationDeliveryMapCard extends StatelessWidget {
  const MedicationDeliveryMapCard({
    super.key,
    required this.medications,
  });

  final List<BackendMedication> medications;

  @override
  Widget build(BuildContext context) {
    final delivery = _trackableDelivery;
    if (delivery == null) return const SizedBox.shrink();

    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Medication delivery',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              _DeliveryStatusBadge(
                label: delivery.deliveryStatusLabel,
                color: primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            delivery.name,
            style: const TextStyle(color: Colors.black54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 210,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFFEAF4EE)),
                child: CustomPaint(
                  painter: _DeliveryMapPainter(primary: primary),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 18,
                        top: 16,
                        child: _MapLabel(
                          icon: Icons.local_pharmacy_outlined,
                          title: 'King Fahad Hospital',
                          subtitle: 'Courier picked up',
                          color: primary,
                        ),
                      ),
                      Positioned(
                        right: 18,
                        bottom: 16,
                        child: _MapLabel(
                          icon: Icons.home_outlined,
                          title: 'Patient address',
                          subtitle: 'Arriving soon',
                          color: primary,
                        ),
                      ),
                      Positioned(
                        left: 128,
                        top: 92,
                        child: _CourierMarker(color: primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DeliveryMetric(
                  label: 'ETA',
                  value: '12 min',
                  icon: Icons.schedule_outlined,
                  color: primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DeliveryMetric(
                  label: 'Distance',
                  value: '2.4 km',
                  icon: Icons.route_outlined,
                  color: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BackendMedication? get _trackableDelivery {
    for (final medication in medications) {
      if (medication.deliveryStatus == 'out_for_delivery') {
        return medication;
      }
    }
    return null;
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

class _MapLabel extends StatelessWidget {
  const _MapLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 168),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierMarker extends StatelessWidget {
  const _CourierMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .32),
            blurRadius: 18,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.delivery_dining, color: Colors.white),
    );
  }
}

class _DeliveryMetric extends StatelessWidget {
  const _DeliveryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliveryMapPainter extends CustomPainter {
  const _DeliveryMapPainter({required this.primary});

  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: .82)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final routePaint = Paint()
      ..color = primary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final thinRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: .58)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadA = Path()
      ..moveTo(-20, size.height * .28)
      ..cubicTo(
        size.width * .22,
        size.height * .18,
        size.width * .45,
        size.height * .56,
        size.width + 20,
        size.height * .38,
      );
    final roadB = Path()
      ..moveTo(size.width * .18, -12)
      ..cubicTo(
        size.width * .24,
        size.height * .35,
        size.width * .68,
        size.height * .48,
        size.width * .76,
        size.height + 12,
      );
    final roadC = Path()
      ..moveTo(-14, size.height * .78)
      ..lineTo(size.width * .48, size.height * .58)
      ..lineTo(size.width + 14, size.height * .72);
    canvas.drawPath(roadA, roadPaint);
    canvas.drawPath(roadB, thinRoadPaint);
    canvas.drawPath(roadC, thinRoadPaint);

    final route = Path()
      ..moveTo(size.width * .18, size.height * .27)
      ..cubicTo(
        size.width * .38,
        size.height * .26,
        size.width * .35,
        size.height * .58,
        size.width * .52,
        size.height * .57,
      )
      ..cubicTo(
        size.width * .68,
        size.height * .56,
        size.width * .67,
        size.height * .76,
        size.width * .82,
        size.height * .77,
      );
    canvas.drawPath(route, routePaint);

    canvas.drawCircle(
      Offset(size.width * .18, size.height * .27),
      8,
      Paint()..color = primary,
    );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .77),
      8,
      Paint()..color = const Color(0xFF232A25),
    );
  }

  @override
  bool shouldRepaint(covariant _DeliveryMapPainter oldDelegate) {
    return oldDelegate.primary != primary;
  }
}
