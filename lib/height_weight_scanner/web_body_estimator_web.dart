import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_web/camera_web.dart';
import 'package:web/web.dart' as web;

class WebBodyCapture {
  const WebBodyCapture({
    required this.photoDataUrl,
    required this.completeBodyLikely,
    required this.faceLikely,
    required this.message,
    required this.bodyHeightRatio,
  });

  final String photoDataUrl;
  final bool completeBodyLikely;
  final bool faceLikely;
  final String message;
  final double bodyHeightRatio;
}

Future<WebBodyCapture?> captureWebBodyPhotoFromCamera(int cameraId) async {
  final platform = CameraPlatform.instance;
  if (platform is! CameraPlugin) return null;

  // camera_web exposes the active HTML video element only through this testing
  // hook; reading it is required for browser-side frame capture.
  // ignore: invalid_use_of_visible_for_testing_member
  final dynamic camera = platform.getCamera(cameraId);
  final video = camera.videoElement as web.HTMLVideoElement;
  final videoWidth = video.videoWidth;
  final videoHeight = video.videoHeight;
  if (videoWidth <= 0 || videoHeight <= 0) return null;

  const frameWidth = 240;
  final frameHeight =
      math.max(160, (frameWidth * videoHeight / videoWidth).round());
  final canvas = web.HTMLCanvasElement()
    ..width = frameWidth
    ..height = frameHeight;
  final context = canvas.context2D;
  context.drawImage(video, 0, 0, frameWidth.toDouble(), frameHeight.toDouble());

  final data = context.getImageData(0, 0, frameWidth, frameHeight).data.toDart;
  final background = _sampleBackground(data, frameWidth, frameHeight);
  final box = _foregroundBox(data, frameWidth, frameHeight, background);
  if (box == null) {
    return WebBodyCapture(
      photoDataUrl: canvas.toDataURL('image/jpeg', 0.86.toJS),
      completeBodyLikely: false,
      faceLikely: false,
      message: 'Move closer to the camera',
      bodyHeightRatio: 0,
    );
  }

  final bodyHeightRatio = box.height / frameHeight;
  final bodyWidthRatio = box.width / frameWidth;
  final topRatio = box.minY / frameHeight;
  final bottomRatio = box.maxY / frameHeight;
  final coverage = box.pixelCount / (frameWidth * frameHeight);
  final faceLikely = _faceLikely(data, frameWidth, frameHeight, box);
  final completeBodyLikely = bodyHeightRatio >= .55 &&
      bodyHeightRatio <= .96 &&
      bodyWidthRatio >= .06 &&
      bodyWidthRatio <= .72 &&
      coverage >= .025 &&
      coverage <= .55 &&
      faceLikely &&
      topRatio > .01 &&
      bottomRatio < .985;

  return WebBodyCapture(
    photoDataUrl: canvas.toDataURL('image/jpeg', 0.86.toJS),
    completeBodyLikely: completeBodyLikely,
    faceLikely: faceLikely,
    message: completeBodyLikely
        ? 'Full body detected'
        : _messageForBox(
            bodyHeightRatio: bodyHeightRatio,
            topRatio: topRatio,
            bottomRatio: bottomRatio,
            faceLikely: faceLikely,
          ),
    bodyHeightRatio: bodyHeightRatio,
  );
}

String _messageForBox({
  required double bodyHeightRatio,
  required double topRatio,
  required double bottomRatio,
  required bool faceLikely,
}) {
  if (!faceLikely) return 'Center your face in the camera';
  if (topRatio <= .01) return 'Make sure the top of your head is visible';
  if (bottomRatio >= .985) return 'Make sure your feet are visible';
  if (bodyHeightRatio > .96) return 'Move slightly farther from the camera';
  if (bodyHeightRatio < .55) return 'Move closer to the camera';
  return 'Stand straight and face the camera';
}

_Rgb _sampleBackground(Uint8ClampedList data, int width, int height) {
  var red = 0;
  var green = 0;
  var blue = 0;
  var count = 0;
  final edge = math.max(5, width ~/ 18);

  void add(int x, int y) {
    final index = (y * width + x) * 4;
    red += data[index];
    green += data[index + 1];
    blue += data[index + 2];
    count++;
  }

  for (var y = 0; y < height; y += 2) {
    for (var x = 0; x < edge; x += 2) {
      add(x, y);
      add(width - 1 - x, y);
    }
  }
  for (var y = 0; y < edge; y += 2) {
    for (var x = 0; x < width; x += 2) {
      add(x, y);
      add(x, height - 1 - y);
    }
  }

  return _Rgb(red / count, green / count, blue / count);
}

_ForegroundBox? _foregroundBox(
  Uint8ClampedList data,
  int width,
  int height,
  _Rgb background,
) {
  var minX = width;
  var minY = height;
  var maxX = 0;
  var maxY = 0;
  var count = 0;
  final bgLum = background.luminance;
  final threshold = math.max(34.0, bgLum * .16);

  for (var y = 2; y < height - 2; y += 2) {
    for (var x = 2; x < width - 2; x += 2) {
      final index = (y * width + x) * 4;
      final red = data[index].toDouble();
      final green = data[index + 1].toDouble();
      final blue = data[index + 2].toDouble();
      final lum = red * .299 + green * .587 + blue * .114;
      final distance = math.sqrt(
        math.pow(red - background.red, 2) +
            math.pow(green - background.green, 2) +
            math.pow(blue - background.blue, 2),
      );
      final foreground = distance > threshold || (bgLum - lum).abs() > 28;
      if (!foreground) continue;

      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
      count++;
    }
  }

  if (count < 70) return null;
  return _ForegroundBox(
    minX: minX,
    minY: minY,
    maxX: maxX,
    maxY: maxY,
    pixelCount: count * 4,
  );
}

bool _faceLikely(
  Uint8ClampedList data,
  int width,
  int height,
  _ForegroundBox box,
) {
  final boxWidth = box.width;
  final boxHeight = box.height;
  if (boxWidth < width * .05 || boxHeight < height * .18) return false;

  final faceLeft = math.max(0, box.minX + (boxWidth * .18).round());
  final faceRight = math.min(width - 1, box.maxX - (boxWidth * .18).round());
  final faceTop = math.max(0, box.minY);
  final faceBottom = math.min(
    height - 1,
    box.minY + math.max(14, (boxHeight * .26).round()),
  );
  if (faceRight <= faceLeft || faceBottom <= faceTop) return false;

  var total = 0;
  var skin = 0;
  var centerSkin = 0;
  var centerTotal = 0;
  var brightEnough = 0;
  for (var y = faceTop; y <= faceBottom; y += 2) {
    for (var x = faceLeft; x <= faceRight; x += 2) {
      final index = (y * width + x) * 4;
      final red = data[index].toDouble();
      final green = data[index + 1].toDouble();
      final blue = data[index + 2].toDouble();
      final luminance = red * .299 + green * .587 + blue * .114;
      final maxChannel = math.max(red, math.max(green, blue));
      final minChannel = math.min(red, math.min(green, blue));
      final chroma = maxChannel - minChannel;
      final likelySkin = luminance >= 38 &&
          luminance <= 235 &&
          chroma >= 10 &&
          red >= blue * .82 &&
          green >= blue * .58 &&
          red >= green * .70 &&
          red <= green * 1.85;
      final center = x > faceLeft + (faceRight - faceLeft) * .25 &&
          x < faceRight - (faceRight - faceLeft) * .25;

      total++;
      if (center) centerTotal++;
      if (luminance >= 38 && luminance <= 235) brightEnough++;
      if (!likelySkin) continue;

      skin++;
      if (center) centerSkin++;
    }
  }

  if (total == 0 || centerTotal == 0) return false;
  final skinRatio = skin / total;
  final centerSkinRatio = centerSkin / centerTotal;
  final usableLightRatio = brightEnough / total;
  return skin >= 18 &&
      skinRatio >= .10 &&
      centerSkinRatio >= .08 &&
      usableLightRatio >= .45;
}

class _Rgb {
  const _Rgb(this.red, this.green, this.blue);

  final double red;
  final double green;
  final double blue;

  double get luminance => red * .299 + green * .587 + blue * .114;
}

class _ForegroundBox {
  const _ForegroundBox({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.pixelCount,
  });

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
  final int pixelCount;

  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;
}
