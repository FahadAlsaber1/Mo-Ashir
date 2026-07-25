import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class BodyAnalysisResult {
  const BodyAnalysisResult({
    required this.captureAccepted,
    required this.completeBodyVisible,
    required this.knownScaleVisible,
    required this.messageAr,
    required this.messageEn,
    required this.model,
    this.heightCm,
    this.weightKg,
  });

  final bool captureAccepted;
  final bool completeBodyVisible;
  final bool knownScaleVisible;
  final String messageAr;
  final String messageEn;
  final String model;
  final double? heightCm;
  final double? weightKg;

  bool get hasEstimate => heightCm != null && weightKg != null;

  String get displayMessage {
    final height = heightCm == null
        ? 'Height: unavailable.'
        : 'Height: ${heightCm!.toStringAsFixed(1)} cm.';
    final weight = weightKg == null
        ? 'Weight: unavailable.'
        : 'Weight: ${weightKg!.toStringAsFixed(1)} kg.';
    return '$messageEn $height $weight';
  }

  factory BodyAnalysisResult.fromJson(Map<String, dynamic> json) {
    return BodyAnalysisResult(
      captureAccepted: json['capture_accepted'] == true,
      completeBodyVisible: json['complete_body_visible'] == true,
      knownScaleVisible: json['known_scale_visible'] == true,
      messageAr: json['message_ar']?.toString() ?? '',
      messageEn: json['message_en']?.toString() ?? 'Image analyzed.',
      model: json['model']?.toString() ?? 'unknown',
      heightCm: _doubleOrNull(json['height_cm']),
      weightKg: _doubleOrNull(json['weight_kg']),
    );
  }

  static double? _doubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class BodyAnalysisApi {
  static const _endpoint = String.fromEnvironment(
    'BODY_ANALYSIS_API_URL',
    defaultValue: 'http://127.0.0.1:8787/analyze-body',
  );

  static Future<BodyAnalysisResult> analyzeDataUrl(String dataUrl) async {
    return _postImageDataUrl(dataUrl);
  }

  static Future<BodyAnalysisResult> analyzeJpegBytes(Uint8List bytes) async {
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    return _postImageDataUrl(dataUrl);
  }

  static Future<BodyAnalysisResult> _postImageDataUrl(String dataUrl) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'image_data_url': dataUrl}),
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const BodyAnalysisException(
        'Body analysis server timed out. Check the local API proxy.',
      );
    } on http.ClientException {
      throw const BodyAnalysisException(
        'Body analysis server is offline. Start the local API proxy.',
      );
    }

    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'error': 'Unexpected API response.'};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload['error']?.toString() ?? '';
      if (message.contains('OPENAI_API_KEY')) {
        throw const BodyAnalysisException(
          'Add a new OPENAI_API_KEY in server/.env, then restart the body analysis server.',
        );
      }
      throw BodyAnalysisException(
        message.isEmpty ? 'Body analysis API failed.' : message,
      );
    }

    return BodyAnalysisResult.fromJson(payload);
  }
}

class BodyAnalysisException implements Exception {
  const BodyAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}
