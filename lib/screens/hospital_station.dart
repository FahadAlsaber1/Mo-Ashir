import 'package:flutter/material.dart';

import '../services/backend_api.dart';
import '../services/thermal_camera.dart';

class HospitalStationScreen extends StatefulWidget {
  const HospitalStationScreen({super.key});

  @override
  State<HospitalStationScreen> createState() => _HospitalStationScreenState();
}

class _HospitalStationScreenState extends State<HospitalStationScreen> {
  late Future<List<BackendAppointment>> _appointmentsFuture;
  BackendAppointment? _selectedAppointment;
  ThermalCameraResult? _thermalResult;
  String? _message;
  String? _appointmentLoadError;
  bool _runningThermal = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _appointmentsFuture = _loadAppointments();
  }

  Future<List<BackendAppointment>> _loadAppointments() async {
    try {
      final appointment = await BackendApi.getLatestAppointment();
      if (appointment == null) return const [];
      if (mounted) {
        _appointmentLoadError = null;
        _selectedAppointment ??= appointment;
      }
      return [appointment];
    } on BackendApiException catch (error) {
      if (mounted) {
        _appointmentLoadError = error.message;
      }
      return const [];
    }
  }

  Future<void> _runThermalCamera() async {
    final appointment = _selectedAppointment;
    if (appointment == null) {
      setState(() => _message = 'Select an appointment first.');
      return;
    }

    setState(() {
      _runningThermal = true;
      _message = 'Reading thermal camera...';
    });

    final patientName =
        (appointment.patient?['full_name'] as String?)?.trim() ?? 'Patient';
    final thermal = await ThermalCamera.captureVerifiedTemperature(
      patientId: appointment.patientId,
      patientName: patientName,
    );

    if (!mounted) return;
    setState(() {
      _runningThermal = false;
      _thermalResult = thermal;
      _message = thermal == null
          ? 'Thermal camera did not return a verified temperature.'
          : 'Thermal temperature captured. Sending to doctor dashboard...';
    });
    if (thermal != null) {
      await _saveTemperature(thermal);
    }
  }

  Future<void> _saveTemperature(ThermalCameraResult thermal) async {
    setState(() {
      _saving = true;
      _message = 'Saving station temperature...';
    });

    try {
      await BackendApi.createLatestAppointmentTemperature(
        temperatureC: thermal.temperatureC,
        capturedAt: thermal.capturedAt,
        confirmation: 'Thermal camera station capture',
      );
      if (!mounted) return;
      setState(() => _message = 'Temperature saved to doctor dashboard.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Could not save temperature: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Hospital Station')),
      backgroundColor: const Color(0xFFEFFFF5),
      body: FutureBuilder<List<BackendAppointment>>(
        future: _appointmentsFuture,
        builder: (context, snapshot) {
          final appointments = snapshot.data ?? const <BackendAppointment>[];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Thermal camera',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Capture the patient temperature from the thermal camera.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (appointments.isEmpty)
                _StationCard(
                  child: Text(
                    _appointmentLoadError == null
                        ? 'No latest appointment found.'
                        : 'Could not load latest appointment: $_appointmentLoadError',
                  ),
                )
              else
                _StationCard(
                  child: DropdownButtonFormField<BackendAppointment>(
                    value: _selectedAppointment,
                    decoration: const InputDecoration(
                      labelText: 'Station appointment',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final appointment in appointments)
                        DropdownMenuItem(
                          value: appointment,
                          child: Text(
                            '${_patientName(appointment)} - ${appointment.reason}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (appointment) {
                      setState(() {
                        _selectedAppointment = appointment;
                        _thermalResult = null;
                      });
                    },
                  ),
                ),
              const SizedBox(height: 14),
              _StationCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _runningThermal ? null : _runThermalCamera,
                      icon: _runningThermal
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.thermostat_outlined),
                      label: const Text('Run thermal camera'),
                    ),
                    if (_thermalResult != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${_thermalResult!.temperatureC.round()} C',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: primary,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (_saving) ...[
                        const SizedBox(height: 12),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ],
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _patientName(BackendAppointment appointment) {
    return (appointment.patient?['full_name'] as String?)?.trim() ?? 'Patient';
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}
