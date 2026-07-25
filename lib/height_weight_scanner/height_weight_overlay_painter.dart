import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'config.dart';
import 'pose_geometry.dart';

class HeightWeightOverlayPainter extends CustomPainter {
  HeightWeightOverlayPainter({
    required this.observation,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
  });

  final PoseObservation? observation;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final guideY = size.height * ScannerConfig.footGuideYRatio;
    final guidePaint = Paint()
      ..color = const Color(0xff2196f3)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, guideY), Offset(size.width, guideY), guidePaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Align feet with this line',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(size.width - textPainter.width - 12, guideY - 24),
    );

    final current = observation;
    if (current == null) {
      return;
    }

    if (current.pose != null) {
      _drawPose(canvas, size, current.pose!);
    }

    final bounds = current.bounds;
    if (bounds != null) {
      final rect = Rect.fromPoints(
        _translate(bounds.topLeft, size),
        _translate(bounds.bottomRight, size),
      );
      final boundsPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = current.valid ? Colors.greenAccent : Colors.orangeAccent;
      canvas.drawRect(rect, boundsPaint);
    }

    final colors = <String, Color>{
      'head': Colors.yellowAccent,
      'feet': Colors.yellowAccent,
      'shoulders': Colors.lightBlueAccent,
      'waist': Colors.pinkAccent,
      'hips': Colors.orangeAccent,
    };

    for (final entry in current.lines.entries) {
      final paint = Paint()
        ..color = colors[entry.key] ?? Colors.white
        ..strokeWidth = 3;
      canvas.drawLine(
        _translate(entry.value.start, size),
        _translate(entry.value.end, size),
        paint,
      );
    }
  }

  void _drawPose(Canvas canvas, Size size, Pose pose) {
    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.yellow;
    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.blueAccent;
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    for (final landmark in pose.landmarks.values) {
      canvas.drawCircle(
        _translate(Offset(landmark.x, landmark.y), size),
        2,
        dotPaint,
      );
    }

    void line(PoseLandmarkType a, PoseLandmarkType b, Paint paint) {
      final first = pose.landmarks[a];
      final second = pose.landmarks[b];
      if (first == null || second == null) {
        return;
      }
      canvas.drawLine(
        _translate(Offset(first.x, first.y), size),
        _translate(Offset(second.x, second.y), size),
        paint,
      );
    }

    line(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
    line(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
    line(
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightElbow,
      rightPaint,
    );
    line(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);
    line(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
    line(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, rightPaint);
    line(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
    line(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
    line(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
    line(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);
  }

  Offset _translate(Offset point, Size canvasSize) {
    final rotated = _rotate(point);
    final sourceSize = _rotatedImageSize();
    var x = rotated.dx;
    final y = rotated.dy;

    if (cameraLensDirection == CameraLensDirection.front) {
      x = sourceSize.width - x;
    }

    return Offset(
      x / sourceSize.width * canvasSize.width,
      y / sourceSize.height * canvasSize.height,
    );
  }

  Offset _rotate(Offset point) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return Offset(point.dy, imageSize.width - point.dx);
      case InputImageRotation.rotation180deg:
        return Offset(imageSize.width - point.dx, imageSize.height - point.dy);
      case InputImageRotation.rotation270deg:
        return Offset(imageSize.height - point.dy, point.dx);
      case InputImageRotation.rotation0deg:
        return point;
    }
  }

  Size _rotatedImageSize() {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return Size(imageSize.height, imageSize.width);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return imageSize;
    }
  }

  @override
  bool shouldRepaint(covariant HeightWeightOverlayPainter oldDelegate) {
    return oldDelegate.observation != observation ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.rotation != rotation ||
        oldDelegate.cameraLensDirection != cameraLensDirection;
  }
}
