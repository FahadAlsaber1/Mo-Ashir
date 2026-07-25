class WebBodyCapture {
  const WebBodyCapture({
    required this.photoDataUrl,
    required this.completeBodyLikely,
    required this.message,
    required this.bodyHeightRatio,
  });

  final String photoDataUrl;
  final bool completeBodyLikely;
  final String message;
  final double bodyHeightRatio;
}

Future<WebBodyCapture?> captureWebBodyPhotoFromCamera(int cameraId) async {
  return null;
}
