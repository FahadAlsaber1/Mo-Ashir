import 'dart:math' as math;

import 'config.dart';
import 'measurement_filter.dart';
import 'pose_geometry.dart';

class FrameMeasurement {
  const FrameMeasurement({required this.heightCm, required this.weightKg});

  final double heightCm;
  final double weightKg;
}

class HeightEstimator {
  static double estimateFrame(BodyFeatures features) {
    final body = math.max(features.bodyHeight, 1.0);
    final imageHeight = math.max(features.imageHeight, 1.0);
    final footOffset = features.footY - imageHeight / 2.0;
    if (footOffset < imageHeight * 0.10) {
      throw StateError('Keep feet below image centre and camera level');
    }

    var estimate = body * ScannerConfig.cameraHeightCm / footOffset;
    final headRatio = features.headLength / body;
    final legRatio = features.legLength / body;
    estimate *= _clamp(
      math.pow(0.135 / math.max(headRatio, 0.08), 0.05),
      0.98,
      1.02,
    );
    estimate *= _clamp(math.pow(legRatio / 0.53, 0.03), 0.99, 1.01);
    estimate *= ScannerConfig.heightScaleCorrection;

    if (estimate < ScannerConfig.minHeightCm ||
        estimate > ScannerConfig.maxHeightCm) {
      throw StateError(
        'Height outside 100-230 cm; check camera height and level',
      );
    }
    return estimate;
  }

  static RobustResult finalEstimate(Iterable<double> values) =>
      robustMedian(values);
}

class WeightEstimator {
  static double estimateFrame(BodyFeatures features, double heightCm) {
    final body = math.max(features.bodyHeight, 1.0);
    final shoulderRatio = features.shoulderWidth / body;
    final waistRatio = features.waistWidth / body;
    final hipRatio = features.hipWidth / body;
    final areaRatio = features.silhouetteArea / (body * body);

    var build = 0.20 * shoulderRatio / 0.25 +
        0.35 * waistRatio / 0.19 +
        0.25 * hipRatio / 0.24 +
        0.20 * math.sqrt(math.max(areaRatio, 0.04) / 0.20);
    build = _clamp(build, 0.78, 1.38);

    final relativeBuild = _clamp(build / 1.38, 0.88, 1.12);
    var estimate = ScannerConfig.referenceWeightKg;
    estimate *= math.pow(relativeBuild, 1.25);
    estimate *= math.pow(heightCm / ScannerConfig.referenceHeightCm, 0.75);

    final personalLow = math.max(
      ScannerConfig.minWeightKg,
      ScannerConfig.referenceWeightKg * 0.82,
    );
    final personalHigh = math.min(
      ScannerConfig.maxWeightKg,
      ScannerConfig.referenceWeightKg * 1.18,
    );
    return _clamp(estimate, personalLow, personalHigh);
  }

  static RobustResult finalEstimate(Iterable<double> values) =>
      robustMedian(values);
}

double _clamp(num value, double low, double high) {
  return value.toDouble().clamp(low, high).toDouble();
}
