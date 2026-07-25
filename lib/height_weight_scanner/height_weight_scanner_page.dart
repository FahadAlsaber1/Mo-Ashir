import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'body_analysis_api.dart';
import 'config.dart';
import 'measurement_validation.dart';
import 'pose_geometry.dart';
import 'web_body_estimator_stub.dart'
    if (dart.library.js_interop) 'web_body_estimator_web.dart';

class ScanResult {
  const ScanResult({
    required this.heightCm,
    required this.weightKg,
    required this.confidence,
    required this.validFrames,
    required this.heightSource,
    required this.weightSource,
    this.photoPath,
    this.photoDataUrl,
    this.actualHeightCm,
    this.actualWeightKg,
    this.heightErrorCm,
    this.weightErrorKg,
    this.heightAccuracyPercent,
    this.weightAccuracyPercent,
  });

  final double heightCm;
  final double weightKg;
  final String confidence;
  final int validFrames;
  final String heightSource;
  final String weightSource;
  final String? photoPath;
  final String? photoDataUrl;
  final double? actualHeightCm;
  final double? actualWeightKg;
  final double? heightErrorCm;
  final double? weightErrorKg;
  final double? heightAccuracyPercent;
  final double? weightAccuracyPercent;

  ScanResult copyWith({
    String? confidence,
    String? heightSource,
    String? weightSource,
    String? photoPath,
    String? photoDataUrl,
    double? actualHeightCm,
    double? actualWeightKg,
    double? heightErrorCm,
    double? weightErrorKg,
    double? heightAccuracyPercent,
    double? weightAccuracyPercent,
  }) {
    return ScanResult(
      heightCm: heightCm,
      weightKg: weightKg,
      confidence: confidence ?? this.confidence,
      validFrames: validFrames,
      heightSource: heightSource ?? this.heightSource,
      weightSource: weightSource ?? this.weightSource,
      photoPath: photoPath ?? this.photoPath,
      photoDataUrl: photoDataUrl ?? this.photoDataUrl,
      actualHeightCm: actualHeightCm ?? this.actualHeightCm,
      actualWeightKg: actualWeightKg ?? this.actualWeightKg,
      heightErrorCm: heightErrorCm ?? this.heightErrorCm,
      weightErrorKg: weightErrorKg ?? this.weightErrorKg,
      heightAccuracyPercent:
          heightAccuracyPercent ?? this.heightAccuracyPercent,
      weightAccuracyPercent:
          weightAccuracyPercent ?? this.weightAccuracyPercent,
    );
  }
}

class HeightWeightScannerPage extends StatefulWidget {
  const HeightWeightScannerPage({
    super.key,
    this.initialLensDirection = CameraLensDirection.front,
    this.embedded = false,
    this.onResult,
  });

  final CameraLensDirection initialLensDirection;
  final bool embedded;
  final ValueChanged<ScanResult>? onResult;

  @override
  State<HeightWeightScannerPage> createState() =>
      _HeightWeightScannerPageState();
}

class _HeightWeightScannerPageState extends State<HeightWeightScannerPage>
    with WidgetsBindingObserver {
  PoseDetector? _poseDetector;
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  CameraDescription? _activeCamera;
  HeightWeightMeasurementState _measurementState =
      HeightWeightMeasurementState.cameraInitializing;

  bool _isInitializing = true;
  bool _isRunning = false;
  bool _isBusy = false;
  bool _isWebScanning = false;
  double? _previousHeightPx;
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _stableBodySince;
  bool _captureAllowed = false;
  String _status = 'Preparing camera...';

  static const _bodyInstruction =
      'Stand 2-3 metres from the camera. Make sure your full body, including your head and feet, is visible.';

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _poseDetector = PoseDetector(options: PoseDetectorOptions());
    }
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poseDetector?.close();
    _disposeController();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeController();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _measurementState = HeightWeightMeasurementState.cameraInitializing;
      _status = 'Preparing camera...';
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw StateError('No camera found on this device.');
      }

      _activeCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == widget.initialLensDirection,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        _activeCamera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: !kIsWeb && Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();

      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _measurementState = HeightWeightMeasurementState.waitingForPerson;
        _status = kIsWeb ? 'Edge camera ready' : 'Ready';
      });
    } on CameraException catch (error) {
      setState(() {
        _isInitializing = false;
        _status = error.code == 'CameraAccessDenied'
            ? 'Camera permission was denied.'
            : 'Camera error: ${error.description ?? error.code}';
      });
    } catch (error) {
      setState(() {
        _isInitializing = false;
        _status = error.toString();
      });
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) {
      return;
    }
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  Future<void> _startScan() async {
    if (kIsWeb) {
      await _takeWebPhotoScan();
      return;
    }

    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }

    setState(() {
      _previousHeightPx = null;
      _isRunning = true;
      _captureAllowed = false;
      _stableBodySince = null;
      _measurementState = HeightWeightMeasurementState.waitingForPerson;
      _status = 'Scanning...';
    });

    await controller.startImageStream(_processCameraImage);
  }

  Future<void> _stopScan() async {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isRunning = false;
      _status = 'Scan stopped';
    });
  }

  Future<void> _takeWebPhotoScan() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isWebScanning) {
      return;
    }

    setState(() {
      _isWebScanning = true;
      _measurementState = HeightWeightMeasurementState.capturing;
      _status = 'Taking photo...';
    });

    final capture = await captureWebBodyPhotoFromCamera(controller.cameraId);

    if (!mounted) return;

    if (capture == null) {
      setState(() {
        _isWebScanning = false;
        _measurementState = HeightWeightMeasurementState.failed;
        _status =
            'Could not read the camera photo. Check camera permission and try again.';
      });
      return;
    }

    setState(() {
      _measurementState = HeightWeightMeasurementState.validatingImage;
      _status = 'Photo captured. Sending to body analysis API...';
    });

    await _analyzeCapturedDataUrl(capture.photoDataUrl);
  }

  Future<String?> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || kIsWeb) {
      return null;
    }

    try {
      final file = await controller.takePicture();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showResult() async {
    if (!_captureAllowed) {
      setState(
        () => _status =
            'Stand 2-3 metres from the camera. Make sure your full body, including your head and feet, is visible.',
      );
      return;
    }
    await _stopScan();

    try {
      final photoPath = await _capturePhoto();
      if (photoPath == null) {
        setState(() {
          _measurementState = HeightWeightMeasurementState.failed;
          _status = 'Could not capture a photo. Please try again.';
        });
        return;
      }

      setState(() {
        _measurementState = HeightWeightMeasurementState.validatingImage;
        _status = 'Photo captured. Sending to body analysis API...';
      });

      final bytes = await File(photoPath).readAsBytes();
      await _analyzeCapturedJpegBytes(bytes, photoPath: photoPath);
    } catch (error) {
      setState(() {
        _measurementState = HeightWeightMeasurementState.failed;
        _status = error.toString();
      });
    }
  }

  Future<void> _analyzeCapturedDataUrl(String dataUrl) async {
    try {
      final analysis = await BodyAnalysisApi.analyzeDataUrl(dataUrl);
      if (!mounted) return;
      _applyBodyAnalysis(analysis, photoDataUrl: dataUrl);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isWebScanning = false;
        _measurementState = HeightWeightMeasurementState.failed;
        _status = 'Body analysis API failed: $error';
      });
    }
  }

  Future<void> _analyzeCapturedJpegBytes(
    Uint8List bytes, {
    String? photoPath,
  }) async {
    try {
      final analysis = await BodyAnalysisApi.analyzeJpegBytes(bytes);
      if (!mounted) return;
      _applyBodyAnalysis(analysis, photoPath: photoPath);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _measurementState = HeightWeightMeasurementState.failed;
        _status = 'Body analysis API failed: $error';
      });
    }
  }

  void _applyBodyAnalysis(
    BodyAnalysisResult analysis, {
    String? photoPath,
    String? photoDataUrl,
  }) {
    final canUseEstimate = analysis.captureAccepted && analysis.hasEstimate;
    setState(() {
      _isWebScanning = false;
      _measurementState = canUseEstimate
          ? HeightWeightMeasurementState.completed
          : HeightWeightMeasurementState.failed;
      _status = analysis.displayMessage;
    });

    if (!canUseEstimate) {
      return;
    }

    final result = ScanResult(
      heightCm: analysis.heightCm!,
      weightKg: analysis.weightKg!,
      confidence: 'AI visual estimate',
      validFrames: 1,
      heightSource: 'AI visual estimate from photo',
      weightSource: 'AI visual estimate from photo',
      photoPath: photoPath,
      photoDataUrl: photoDataUrl,
    );

    final onResult = widget.onResult;
    if (onResult != null) {
      onResult(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isRunning || _isBusy) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < 140) {
      return;
    }
    _lastProcessed = now;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      final poseDetector = _poseDetector;
      if (inputImage == null || inputImage.metadata == null) {
        _setStatus('Unsupported camera image format');
        return;
      }
      if (poseDetector == null) {
        _setStatus('Pose detector is not available on this platform');
        return;
      }

      final brightness = _estimateBrightness(image);
      final poses = await poseDetector.processImage(inputImage);
      var observation = PoseGeometry.process(poses, inputImage.metadata!.size);
      var status = observation.reason;
      var valid = observation.valid;

      if (brightness < 35) {
        valid = false;
        status = 'Insufficient lighting';
      }

      if (valid && _previousHeightPx != null) {
        final movement =
            (observation.bodyHeightPixels - _previousHeightPx!).abs() /
                _previousHeightPx!;
        if (movement > 0.045) {
          valid = false;
          status = 'Hold still';
        }
      }

      if (valid) {
        _previousHeightPx = observation.bodyHeightPixels;
        final now = DateTime.now();
        _stableBodySince ??= now;
        final stableDuration = now.difference(_stableBodySince!);
        _captureAllowed =
            stableDuration >= MeasurementValidator.requiredStableDuration;
        status = _captureAllowed ? 'Full body detected' : 'Hold still';
        _measurementState = _captureAllowed
            ? HeightWeightMeasurementState.fullBodyDetected
            : HeightWeightMeasurementState.holdStill;
      } else {
        _stableBodySince = null;
        _captureAllowed = false;
        _measurementState = HeightWeightMeasurementState.partialBodyDetected;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
      });
    } catch (error) {
      _setStatus('Camera processing error: $error');
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (kIsWeb) {
      return null;
    }

    final controller = _controller;
    final camera = _activeCamera;
    if (controller == null || camera == null) {
      return null;
    }

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (!kIsWeb && Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (!kIsWeb && Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) {
        return null;
      }
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) {
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (!kIsWeb && Platform.isAndroid && format != InputImageFormat.nv21) ||
        (!kIsWeb && Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) {
      return null;
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  double _estimateBrightness(CameraImage image) {
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) {
      return 255;
    }

    if (!kIsWeb &&
        Platform.isIOS &&
        image.format.group == ImageFormatGroup.bgra8888) {
      var total = 0;
      var count = 0;
      for (var index = 0; index + 2 < bytes.length; index += 16) {
        total += (bytes[index] + bytes[index + 1] + bytes[index + 2]) ~/ 3;
        count++;
      }
      return count == 0 ? 255 : total / count;
    }

    final yLength = math.min(image.width * image.height, bytes.length);
    return _average(bytes, yLength);
  }

  double _average(Uint8List bytes, int length) {
    if (length <= 0) {
      return 255;
    }
    var total = 0;
    final step = math.max(1, length ~/ 2500);
    var count = 0;
    for (var index = 0; index < length; index += step) {
      total += bytes[index];
      count++;
    }
    return total / count;
  }

  void _setStatus(String status) {
    if (!mounted) {
      return;
    }
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final canCapture = _captureAllowed &&
        _measurementState == HeightWeightMeasurementState.fullBodyDetected;

    final body =
        _isInitializing || controller == null || !controller.value.isInitialized
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  _cameraPreview(controller),
                  SafeArea(
                    top: !widget.embedded,
                    child: Column(
                      children: [
                        _instructions(),
                        const Spacer(),
                        kIsWeb ? _webBottomPanel() : _bottomPanel(canCapture),
                      ],
                    ),
                  ),
                ],
              );

    if (widget.embedded) {
      return ColoredBox(color: Colors.black, child: body);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(ScannerConfig.appTitle),
        backgroundColor: Colors.black.withValues(alpha: .36),
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }

  Widget _instructions() {
    return Container(
      margin: widget.embedded
          ? const EdgeInsets.fromLTRB(12, 12, 12, 8)
          : const EdgeInsets.fromLTRB(16, 66, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        _bodyInstruction,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _cameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (previewSize == null)
          CameraPreview(controller)
        else
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(controller),
            ),
          ),
      ],
    );
  }

  Widget _bottomPanel(bool canShowResult) {
    return _shutterArea(
      status: _status,
      onPressed: () => _handleNativeShutter(canShowResult),
      busy: false,
    );
  }

  Widget _webBottomPanel() {
    return _shutterArea(
      status: _isWebScanning ? 'Taking photo...' : _status,
      onPressed: _isWebScanning ? null : _takeWebPhotoScan,
      busy: _isWebScanning,
    );
  }

  Widget _shutterArea({
    required String status,
    required VoidCallback? onPressed,
    required bool busy,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .58),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _shutterButton(onPressed: onPressed, busy: busy),
        ],
      ),
    );
  }

  Widget _shutterButton({
    required VoidCallback? onPressed,
    required bool busy,
  }) {
    final enabled = onPressed != null;
    final borderColor = enabled ? Colors.white : Colors.white54;
    final fillColor = enabled ? Colors.white : Colors.white38;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Take photo',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : .56,
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 4),
              color: Colors.black.withValues(alpha: .18),
            ),
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: fillColor,
                      ),
                    )
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fillColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleNativeShutter(bool canShowResult) async {
    if (!_isRunning) {
      await _startScan();
      return;
    }
    if (canShowResult) {
      await _showResult();
      return;
    }
    setState(() => _status = _bodyInstruction);
  }
}
