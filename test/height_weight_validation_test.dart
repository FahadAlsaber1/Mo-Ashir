import 'package:flutter_test/flutter_test.dart';
import 'package:moashir/height_weight_scanner/measurement_validation.dart';

void main() {
  group('body capture validation', () {
    test('face-only image: capture rejected', () {
      final result = MeasurementValidator.validateBodyFrame(
        _body(headVisible: true, shouldersVisible: false, bodyHeightRatio: .18),
      );

      expect(result.captureAllowed, isFalse);
      expect(result.message, 'Stand straight and face the camera');
    });

    test('upper-body-only image: capture rejected', () {
      final result = MeasurementValidator.validateBodyFrame(
        _body(hipsVisible: false, kneesVisible: false, feetVisible: false),
      );

      expect(result.captureAllowed, isFalse);
      expect(result.message, 'Move farther from the camera');
    });

    test('missing feet: capture rejected', () {
      final result = MeasurementValidator.validateBodyFrame(
        _body(feetVisible: false, hasSpaceBelowFeet: false),
      );

      expect(result.captureAllowed, isFalse);
      expect(result.message, 'Make sure your feet are visible');
    });

    test('missing top of head: capture rejected', () {
      final result = MeasurementValidator.validateBodyFrame(
        _body(headVisible: false, hasSpaceAboveHead: false),
      );

      expect(result.captureAllowed, isFalse);
      expect(result.message, 'Make sure the top of your head is visible');
    });

    test('two people in the frame: capture rejected', () {
      final result =
          MeasurementValidator.validateBodyFrame(_body(personCount: 2));

      expect(result.captureAllowed, isFalse);
      expect(result.message, 'Only one person can be in the frame');
    });

    test('full body correctly positioned: capture allowed', () {
      final result = MeasurementValidator.validateBodyFrame(_body());

      expect(result.captureAllowed, isTrue);
      expect(result.message, 'Full body detected');
    });

    test('closer full body position is accepted', () {
      final result = MeasurementValidator.validateBodyFrame(
        _body(bodyHeightRatio: .90),
      );

      expect(result.captureAllowed, isTrue);
      expect(result.message, 'Full body detected');
    });

    test('body that nearly fills the frame still asks user to move farther',
        () {
      final result = MeasurementValidator.validateBodyFrame(
        _body(bodyHeightRatio: .94),
      );

      expect(result.captureAllowed, isFalse);
      expect(result.message, 'Move farther from the camera');
    });
  });

  group('measurement result validation', () {
    test('no known scale: no height result displayed', () {
      final result = MeasurementValidator.validateHeight(
        heightCm: 176,
        source: null,
        knownScaleValid: false,
        completeBodyDetected: true,
        landmarkConfidencePassed: true,
      );

      expect(result.valid, isFalse);
      expect(
          result.message, 'Height cannot be measured from this photo alone.');
    });

    test('no scale connected: no automatic weight displayed', () {
      final result = MeasurementValidator.validateWeight(
        weightKg: null,
        source: null,
      );

      expect(result.valid, isFalse);
      expect(
          result.message, 'A connected scale is required to measure weight.');
    });

    test('invalid height result: measurement rejected', () {
      final result = MeasurementValidator.validateHeight(
        heightCm: 260,
        source: HeightSource.knownScaleCamera,
        knownScaleValid: true,
        completeBodyDetected: true,
        landmarkConfidencePassed: true,
      );

      expect(result.valid, isFalse);
      expect(result.message,
          'Invalid height measurement. Please retake the photo.');
    });

    test('valid known-scale measurement: result displayed with its source', () {
      final result = MeasurementValidator.validateHeight(
        heightCm: 176.2,
        source: HeightSource.knownScaleCamera,
        knownScaleValid: true,
        completeBodyDetected: true,
        landmarkConfidencePassed: true,
      );

      expect(result.valid, isTrue);
    });
  });
}

BodyFrameInput _body({
  int personCount = 1,
  bool headVisible = true,
  bool shouldersVisible = true,
  bool hipsVisible = true,
  bool kneesVisible = true,
  bool feetVisible = true,
  bool completeBodyInsideFrame = true,
  bool hasSpaceAboveHead = true,
  bool hasSpaceBelowFeet = true,
  bool facingCamera = true,
  bool standingUpright = true,
  bool notBlurred = true,
  bool landmarkConfidencePassed = true,
  double bodyHeightRatio = .74,
  Duration stableDuration = const Duration(milliseconds: 1600),
}) {
  return BodyFrameInput(
    personCount: personCount,
    headVisible: headVisible,
    shouldersVisible: shouldersVisible,
    hipsVisible: hipsVisible,
    kneesVisible: kneesVisible,
    feetVisible: feetVisible,
    completeBodyInsideFrame: completeBodyInsideFrame,
    hasSpaceAboveHead: hasSpaceAboveHead,
    hasSpaceBelowFeet: hasSpaceBelowFeet,
    facingCamera: facingCamera,
    standingUpright: standingUpright,
    notBlurred: notBlurred,
    landmarkConfidencePassed: landmarkConfidencePassed,
    bodyHeightRatio: bodyHeightRatio,
    stableDuration: stableDuration,
  );
}
