import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'config.dart';

class BodyFeatures {
  const BodyFeatures({
    required this.shoulderWidth,
    required this.waistWidth,
    required this.hipWidth,
    required this.torsoLength,
    required this.headLength,
    required this.legLength,
    required this.kneeHeight,
    required this.silhouetteArea,
    required this.bodyHeight,
    required this.imageWidth,
    required this.imageHeight,
    required this.footY,
  });

  final double shoulderWidth;
  final double waistWidth;
  final double hipWidth;
  final double torsoLength;
  final double headLength;
  final double legLength;
  final double kneeHeight;
  final double silhouetteArea;
  final double bodyHeight;
  final double imageWidth;
  final double imageHeight;
  final double footY;
}

class PoseObservation {
  const PoseObservation({
    required this.valid,
    required this.reason,
    this.bodyHeightPixels = 0,
    this.features,
    this.pose,
    this.bounds,
    this.lines = const {},
  });

  final bool valid;
  final String reason;
  final double bodyHeightPixels;
  final BodyFeatures? features;
  final Pose? pose;
  final Rect? bounds;
  final Map<String, LineSegment> lines;
}

class LineSegment {
  const LineSegment(this.start, this.end);

  final Offset start;
  final Offset end;
}

class PoseGeometry {
  static PoseObservation process(List<Pose> poses, Size imageSize) {
    if (poses.length > 1) {
      return const PoseObservation(
        valid: false,
        reason: 'More than one person detected',
      );
    }
    if (poses.isEmpty) {
      return const PoseObservation(valid: false, reason: 'No person detected');
    }

    final pose = poses.first;
    final landmarks = pose.landmarks;
    const required = <PoseLandmarkType>[
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEye,
      PoseLandmarkType.rightEye,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftHeel,
      PoseLandmarkType.rightHeel,
      PoseLandmarkType.leftFootIndex,
      PoseLandmarkType.rightFootIndex,
    ];
    const failureMessages = <PoseLandmarkType, String>{
      PoseLandmarkType.nose: 'Make sure the top of your head is visible',
      PoseLandmarkType.leftEye: 'Make sure the top of your head is visible',
      PoseLandmarkType.rightEye: 'Make sure the top of your head is visible',
      PoseLandmarkType.leftEar: 'Stand straight and face the camera',
      PoseLandmarkType.rightEar: 'Stand straight and face the camera',
      PoseLandmarkType.leftShoulder: 'Stand straight and face the camera',
      PoseLandmarkType.rightShoulder: 'Stand straight and face the camera',
      PoseLandmarkType.leftHip: 'Move farther from the camera',
      PoseLandmarkType.rightHip: 'Move farther from the camera',
      PoseLandmarkType.leftKnee: 'Move farther from the camera',
      PoseLandmarkType.rightKnee: 'Move farther from the camera',
      PoseLandmarkType.leftAnkle: 'Make sure your feet are visible',
      PoseLandmarkType.rightAnkle: 'Make sure your feet are visible',
      PoseLandmarkType.leftHeel: 'Make sure your feet are visible',
      PoseLandmarkType.rightHeel: 'Make sure your feet are visible',
      PoseLandmarkType.leftFootIndex: 'Make sure your feet are visible',
      PoseLandmarkType.rightFootIndex: 'Make sure your feet are visible',
    };

    for (final type in required) {
      final landmark = landmarks[type];
      if (landmark == null ||
          landmark.likelihood < ScannerConfig.visibilityThreshold) {
        return PoseObservation(
          valid: false,
          reason: failureMessages[type] ?? 'Move farther from the camera',
          pose: pose,
        );
      }
    }

    Offset point(PoseLandmarkType type) {
      final landmark = landmarks[type]!;
      return Offset(landmark.x, landmark.y);
    }

    final width = imageSize.width;
    final height = imageSize.height;
    final face = [
      point(PoseLandmarkType.nose),
      point(PoseLandmarkType.leftEye),
      point(PoseLandmarkType.rightEye),
      point(PoseLandmarkType.leftEar),
      point(PoseLandmarkType.rightEar),
    ];

    final leftShoulder = point(PoseLandmarkType.leftShoulder);
    final rightShoulder = point(PoseLandmarkType.rightShoulder);
    final leftHip = point(PoseLandmarkType.leftHip);
    final rightHip = point(PoseLandmarkType.rightHip);
    final shoulderMid = Offset(
      (leftShoulder.dx + rightShoulder.dx) / 2,
      (leftShoulder.dy + rightShoulder.dy) / 2,
    );
    final hipMid = Offset(
      (leftHip.dx + rightHip.dx) / 2,
      (leftHip.dy + rightHip.dy) / 2,
    );

    final faceTop = face.map((p) => p.dy).reduce(math.min);
    final headExtension = math.max(8.0, (shoulderMid.dy - faceTop) * 0.32);
    final topY = faceTop - headExtension;
    final feet = [
      point(PoseLandmarkType.leftHeel),
      point(PoseLandmarkType.rightHeel),
      point(PoseLandmarkType.leftFootIndex),
      point(PoseLandmarkType.rightFootIndex),
    ];
    final bottomY = feet.map((p) => p.dy).reduce(math.max);

    final allPoints = required.map(point).toList();
    final x1 = allPoints.map((p) => p.dx).reduce(math.min);
    final x2 = allPoints.map((p) => p.dx).reduce(math.max);
    final marginX = width * ScannerConfig.edgeMarginRatio;
    final marginY = height * ScannerConfig.edgeMarginRatio;
    final bounds = Rect.fromLTRB(x1, topY, x2, bottomY);

    if (topY <= marginY) {
      return PoseObservation(
        valid: false,
        reason: 'Head is outside the frame',
        pose: pose,
        bounds: bounds,
      );
    }
    if (bottomY >= height - marginY) {
      return PoseObservation(
        valid: false,
        reason: 'Feet are outside the frame',
        pose: pose,
        bounds: bounds,
      );
    }
    if (x1 <= marginX || x2 >= width - marginX) {
      return PoseObservation(
        valid: false,
        reason: 'Step farther away',
        pose: pose,
        bounds: bounds,
      );
    }

    final bodyHeight = bottomY - topY;
    if (bodyHeight > height * 0.97) {
      return PoseObservation(
        valid: false,
        reason: 'Step farther away',
        pose: pose,
        bounds: bounds,
      );
    }
    if (bodyHeight < height * 0.65) {
      return PoseObservation(
        valid: false,
        reason: 'Step closer',
        pose: pose,
        bounds: bounds,
      );
    }

    final footTarget = height * ScannerConfig.footGuideYRatio;
    final footError = bottomY - footTarget;
    if (footError.abs() > height * ScannerConfig.footGuideToleranceRatio) {
      final direction = footError > 0 ? 'farther' : 'closer';
      return PoseObservation(
        valid: false,
        reason: 'Step $direction: align feet with blue line',
        pose: pose,
        bounds: bounds,
      );
    }

    if ((shoulderMid.dx - hipMid.dx).abs() / bodyHeight >
        ScannerConfig.uprightMaxTiltRatio) {
      return PoseObservation(
        valid: false,
        reason: 'Stand straight',
        pose: pose,
        bounds: bounds,
      );
    }

    final shoulderWidth = (rightShoulder.dx - leftShoulder.dx).abs();
    final hipWidth = (rightHip.dx - leftHip.dx).abs() * 1.08;
    final waistWidth = (shoulderWidth * 0.46 + hipWidth * 0.54) * 0.86;
    final shoulderY = shoulderMid.dy;
    final hipY = hipMid.dy;
    final waistY = shoulderY + 0.68 * (hipY - shoulderY);
    final kneeMidY = (point(PoseLandmarkType.leftKnee).dy +
            point(PoseLandmarkType.rightKnee).dy) /
        2;
    final averageWidth = (shoulderWidth + waistWidth + hipWidth) / 3;
    final silhouetteArea = bodyHeight * averageWidth * 0.82;

    final lines = {
      'head': LineSegment(Offset(x1, topY), Offset(x2, topY)),
      'feet': LineSegment(Offset(x1, bottomY), Offset(x2, bottomY)),
      'shoulders': LineSegment(
        Offset(leftShoulder.dx, shoulderY),
        Offset(rightShoulder.dx, shoulderY),
      ),
      'waist': LineSegment(
        Offset(shoulderMid.dx - waistWidth / 2, waistY),
        Offset(shoulderMid.dx + waistWidth / 2, waistY),
      ),
      'hips': LineSegment(Offset(leftHip.dx, hipY), Offset(rightHip.dx, hipY)),
    };

    return PoseObservation(
      valid: true,
      reason: 'Valid frame collected',
      bodyHeightPixels: bodyHeight,
      features: BodyFeatures(
        shoulderWidth: shoulderWidth,
        waistWidth: waistWidth,
        hipWidth: hipWidth,
        torsoLength: hipY - shoulderY,
        headLength: shoulderY - topY,
        legLength: bottomY - hipY,
        kneeHeight: bottomY - kneeMidY,
        silhouetteArea: silhouetteArea,
        bodyHeight: bodyHeight,
        imageWidth: width,
        imageHeight: height,
        footY: bottomY,
      ),
      pose: pose,
      bounds: bounds,
      lines: lines,
    );
  }
}
