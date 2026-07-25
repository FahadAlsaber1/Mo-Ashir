import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/vital_signs_data.dart';

enum _MeasurementState { instructions, measuring, result }

class HeartRateMeasurementScreen extends StatefulWidget {
  const HeartRateMeasurementScreen({super.key});

  @override
  State<HeartRateMeasurementScreen> createState() =>
      _HeartRateMeasurementScreenState();
}

class _HeartRateMeasurementScreenState
    extends State<HeartRateMeasurementScreen> {
  static const _duration = Duration(seconds: 25);
  static const _darkGreen = Color(0xFF042C1B);

  final Queue<double> _samples = Queue<double>();
  final Queue<double> _recentSignal = Queue<double>();
  final List<DateTime> _peaks = [];

  CameraController? _controller;
  Timer? _timer;
  _MeasurementState _state = _MeasurementState.instructions;
  DateTime? _startedAt;
  int _bpm = 0;
  int _resultBpm = 0;
  int _cameraSamples = 0;
  double _progress = 0;
  double _signalQuality = 0;
  String? _message;
  bool _isProcessingFrame = false;
  bool _rising = false;
  double _lastValue = 0;

  @override
  void dispose() {
    _timer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream().catchError((_) {});
      }
      controller.setFlashMode(FlashMode.off).catchError((_) {});
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _state == _MeasurementState.measuring
          ? _darkGreen
          : const Color(0xFFEFFFF5),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: switch (_state) {
          _MeasurementState.instructions => _InstructionView(
              message: _message,
              onStart: _startMeasurement,
            ),
          _MeasurementState.measuring => _MeasuringView(
              controller: _controller,
              bpm: _bpm,
              progress: _progress,
              signalQuality: _signalQuality,
              message: _signalMessage,
              signal: _recentSignal.toList(),
              onStop: _stopMeasurement,
            ),
          _MeasurementState.result => _ResultView(
              bpm: _resultBpm,
              onSave: _saveResult,
              onMeasureAgain: _resetToInstructions,
            ),
        },
      ),
    );
  }

  String get _signalMessage {
    if (_message != null) return _message!;
    if (_signalQuality < 0.18 && _progress > 0.08) {
      return 'Cover the camera and flash completely';
    }
    if (_signalQuality < 0.28 && _progress > 0.16) {
      return 'Adjust your finger position';
    }
    return 'Make sure you are still covering the camera & flash';
  }

  Future<void> _startMeasurement() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      setState(() => _message = 'Camera permission denied');
      return;
    }

    setState(() {
      _message = null;
      _progress = 0;
      _bpm = 0;
      _signalQuality = 0;
      _samples.clear();
      _recentSignal.clear();
      _peaks.clear();
      _cameraSamples = 0;
      _state = _MeasurementState.measuring;
    });

    try {
      final cameras = await availableCameras();
      CameraDescription? camera;
      for (final item in cameras) {
        if (item.lensDirection == CameraLensDirection.back) {
          camera = item;
          break;
        }
      }

      if (camera == null) {
        throw Exception('No rear camera found');
      }

      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      _controller = controller;

      try {
        await controller.setFlashMode(FlashMode.torch);
      } on CameraException {
        setState(() => _message = 'Flash not available');
      }

      await controller.startImageStream(_processCameraImage);
      _startedAt = DateTime.now();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _updateProgress();
      });

      if (mounted) setState(() {});
    } catch (error) {
      await _stopCamera();
      if (!mounted) return;
      setState(() {
        _state = _MeasurementState.instructions;
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _processCameraImage(CameraImage image) {
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    final value = _averageSignal(image);
    if (value != null) {
      _addSample(value);
    }

    _isProcessingFrame = false;
  }

  double? _averageSignal(CameraImage image) {
    if (image.planes.isEmpty) return null;

    if (image.format.group == ImageFormatGroup.bgra8888) {
      final bytes = image.planes.first.bytes;
      if (bytes.length < 4) return null;

      var sum = 0.0;
      var count = 0;
      const stride = 24;
      for (var i = 2; i < bytes.length; i += stride) {
        sum += bytes[i];
        count++;
      }
      return count == 0 ? null : sum / count;
    }

    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return null;

    var sum = 0.0;
    var count = 0;
    const stride = 12;
    for (var i = 0; i < bytes.length; i += stride) {
      sum += bytes[i];
      count++;
    }
    return count == 0 ? null : sum / count;
  }

  void _addSample(double value) {
    _cameraSamples++;
    _samples.add(value);
    if (_samples.length > 16) _samples.removeFirst();

    final smoothed = _samples.fold<double>(0, (sum, sample) => sum + sample) /
        _samples.length;

    _recentSignal.add(smoothed);
    if (_recentSignal.length > 60) _recentSignal.removeFirst();

    final normalized = _normalise(smoothed);
    final now = DateTime.now();

    if (normalized > 0.62 && !_rising && smoothed > _lastValue) {
      if (_peaks.isEmpty ||
          now.difference(_peaks.last) > const Duration(milliseconds: 420)) {
        _peaks.add(now);
        if (_peaks.length > 8) _peaks.removeAt(0);
        _updateBpmFromPeaks();
      }
      _rising = true;
    } else if (normalized < 0.45) {
      _rising = false;
    }

    _lastValue = smoothed;
    _signalQuality = _calculateSignalQuality();
  }

  double _normalise(double value) {
    if (_recentSignal.length < 4) return 0;

    final minValue = _recentSignal.reduce(math.min);
    final maxValue = _recentSignal.reduce(math.max);
    final range = maxValue - minValue;
    if (range < 0.1) return 0;

    return ((value - minValue) / range).clamp(0.0, 1.0);
  }

  double _calculateSignalQuality() {
    if (_recentSignal.length < 20) return 0;

    final minValue = _recentSignal.reduce(math.min);
    final maxValue = _recentSignal.reduce(math.max);
    final amplitude = (maxValue - minValue).clamp(0.0, 40.0) / 40.0;
    final peakScore = (_peaks.length / 5).clamp(0.0, 1.0);

    return ((amplitude * 0.65) + (peakScore * 0.35)).clamp(0.0, 1.0);
  }

  void _updateBpmFromPeaks() {
    if (_peaks.length < 2) return;

    final intervals = <int>[];
    for (var i = 1; i < _peaks.length; i++) {
      intervals.add(_peaks[i].difference(_peaks[i - 1]).inMilliseconds);
    }

    final validIntervals = intervals
        .where((interval) => interval >= 420 && interval <= 1500)
        .toList();
    if (validIntervals.isEmpty) return;

    final average =
        validIntervals.reduce((a, b) => a + b) / validIntervals.length;
    final bpm = (60000 / average).round().clamp(45, 150);

    if (mounted) setState(() => _bpm = bpm);
  }

  void _updateProgress() {
    final startedAt = _startedAt;
    if (startedAt == null) return;

    final elapsed = DateTime.now().difference(startedAt);
    final nextProgress =
        (elapsed.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    if (nextProgress >= 1) {
      _completeMeasurement();
      return;
    }

    if (mounted) setState(() => _progress = nextProgress);
  }

  Future<void> _completeMeasurement() async {
    if (_cameraSamples < 80 || _bpm == 0 || _signalQuality < 0.2) {
      await _stopCamera();
      if (!mounted) return;

      setState(() {
        _state = _MeasurementState.instructions;
        _progress = 0;
        _message =
            'The camera did not capture a stable pulse signal. Cover the camera and flash fully, hold still, and measure again.';
      });
      return;
    }

    await _stopCamera();
    if (!mounted) return;

    setState(() {
      _progress = 1;
      _resultBpm = _bpm;
      _state = _MeasurementState.result;
      _message = null;
    });
  }

  Future<void> _stopMeasurement() async {
    await _stopCamera();
    if (!mounted) return;

    setState(() {
      _state = _MeasurementState.instructions;
      _message = null;
      _progress = 0;
    });
  }

  Future<void> _stopCamera() async {
    _timer?.cancel();
    _timer = null;
    _startedAt = null;

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

    try {
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {
      // Some devices expose a camera but no controllable flash.
    }

    await controller.dispose();
  }

  void _saveResult() {
    Navigator.of(context).pop(
      VitalSignResult(bpm: _resultBpm, measuredAt: DateTime.now()),
    );
  }

  void _resetToInstructions() {
    setState(() {
      _state = _MeasurementState.instructions;
      _message = null;
      _progress = 0;
      _bpm = 0;
      _resultBpm = 0;
      _signalQuality = 0;
      _samples.clear();
      _recentSignal.clear();
      _peaks.clear();
      _cameraSamples = 0;
    });
  }
}

class _InstructionView extends StatelessWidget {
  const _InstructionView({
    required this.message,
    required this.onStart,
  });

  final String? message;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 34, 22, 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B6B39), Color(0xFF04351F)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Container(
                  width: 102,
                  height: 102,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Measure Heart Rate',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Place your fingertip gently over the rear camera and flash.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Keep your finger still and wait until the signal becomes stable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _DisclaimerCard(),
          if (message != null) ...[
            const SizedBox(height: 14),
            _InlineMessage(message: message!),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B6B39),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Start Measurement',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Make sure camera and flash are fully covered.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MeasuringView extends StatelessWidget {
  const _MeasuringView({
    required this.controller,
    required this.bpm,
    required this.progress,
    required this.signalQuality,
    required this.message,
    required this.signal,
    required this.onStop,
  });

  final CameraController? controller;
  final int bpm;
  final double progress;
  final double signalQuality;
  final String message;
  final List<double> signal;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null && controller!.value.isInitialized)
          CameraPreview(controller!)
        else
          const ColoredBox(color: Color(0xFF042C1B)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF03180F).withValues(alpha: 0.72),
                const Color(0xFF0B6B39).withValues(alpha: 0.52),
                const Color(0xFF1E0505).withValues(alpha: 0.78),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Column(
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, color: Color(0xFFE54141)),
                      const SizedBox(width: 12),
                      Text(
                        bpm == 0 ? '-- bpm' : '$bpm bpm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _WaveformPainter(signal: signal),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 9,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          signalQuality < 0.25
                              ? const Color(0xFFFFB86B)
                              : Colors.white,
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: onStop,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.65),
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

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.bpm,
    required this.onSave,
    required this.onMeasureAgain,
  });

  final int bpm;
  final VoidCallback onSave;
  final VoidCallback onMeasureAgain;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        children: [
          const Text(
            'Heart Rate Result',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE5E5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFE54141),
                    size: 46,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '$bpm bpm',
                  style: const TextStyle(
                    color: Color(0xFF0B6B39),
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Normal resting range',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Saved to your appointment vital signs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _DisclaimerCard(),
          const SizedBox(height: 28),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B6B39),
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
              onPressed: onMeasureAgain,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0B6B39),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Measure Again',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0A3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF9B6500), size: 21),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This measurement is for prototype and wellness use only. It is not a medical diagnosis.',
              style: TextStyle(
                color: Color(0xFF6E4A00),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
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

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.signal});

  final List<double> signal;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height * 0.5;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = size.height * (i + 1) / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final paint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    if (signal.length < 3) {
      path.moveTo(0, baseline);
      for (var i = 0; i < 12; i++) {
        final x = size.width * i / 11;
        final y = baseline + math.sin(i * 1.7) * 18;
        path.lineTo(x, y);
      }
    } else {
      final minValue = signal.reduce(math.min);
      final maxValue = signal.reduce(math.max);
      final range = math.max(maxValue - minValue, 0.1);

      for (var i = 0; i < signal.length; i++) {
        final x = size.width * i / (signal.length - 1);
        final normalised = (signal[i] - minValue) / range;
        final y = baseline - ((normalised - 0.5) * size.height * 0.76);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.signal != signal;
  }
}
