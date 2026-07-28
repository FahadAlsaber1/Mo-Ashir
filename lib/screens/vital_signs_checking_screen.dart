import 'package:flutter/material.dart';

import '../data/mock.dart';
import '../data/vital_signs_data.dart';
import '../height_weight_scanner/height_weight_scanner_page.dart';
import 'remote_vitals_measurement_screen.dart';

class VitalSignsCheckingScreen extends StatefulWidget {
  const VitalSignsCheckingScreen({
    super.key,
    required this.doctor,
    required this.appointment,
  });

  final Doctor doctor;
  final String appointment;

  @override
  State<VitalSignsCheckingScreen> createState() =>
      _VitalSignsCheckingScreenState();
}

class _VitalSignsCheckingScreenState extends State<VitalSignsCheckingScreen> {
  int _pageIndex = 0;
  ScanResult? _bodyResult;
  RemoteVitalResult? _vitalsResult;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isBodyPage = _pageIndex == 0;
    final canContinue =
        isBodyPage ? _bodyResult != null : _vitalsResult != null;

    return PopScope(
      canPop: _pageIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _pageIndex > 0) {
          setState(() => _pageIndex = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isBodyPage ? 'Height & Weight' : 'Vital Signs'),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _ProgressHeader(pageIndex: _pageIndex),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: isBodyPage ? _bodyMeasurementPage() : _vitalsPage(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: canContinue
                        ? isBodyPage
                            ? () => setState(() => _pageIndex = 1)
                            : _confirm
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      isBodyPage ? 'Continue to Vital Signs' : 'Confirm',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bodyMeasurementPage() {
    final result = _bodyResult;
    return ListView(
      key: const ValueKey('body'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        const _Heading(
          title: 'First, get height and weight',
          subtitle:
              'Use the camera body scan to estimate height and weight before the vital-sign scan.',
        ),
        const _PrototypeNotice(
          text:
              'Height and weight are visual estimates. Use a scale and stadiometer for clinical accuracy.',
        ),
        const SizedBox(height: 18),
        _MeasurementCard(
          icon: Icons.height_rounded,
          title: 'Height & Weight',
          value: result == null
              ? 'Ready to scan'
              : '${result.heightCm.toStringAsFixed(1)} cm\n${result.weightKg.toStringAsFixed(1)} kg',
          completed: result != null,
          onTap: _openHeightWeightScanner,
        ),
        if (result != null) ...[
          const SizedBox(height: 14),
          _SummaryPanel(
            rows: [
              ('Height', '${result.heightCm.toStringAsFixed(1)} cm'),
              ('Weight', '${result.weightKg.toStringAsFixed(1)} kg'),
              ('Confidence', result.confidence),
            ],
          ),
        ],
      ],
    );
  }

  Widget _vitalsPage() {
    final result = _vitalsResult;
    return ListView(
      key: const ValueKey('vitals'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        const _Heading(
          title: 'Now scan vital signs',
          subtitle:
              'A 30-second face scan estimates heart beat, breathing rate, blood pressure, and oxygen level.',
        ),
        const _PrototypeNotice(
          text:
              'This is a prototype wellness scan, not a medical device or diagnosis.',
        ),
        const SizedBox(height: 18),
        _MeasurementCard(
          icon: Icons.face_retouching_natural_outlined,
          title: 'Face Vital Scan',
          value: result == null
              ? 'Ready to scan'
              : '${result.heartRateBpm} bpm\n${result.systolic}/${result.diastolic} mmHg',
          completed: result != null,
          onTap: _openRemoteVitals,
        ),
        if (result != null) ...[
          const SizedBox(height: 14),
          _VitalsGrid(result: result),
        ],
      ],
    );
  }

  Future<void> _openHeightWeightScanner() async {
    final result = await Navigator.of(context).push<ScanResult>(
      MaterialPageRoute(builder: (_) => const HeightWeightScannerPage()),
    );

    if (result == null || !mounted) return;
    setState(() => _bodyResult = result);
  }

  Future<void> _openRemoteVitals() async {
    final result = await Navigator.of(context).push<RemoteVitalResult>(
      MaterialPageRoute(builder: (_) => const RemoteVitalsMeasurementScreen()),
    );

    if (result == null || !mounted) return;
    setState(() => _vitalsResult = result);
  }

  void _back() {
    if (_pageIndex == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _pageIndex = 0);
    }
  }

  void _confirm() {
    final body = _bodyResult!;
    final vitals = _vitalsResult!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: Color(0xFF0B6B39),
          size: 54,
        ),
        title: const Text('Appointment confirmed'),
        content: Text(
          '${widget.doctor.name}\n'
          '${widget.appointment}\n'
          'Consultation fee: ${widget.doctor.consultationFeeLabel}\n'
          'Payment: Pay at clinic\n'
          'Height: ${body.heightCm.toStringAsFixed(1)} cm\n'
          'Weight: ${body.weightKg.toStringAsFixed(1)} kg\n'
          'Heart: ${vitals.heartRateBpm} bpm\n'
          'Breathing: ${vitals.breathingRateRpm} rpm\n'
          'BP: ${vitals.systolic}/${vitals.diastolic} mmHg\n'
          'Oxygen: ${vitals.oxygenPercent}%',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.pageIndex});

  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Page ${pageIndex + 1} of 2',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const Spacer(),
              Text(
                pageIndex == 0 ? 'Body measurements' : 'Vitals',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: (pageIndex + 1) / 2,
            minHeight: 6,
            color: primary,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0A3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF9B6500), size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6E4A00),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.completed,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: completed ? primary : const Color(0xFFE0ECE5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .045),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: TextStyle(
                        color: completed ? primary : Colors.black54,
                        fontWeight:
                            completed ? FontWeight.w900 : FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                completed ? Icons.check_circle : Icons.chevron_right_rounded,
                color: completed ? primary : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Text(
                      row.$1,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({required this.result});

  final RemoteVitalResult result;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: .96,
      children: [
        _VitalMetric(
          icon: Icons.favorite,
          title: 'Heart',
          value: '${result.heartRateBpm}',
          unit: 'bpm',
        ),
        _VitalMetric(
          icon: Icons.air_rounded,
          title: 'Breathing',
          value: '${result.breathingRateRpm}',
          unit: 'rpm',
        ),
        _VitalMetric(
          icon: Icons.health_and_safety_outlined,
          title: 'Blood Pressure',
          value: '${result.systolic}/${result.diastolic}',
          unit: 'mmHg',
        ),
        _VitalMetric(
          icon: Icons.water_drop_outlined,
          title: 'Oxygen',
          value: '${result.oxygenPercent}',
          unit: '%',
        ),
        if (result.hasVerifiedTemperature)
          _VitalMetric(
            icon: Icons.thermostat_outlined,
            title: 'Temperature',
            value: result.temperatureC!.toStringAsFixed(1),
            unit: 'C',
          ),
      ],
    );
  }
}

class _VitalMetric extends StatelessWidget {
  const _VitalMetric({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String title;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0ECE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary, size: 28),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w900,
                fontSize: 30,
              ),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
