import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ThermalCameraResult {
  const ThermalCameraResult({
    required this.temperatureC,
    required this.faceRecognitionConfirmed,
    required this.capturedAt,
    this.confidence = 'Unknown',
  });

  final double temperatureC;
  final bool faceRecognitionConfirmed;
  final DateTime capturedAt;
  final String confidence;
}

class ThermalCamera {
  const ThermalCamera._();

  static const String endpoint = String.fromEnvironment(
    'THERMAL_CAMERA_API_URL',
    defaultValue: '',
  );

  static Future<ThermalCameraResult?> captureVerifiedTemperature({
    String? patientId,
    String? patientName,
  }) async {
    if (endpoint.trim().isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (patientId != null && patientId.trim().isNotEmpty)
                'patient_id': patientId.trim(),
              if (patientName != null && patientName.trim().isNotEmpty)
                'patient_name': patientName.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final temperature = _doubleValue(
        decoded['temperature_c'] ?? decoded['temperatureC'],
      );
      final faceConfirmed = _boolValue(
        decoded['face_recognition_confirmed'] ??
            decoded['faceRecognitionConfirmed'],
      );
      final faceDetected = _optionalBoolValue(
            decoded['face_detected'] ?? decoded['faceDetected'],
          ) ??
          _optionalBoolValue(
            decoded['person_detected'] ?? decoded['personDetected'],
          ) ??
          faceConfirmed;
      final faceCount =
          _intValue(decoded['face_count'] ?? decoded['faceCount']);
      final faceConfidence = _doubleValue(
        decoded['face_confidence'] ?? decoded['faceConfidence'],
      );
      if (temperature == null ||
          !faceConfirmed ||
          !faceDetected ||
          faceCount == 0 ||
          (faceConfidence != null && faceConfidence < 0.65)) {
        return null;
      }

      return ThermalCameraResult(
        temperatureC: temperature,
        faceRecognitionConfirmed: true,
        capturedAt:
            _dateValue(decoded['captured_at'] ?? decoded['capturedAt']) ??
                DateTime.now(),
        confidence:
            (decoded['confidence'] as String?)?.trim().isNotEmpty == true
                ? (decoded['confidence'] as String).trim()
                : 'Verified',
      );
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    } on http.ClientException {
      return null;
    }
  }

  static double? _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _boolValue(Object? value) {
    return _optionalBoolValue(value) ?? false;
  }

  static bool? _optionalBoolValue(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    if (value is num) return value != 0;
    return null;
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static DateTime? _dateValue(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }
}
