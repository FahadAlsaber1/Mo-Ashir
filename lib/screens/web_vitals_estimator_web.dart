import 'dart:js_interop';
import 'dart:math' as math;

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_web/camera_web.dart';
import 'package:web/web.dart' as web;

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
  final platform = CameraPlatform.instance;
  if (platform is! CameraPlugin) return null;

  // camera_web keeps the active browser video element behind this testing hook.
  // It is the only available route for frame-level browser rPPG sampling.
  // ignore: invalid_use_of_visible_for_testing_member
  final dynamic camera = platform.getCamera(cameraId);
  final video = camera.videoElement as web.HTMLVideoElement;
  final videoWidth = video.videoWidth;
  final videoHeight = video.videoHeight;
  if (videoWidth <= 0 || videoHeight <= 0) return null;

  const frameWidth = 128;
  final frameHeight =
      math.max(96, (frameWidth * videoHeight / videoWidth).round());
  final canvas = web.HTMLCanvasElement()
    ..width = frameWidth
    ..height = frameHeight;
  final context = canvas.context2D;
  context.drawImage(video, 0, 0, frameWidth.toDouble(), frameHeight.toDouble());
  final data = context.getImageData(0, 0, frameWidth, frameHeight).data.toDart;

  final roiLeft = (frameWidth * .18).round();
  final roiRight = (frameWidth * .82).round();
  final roiTop = (frameHeight * .16).round();
  final roiBottom = (frameHeight * .72).round();

  var weightedSignal = 0.0;
  var fallbackSignal = 0.0;
  var brightness = 0.0;
  var skinCount = 0;
  var fallbackCount = 0;
  var totalCount = 0;
  var centerSkinCount = 0;
  var centerTotalCount = 0;

  for (var y = roiTop; y < roiBottom; y += 2) {
    for (var x = roiLeft; x < roiRight; x += 2) {
      final index = (y * frameWidth + x) * 4;
      final red = data[index].toDouble();
      final green = data[index + 1].toDouble();
      final blue = data[index + 2].toDouble();
      final maxChannel = math.max(red, math.max(green, blue));
      final minChannel = math.min(red, math.min(green, blue));
      final luminance = red * .299 + green * .587 + blue * .114;
      final likelySkin = red > 45 &&
          green > 30 &&
          red > blue * .95 &&
          green > blue * .75 &&
          maxChannel - minChannel > 12 &&
          luminance > 35;

      totalCount++;
      brightness += luminance;
      fallbackSignal += (green * .58) + (red * .30) - (blue * .08);
      fallbackCount++;
      final isCenterFaceArea = x > frameWidth * .34 &&
          x < frameWidth * .66 &&
          y > frameHeight * .26 &&
          y < frameHeight * .64;
      if (isCenterFaceArea) centerTotalCount++;
      if (!likelySkin) continue;

      skinCount++;
      if (isCenterFaceArea) centerSkinCount++;
      weightedSignal += (green * .62) + (red * .30) - (blue * .08);
    }
  }

  if (totalCount == 0 || fallbackCount == 0) return null;
  final skinRatio = skinCount / totalCount;
  final centerSkinRatio =
      centerTotalCount == 0 ? 0.0 : centerSkinCount / centerTotalCount;
  final averageBrightness = brightness / totalCount;
  final signal = skinRatio >= .05
      ? weightedSignal / skinCount
      : fallbackSignal / fallbackCount;

  return WebVitalFrame(
    signal: signal,
    brightness: averageBrightness,
    skinRatio: skinRatio,
    isValidFrame: skinRatio >= .12 &&
        centerSkinRatio >= .08 &&
        averageBrightness >= 40 &&
        averageBrightness <= 220,
  );
}
