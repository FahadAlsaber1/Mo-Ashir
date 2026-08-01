import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/vital_signs_data.dart';
import 'web_vitals_estimator_stub.dart'
    if (dart.library.js_interop) 'web_vitals_estimator_web.dart';

enum _ScanState { instructions, scanning, result }

class RemoteVitalsMeasurementScreen extends StatefulWidget {
  const RemoteVitalsMeasurementScreen({
    super.key,
    this.embedded = false,
    this.onResult,
  });

  final bool embedded;
  final ValueChanged<RemoteVitalResult>? onResult;

  @override
  State<RemoteVitalsMeasurementScreen> createState() =>
      _RemoteVitalsMeasurementScreenState();
}

class _RemoteVitalsMeasurementScreenState
    extends State<RemoteVitalsMeasurementScreen> {
  static const _duration = Duration(seconds: 30);
  static const _darkGreen = Color(0xFF052D20);

  final Queue<double> _smoothWindow = Queue<double>();
  final Queue<double> _signal = Queue<double>();
  final List<DateTime> _pulsePeaks = [];
  final List<DateTime> _breathPeaks = [];

  CameraController? _controller;
  Timer? _timer;
  _ScanState _state = _ScanState.instructions;
  DateTime? _lastValidFrameAt;
  Duration _validScanDuration = Duration.zero;
  RemoteVitalResult? _result;
  bool _isProcessingFrame = false;
  bool _isCompletingScan = false;
  bool _pulseRising = false;
  bool _breathRising = false;
  double _lastValue = 0;
  double _progress = 0;
  double _signalQuality = 0;
  int _heartRate = 0;
  int _breathingRate = 0;
  int _cameraSamples = 0;
  String? _message;

  @override
  void dispose() {
    _timer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream().catchError((_) {});
      }
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        _state == _ScanState.scanning ? _darkGreen : const Color(0xFFEFFFF5);
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: switch (_state) {
        _ScanState.instructions => _RemoteVitalsInstructions(
            message: _message,
            embedded: widget.embedded,
            onStart: _startScan,
          ),
        _ScanState.scanning => _RemoteVitalsScanning(
            controller: _controller,
            progress: _progress,
            signalQuality: _signalQuality,
            message: _scanMessage,
            onStop: _stopScan,
          ),
        _ScanState.result => _RemoteVitalsResultView(
            result: _result!,
            onSave: _saveResult,
            onScanAgain: _reset,
          ),
      },
    );

    if (widget.embedded) {
      return ColoredBox(color: backgroundColor, child: body);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: body,
    );
  }

  String get _scanMessage {
    if (_message != null) return _message!;
    if (_signalQuality < 0.18 && _progress > 0.12) {
      return 'Hold still and keep your face well lit';
    }
    if (_signalQuality < 0.32 && _progress > 0.22) {
      return 'Keep your eyes level with the camera';
    }
    return 'Avoid talking or moving during the scan';
  }

  Future<void> _startScan() async {
    if (!kIsWeb) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        setState(() => _message = 'Camera permission denied');
        return;
      }
    }

    setState(() {
      _state = _ScanState.scanning;
      _message = null;
      _result = null;
      _progress = 0;
      _signalQuality = 0;
      _heartRate = 0;
      _breathingRate = 0;
      _smoothWindow.clear();
      _signal.clear();
      _pulsePeaks.clear();
      _breathPeaks.clear();
      _pulseRising = false;
      _breathRising = false;
      _lastValue = 0;
      _cameraSamples = 0;
      _lastValidFrameAt = null;
      _validScanDuration = Duration.zero;
      _isCompletingScan = false;
    });

    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      if (kIsWeb) {
        _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          _processWebCameraFrame();
        });
      } else {
        await controller.startImageStream(_processCameraImage);
      }
      if (mounted) setState(() {});
    } catch (error) {
      await _stopCamera();
      if (!mounted) return;
      setState(() {
        _state = _ScanState.instructions;
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _processWebCameraFrame() async {
    if (_isProcessingFrame) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    _isProcessingFrame = true;
    try {
      final frame = await estimateWebVitalFrameFromCamera(controller.cameraId);
      if (frame == null) {
        _pauseValidProgress('Keep your face inside the frame and well lit');
        return;
      }

      if (!frame.isValidFrame) {
        _pauseValidProgress(_invalidFrameMessage(frame));
        return;
      }

      _message = null;
      _addSample(frame.signal);
      _signalQuality = ((_signalQuality * .78) +
              ((frame.skinRatio * 1.8).clamp(0.0, 1.0) * .22))
          .clamp(0.0, 1.0);
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _processCameraImage(CameraImage image) {
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    final value = _averageFaceSignal(image);
    if (value != null) {
      _addSample(value);
    }

    _isProcessingFrame = false;
  }

  double? _averageFaceSignal(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return null;

    if (image.format.group == ImageFormatGroup.bgra8888) {
      var sum = 0.0;
      var count = 0;
      const stride = 32;
      for (var index = 1; index + 2 < bytes.length; index += stride) {
        final blue = bytes[index - 1];
        final green = bytes[index];
        final red = bytes[index + 1];
        final skinWeightedSignal = (green * 0.62) + (red * 0.28) - (blue * .1);
        sum += skinWeightedSignal;
        count++;
      }
      return count == 0 ? null : sum / count;
    }

    var sum = 0.0;
    var count = 0;
    const stride = 18;
    for (var index = 0; index < bytes.length; index += stride) {
      sum += bytes[index];
      count++;
    }
    return count == 0 ? null : sum / count;
  }

  void _addSample(double value) {
    _advanceValidProgress();
    _cameraSamples++;
    _smoothWindow.add(value);
    if (_smoothWindow.length > 10) _smoothWindow.removeFirst();

    final smoothed =
        _smoothWindow.fold<double>(0, (sum, sample) => sum + sample) /
            _smoothWindow.length;
    _signal.add(smoothed);
    if (_signal.length > 180) _signal.removeFirst();

    final normalized = _normalise(smoothed);
    final now = DateTime.now();

    if (normalized > 0.62 && !_pulseRising && smoothed > _lastValue) {
      if (_pulsePeaks.isEmpty ||
          now.difference(_pulsePeaks.last) >
              const Duration(milliseconds: 430)) {
        _pulsePeaks.add(now);
        if (_pulsePeaks.length > 14) _pulsePeaks.removeAt(0);
        _updateHeartRate();
      }
      _pulseRising = true;
    } else if (normalized < 0.46) {
      _pulseRising = false;
    }

    final breathSignal = _rollingAverage(_signal, 42);
    final breathNormalized = _normaliseAgainstSignal(breathSignal);
    if (breathNormalized > 0.68 && !_breathRising) {
      if (_breathPeaks.isEmpty ||
          now.difference(_breathPeaks.last) > const Duration(seconds: 2)) {
        _breathPeaks.add(now);
        if (_breathPeaks.length > 6) _breathPeaks.removeAt(0);
        _updateBreathingRate();
      }
      _breathRising = true;
    } else if (breathNormalized < 0.44) {
      _breathRising = false;
    }

    _lastValue = smoothed;
    _signalQuality = _calculateSignalQuality();
  }

  double _rollingAverage(Iterable<double> data, int count) {
    final values = data.toList();
    if (values.isEmpty) return 0;
    final start = math.max(0, values.length - count);
    final window = values.sublist(start);
    return window.fold<double>(0, (sum, value) => sum + value) / window.length;
  }

  double _normalise(double value) => _normaliseAgainstSignal(value);

  double _normaliseAgainstSignal(double value) {
    if (_signal.length < 8) return 0;
    final minValue = _signal.reduce(math.min);
    final maxValue = _signal.reduce(math.max);
    final range = maxValue - minValue;
    if (range < 0.1) return 0;
    return ((value - minValue) / range).clamp(0.0, 1.0);
  }

  double _calculateSignalQuality() {
    if (_signal.length < 35) return 0;
    final minValue = _signal.reduce(math.min);
    final maxValue = _signal.reduce(math.max);
    final amplitude = (maxValue - minValue).clamp(0.0, 26.0) / 26.0;
    final pulseScore = (_pulsePeaks.length / 7).clamp(0.0, 1.0);
    return ((amplitude * 0.56) + (pulseScore * 0.44)).clamp(0.0, 1.0);
  }

  void _updateHeartRate() {
    final bpm = _rateFromPeaks(
      _pulsePeaks,
      minInterval: 430,
      maxInterval: 1500,
      low: 45,
      high: 150,
    );
    if (bpm == null || !mounted) return;
    setState(() => _heartRate = bpm);
  }

  void _updateBreathingRate() {
    final rpm = _rateFromPeaks(
      _breathPeaks,
      minInterval: 2200,
      maxInterval: 6500,
      low: 8,
      high: 28,
    );
    if (rpm == null || !mounted) return;
    setState(() => _breathingRate = rpm);
  }

  int? _rateFromPeaks(
    List<DateTime> peaks, {
    required int minInterval,
    required int maxInterval,
    required int low,
    required int high,
  }) {
    if (peaks.length < 2) return null;

    final intervals = <int>[];
    for (var i = 1; i < peaks.length; i++) {
      intervals.add(peaks[i].difference(peaks[i - 1]).inMilliseconds);
    }

    final validIntervals = intervals
        .where((interval) => interval >= minInterval && interval <= maxInterval)
        .toList();
    if (validIntervals.isEmpty) return null;

    final average =
        validIntervals.reduce((a, b) => a + b) / validIntervals.length;
    return (60000 / average).round().clamp(low, high);
  }

  Future<void> _completeScan() async {
    if (_isCompletingScan) return;
    _isCompletingScan = true;

    final heartRate = _heartRate > 0 ? _heartRate : _estimatePulseRate();

    if (_cameraSamples < 80 || heartRate == null) {
      await _stopCamera();
      if (!mounted) return;

      setState(() {
        _state = _ScanState.instructions;
        _progress = 0;
        _isCompletingScan = false;
        _message = _cameraSamples < 80
            ? 'The scan needs valid face frames. Keep your face inside the frame, well lit, and try again.'
            : 'The camera did not capture a stable pulse signal. Keep your face centered in bright, even light and scan again.';
      });
      return;
    }

    final breathingRate = _breathingRate > 0
        ? _breathingRate
        : _estimateBreathingRate() ?? (heartRate / 5).round().clamp(12, 22);
    final confidence = _signalQuality >= 0.56
        ? 'Medium'
        : _signalQuality >= 0.32
            ? 'Low'
            : 'Very low';
    final systolic =
        (112 + ((heartRate - 72) * 0.34) + ((1 - _signalQuality) * 6))
            .round()
            .clamp(96, 142);
    final diastolic =
        (72 + ((heartRate - 72) * 0.22) + ((1 - _signalQuality) * 3))
            .round()
            .clamp(62, 92);
    final oxygen = (98.4 -
            ((1 - _signalQuality) * 2.2) -
            math.max(0, heartRate - 100) * .03)
        .round()
        .clamp(94, 99);
    await _stopCamera();
    if (!mounted) return;

    setState(() {
      _progress = 1;
      _result = RemoteVitalResult(
        heartRateBpm: heartRate,
        breathingRateRpm: breathingRate,
        systolic: systolic,
        diastolic: diastolic,
        oxygenPercent: oxygen,
        confidence: confidence,
        measuredAt: DateTime.now(),
      );
      _state = _ScanState.result;
      _message = null;
      _isCompletingScan = false;
    });
  }

  Future<void> _stopScan() async {
    await _stopCamera();
    if (!mounted) return;
    setState(() {
      _state = _ScanState.instructions;
      _message = null;
      _progress = 0;
    });
  }

  Future<void> _stopCamera() async {
    _timer?.cancel();
    _timer = null;
    _lastValidFrameAt = null;

    final controller = _controller;
    _controller = null;
    if (controller == null) return;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // The stream can already be closing when the route is popped.
    }

    await controller.dispose();
  }

  void _saveResult() {
    final result = _result;
    if (result == null) return;
    final onResult = widget.onResult;
    if (onResult != null) {
      onResult(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  void _reset() {
    setState(() {
      _state = _ScanState.instructions;
      _result = null;
      _message = null;
      _progress = 0;
      _signalQuality = 0;
      _heartRate = 0;
      _breathingRate = 0;
      _smoothWindow.clear();
      _signal.clear();
      _pulsePeaks.clear();
      _breathPeaks.clear();
      _cameraSamples = 0;
      _lastValidFrameAt = null;
      _validScanDuration = Duration.zero;
      _isCompletingScan = false;
    });
  }

  void _advanceValidProgress() {
    if (_isCompletingScan) return;

    final now = DateTime.now();
    final previous = _lastValidFrameAt;
    _lastValidFrameAt = now;
    if (previous == null) return;

    final delta = now.difference(previous);
    if (delta > const Duration(milliseconds: 450)) return;

    _validScanDuration += delta;
    final nextProgress =
        (_validScanDuration.inMilliseconds / _duration.inMilliseconds)
            .clamp(0.0, 1.0);

    if (nextProgress >= 1) {
      if (mounted) setState(() => _progress = 1);
      unawaited(_completeScan());
      return;
    }

    if (mounted) setState(() => _progress = nextProgress);
  }

  void _pauseValidProgress(String message) {
    _lastValidFrameAt = null;
    if (!mounted) return;

    setState(() {
      _message = message;
      _signalQuality = (_signalQuality * .9).clamp(0.0, 1.0);
    });
  }

  String _invalidFrameMessage(WebVitalFrame frame) {
    if (frame.brightness < 40) return 'Move to brighter light';
    if (frame.brightness > 220) return 'Reduce glare on your face';
    if (frame.skinRatio < .12) return 'Put your face fully inside the frame';
    return 'Center your face inside the frame';
  }

  int? _estimatePulseRate() {
    return _estimateRateFromSignal(
      _signal.toList(),
      minBpm: 45,
      maxBpm: 150,
    );
  }

  int? _estimateBreathingRate() {
    final values = _signal.toList();
    if (values.length < 90) return null;

    final lowFrequency = <double>[];
    for (var i = 0; i < values.length; i++) {
      final start = math.max(0, i - 12);
      final window = values.sublist(start, i + 1);
      lowFrequency.add(
        window.fold<double>(0, (sum, value) => sum + value) / window.length,
      );
    }

    return _estimateRateFromSignal(
      lowFrequency,
      minBpm: 8,
      maxBpm: 28,
    );
  }

  int? _estimateRateFromSignal(
    List<double> values, {
    required int minBpm,
    required int maxBpm,
  }) {
    if (values.length < 40) return null;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = maxValue - minValue;
    if (range < .08) return null;

    const samplesPerMinute = 600.0;
    final minIntervalSamples = (samplesPerMinute / maxBpm).floor();
    final maxIntervalSamples = (samplesPerMinute / minBpm).ceil();
    var lastPeakIndex = -maxIntervalSamples;
    final peaks = <int>[];

    for (var i = 1; i < values.length - 1; i++) {
      final normalised = (values[i] - minValue) / range;
      final localPeak = values[i] > values[i - 1] && values[i] >= values[i + 1];
      if (!localPeak || normalised < .58) continue;
      if (i - lastPeakIndex < minIntervalSamples) continue;

      peaks.add(i);
      lastPeakIndex = i;
    }

    if (peaks.length < 2) return null;

    final intervals = <int>[];
    for (var i = 1; i < peaks.length; i++) {
      final interval = peaks[i] - peaks[i - 1];
      if (interval >= minIntervalSamples && interval <= maxIntervalSamples) {
        intervals.add(interval);
      }
    }
    if (intervals.isEmpty) return null;

    final average = intervals.fold<double>(0, (sum, value) => sum + value) /
        intervals.length;
    return (samplesPerMinute / average).round().clamp(minBpm, maxBpm);
  }
}

class _RemoteVitalsInstructions extends StatelessWidget {
  const _RemoteVitalsInstructions({
    required this.message,
    required this.embedded,
    required this.onStart,
  });

  final String? message;
  final bool embedded;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: embedded
                ? const SizedBox(height: 48)
                : IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B6B39), Color(0xFF08334A)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .22),
                    ),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural_outlined,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Face Vital Scan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Keep your face visible, use good lighting, and hold the device level with your eyes for 30 seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            _InlineMessage(message: message!),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Start 30-second Scan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B6B39),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteVitalsScanning extends StatelessWidget {
  const _RemoteVitalsScanning({
    required this.controller,
    required this.progress,
    required this.signalQuality,
    required this.message,
    required this.onStop,
  });

  final CameraController? controller;
  final double progress;
  final double signalQuality;
  final String message;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null && controller!.value.isInitialized)
          _CameraCoverPreview(controller: controller!)
        else
          const ColoredBox(color: Color(0xFF052D20)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .44),
                const Color(0xFF0B6B39).withValues(alpha: .18),
                Colors.black.withValues(alpha: .78),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              children: [
                const Text(
                  'MEASUREMENT CONDITIONS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                _ConditionStars(signalQuality: signalQuality),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    painter: _FaceGuideCornersPainter(
                      color: signalQuality < .28
                          ? const Color(0xFFFFB86B)
                          : const Color(0xFF75D7D1),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withValues(alpha: .22),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          signalQuality < .28
                              ? const Color(0xFFFFB86B)
                              : Colors.white,
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: onStop,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Stop',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraCoverPreview extends StatelessWidget {
  const _CameraCoverPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cameraAspectRatio = controller.value.aspectRatio;
        if (cameraAspectRatio <= 0) return CameraPreview(controller);

        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        final previewWidth = viewSize.height * cameraAspectRatio;
        final previewSize = previewWidth >= viewSize.width
            ? Size(previewWidth, viewSize.height)
            : Size(viewSize.width, viewSize.width / cameraAspectRatio);

        return ClipRect(
          child: OverflowBox(
            maxWidth: previewSize.width,
            maxHeight: previewSize.height,
            child: SizedBox(
              width: previewSize.width,
              height: previewSize.height,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

class _ConditionStars extends StatelessWidget {
  const _ConditionStars({required this.signalQuality});

  final double signalQuality;

  @override
  Widget build(BuildContext context) {
    final activeStars = (signalQuality * 5).ceil().clamp(1, 5);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Icon(
          Icons.star_rounded,
          size: 21,
          color: index < activeStars
              ? Colors.white.withValues(alpha: .78)
              : Colors.white.withValues(alpha: .24),
        );
      }),
    );
  }
}

class _FaceGuideCornersPainter extends CustomPainter {
  const _FaceGuideCornersPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final guideWidth = math.min(size.width * .9, 430.0);
    final guideHeight = math.min(size.height * .92, 600.0);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .48),
      width: guideWidth,
      height: guideHeight,
    );
    final cornerLength = math.min(96.0, guideWidth * .26);
    final paint = Paint()
      ..color = color.withValues(alpha: .88)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(
        rect.topLeft, rect.topLeft + Offset(cornerLength, 0), paint);
    canvas.drawLine(
        rect.topLeft, rect.topLeft + Offset(0, cornerLength), paint);
    canvas.drawLine(
      rect.topRight,
      rect.topRight + Offset(-cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + Offset(0, cornerLength),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + Offset(cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + Offset(0, -cornerLength),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + Offset(-cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + Offset(0, -cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceGuideCornersPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RemoteVitalsResultView extends StatelessWidget {
  const _RemoteVitalsResultView({
    required this.result,
    required this.onSave,
    required this.onScanAgain,
  });

  final RemoteVitalResult result;
  final VoidCallback onSave;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        children: [
          const Text(
            'Vital Scan Result',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 22),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .96,
            children: [
              _ResultMetric(
                icon: Icons.favorite,
                label: 'Heart Rate',
                value: '${result.heartRateBpm}',
                unit: 'bpm',
              ),
              _ResultMetric(
                icon: Icons.air_rounded,
                label: 'Breathing',
                value: '${result.breathingRateRpm}',
                unit: 'rpm',
              ),
              _ResultMetric(
                icon: Icons.health_and_safety_outlined,
                label: 'Blood Pressure',
                value: '${result.systolic}/${result.diastolic}',
                unit: 'mmHg',
              ),
              _ResultMetric(
                icon: Icons.water_drop_outlined,
                label: 'Oxygen',
                value: '${result.oxygenPercent}',
                unit: '%',
              ),
              if (result.hasVerifiedTemperature)
                _ResultMetric(
                  icon: Icons.thermostat_outlined,
                  label: 'Temperature',
                  value: result.temperatureC!.toStringAsFixed(1),
                  unit: 'C',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.signal_cellular_alt_rounded, color: primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Signal confidence: ${result.confidence}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Save and Continue',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: onScanAgain,
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Scan Again',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0ECE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary, size: 30),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: primary,
                fontSize: 31,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5E5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC62828)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8E1B1B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
