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

  static Future<ThermalCameraResult?> captureVerifiedTemperature() async {
    // Hardware integration point. Return a result only after the thermal camera
    // has matched the face for the current patient and measured temperature.
    return null;
  }
}
