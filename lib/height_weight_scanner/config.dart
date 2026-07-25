class ScannerConfig {
  static const appTitle = 'Webcam Height & Estimated Weight';

  static const minValidFrames = 30;
  static const targetValidFrames = 120;
  static const visibilityThreshold = 0.70;
  static const edgeMarginRatio = 0.015;
  static const uprightMaxTiltRatio = 0.10;

  static const minHeightCm = 100.0;
  static const maxHeightCm = 230.0;
  static const cameraHeightCm = 120.0;
  static const heightScaleCorrection = 0.7948;

  static const referenceHeightCm = 176.0;
  static const referenceWeightKg = 73.0;

  static const footGuideYRatio = 0.88;
  static const footGuideToleranceRatio = 0.015;

  static const minWeightKg = 30.0;
  static const maxWeightKg = 250.0;
}
