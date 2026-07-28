import 'package:flutter/material.dart';

enum VitalSignKey {
  heartRate,
  bloodPressure,
  oxygen,
  temperature,
  height,
  weight,
}

class VitalSignCardData {
  const VitalSignCardData({
    required this.key,
    required this.title,
    required this.icon,
    required this.isActive,
  });

  final VitalSignKey key;
  final String title;
  final IconData icon;
  final bool isActive;
}

class VitalSignResult {
  const VitalSignResult({
    required this.bpm,
    required this.measuredAt,
  });

  final int bpm;
  final DateTime measuredAt;
}

class RemoteVitalResult {
  const RemoteVitalResult({
    required this.heartRateBpm,
    required this.breathingRateRpm,
    required this.systolic,
    required this.diastolic,
    required this.oxygenPercent,
    required this.confidence,
    required this.measuredAt,
    this.temperatureC,
    this.thermalFaceRecognitionConfirmed = false,
  });

  final int heartRateBpm;
  final int breathingRateRpm;
  final int systolic;
  final int diastolic;
  final int oxygenPercent;
  final String confidence;
  final DateTime measuredAt;
  final double? temperatureC;
  final bool thermalFaceRecognitionConfirmed;

  bool get hasVerifiedTemperature =>
      thermalFaceRecognitionConfirmed && temperatureC != null;
}

const vitalSignCards = [
  VitalSignCardData(
    key: VitalSignKey.heartRate,
    title: 'Heart Rate',
    icon: Icons.monitor_heart_outlined,
    isActive: true,
  ),
  VitalSignCardData(
    key: VitalSignKey.bloodPressure,
    title: 'Blood Pressure',
    icon: Icons.health_and_safety_outlined,
    isActive: false,
  ),
  VitalSignCardData(
    key: VitalSignKey.oxygen,
    title: 'Oxygen',
    icon: Icons.air_rounded,
    isActive: false,
  ),
  VitalSignCardData(
    key: VitalSignKey.temperature,
    title: 'Temperature',
    icon: Icons.thermostat_outlined,
    isActive: false,
  ),
  VitalSignCardData(
    key: VitalSignKey.height,
    title: 'Height',
    icon: Icons.height_rounded,
    isActive: true,
  ),
  VitalSignCardData(
    key: VitalSignKey.weight,
    title: 'Weight',
    icon: Icons.monitor_weight_outlined,
    isActive: true,
  ),
];
