class WebVitalFrame {
  const WebVitalFrame({
    required this.signal,
    required this.brightness,
    required this.skinRatio,
    required this.isValidFrame,
  });

  final double signal;
  final double brightness;
  final double skinRatio;
  final bool isValidFrame;
}

Future<WebVitalFrame?> estimateWebVitalFrameFromCamera(int cameraId) async {
  return null;
}
