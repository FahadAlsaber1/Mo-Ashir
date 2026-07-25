enum HeightWeightMeasurementState {
  cameraInitializing,
  waitingForPerson,
  partialBodyDetected,
  fullBodyDetected,
  holdStill,
  capturing,
  validatingImage,
  measuringHeight,
  waitingForWeight,
  completed,
  failed,
}

enum BodyValidationCode {
  noPerson,
  multiplePeople,
  missingHead,
  missingShoulders,
  missingHips,
  missingKnees,
  missingFeet,
  bodyOutsideFrame,
  moveFarther,
  moveCloser,
  notFacingCamera,
  notUpright,
  blurred,
  holdStill,
  fullBodyDetected,
}

enum HeightSource { knownScaleCamera, arDepth, referenceMarker }

enum WeightSource { connectedScale, manualEntry }

class BodyFrameInput {
  const BodyFrameInput({
    required this.personCount,
    required this.headVisible,
    required this.shouldersVisible,
    required this.hipsVisible,
    required this.kneesVisible,
    required this.feetVisible,
    required this.completeBodyInsideFrame,
    required this.hasSpaceAboveHead,
    required this.hasSpaceBelowFeet,
    required this.facingCamera,
    required this.standingUpright,
    required this.notBlurred,
    required this.landmarkConfidencePassed,
    required this.bodyHeightRatio,
    required this.stableDuration,
  });

  final int personCount;
  final bool headVisible;
  final bool shouldersVisible;
  final bool hipsVisible;
  final bool kneesVisible;
  final bool feetVisible;
  final bool completeBodyInsideFrame;
  final bool hasSpaceAboveHead;
  final bool hasSpaceBelowFeet;
  final bool facingCamera;
  final bool standingUpright;
  final bool notBlurred;
  final bool landmarkConfidencePassed;
  final double bodyHeightRatio;
  final Duration stableDuration;
}

class BodyValidationResult {
  const BodyValidationResult({
    required this.valid,
    required this.captureAllowed,
    required this.code,
    required this.message,
  });

  final bool valid;
  final bool captureAllowed;
  final BodyValidationCode code;
  final String message;
}

class MeasurementValidationResult {
  const MeasurementValidationResult({
    required this.valid,
    required this.message,
  });

  final bool valid;
  final String message;
}

class MeasurementValidator {
  static const landmarkConfidenceThreshold = 0.70;
  static const minBodyHeightRatio = 0.65;
  static const maxBodyHeightRatio = 0.85;
  static const requiredStableDuration = Duration(milliseconds: 1500);
  static const minAdultHeightCm = 100.0;
  static const maxAdultHeightCm = 230.0;
  static const minWeightKg = 20.0;
  static const maxWeightKg = 300.0;

  static BodyValidationResult validateBodyFrame(BodyFrameInput input) {
    if (input.personCount == 0) {
      return _invalid(BodyValidationCode.noPerson, 'Move closer to the camera');
    }
    if (input.personCount > 1) {
      return _invalid(
        BodyValidationCode.multiplePeople,
        'Only one person can be in the frame',
      );
    }
    if (!input.landmarkConfidencePassed) {
      return _invalid(
        BodyValidationCode.bodyOutsideFrame,
        'Stand 2-3 metres from the camera',
      );
    }
    if (!input.headVisible || !input.hasSpaceAboveHead) {
      return _invalid(
        BodyValidationCode.missingHead,
        'Make sure the top of your head is visible',
      );
    }
    if (!input.shouldersVisible) {
      return _invalid(
        BodyValidationCode.missingShoulders,
        'Stand straight and face the camera',
      );
    }
    if (!input.hipsVisible || !input.kneesVisible) {
      return _invalid(
        BodyValidationCode.bodyOutsideFrame,
        'Move farther from the camera',
      );
    }
    if (!input.feetVisible || !input.hasSpaceBelowFeet) {
      return _invalid(
        BodyValidationCode.missingFeet,
        'Make sure your feet are visible',
      );
    }
    if (!input.completeBodyInsideFrame) {
      return _invalid(
        BodyValidationCode.bodyOutsideFrame,
        'Move farther from the camera',
      );
    }
    if (!input.facingCamera || !input.standingUpright) {
      return _invalid(
        BodyValidationCode.notFacingCamera,
        'Stand straight and face the camera',
      );
    }
    if (!input.notBlurred) {
      return _invalid(BodyValidationCode.blurred, 'Hold still');
    }
    if (input.bodyHeightRatio > maxBodyHeightRatio) {
      return _invalid(
        BodyValidationCode.moveFarther,
        'Move farther from the camera',
      );
    }
    if (input.bodyHeightRatio < minBodyHeightRatio) {
      return _invalid(
        BodyValidationCode.moveCloser,
        'Move closer to the camera',
      );
    }
    if (input.stableDuration < requiredStableDuration) {
      return const BodyValidationResult(
        valid: true,
        captureAllowed: false,
        code: BodyValidationCode.holdStill,
        message: 'Hold still',
      );
    }

    return const BodyValidationResult(
      valid: true,
      captureAllowed: true,
      code: BodyValidationCode.fullBodyDetected,
      message: 'Full body detected',
    );
  }

  static MeasurementValidationResult validateHeight({
    required double? heightCm,
    required HeightSource? source,
    required bool knownScaleValid,
    required bool completeBodyDetected,
    required bool landmarkConfidencePassed,
  }) {
    if (source == null || !knownScaleValid) {
      return const MeasurementValidationResult(
        valid: false,
        message: 'Height cannot be measured from this photo alone.',
      );
    }
    if (!completeBodyDetected || !landmarkConfidencePassed) {
      return const MeasurementValidationResult(
        valid: false,
        message: 'The complete body was not detected. Please retake the photo.',
      );
    }
    if (heightCm == null || !heightCm.isFinite) {
      return const MeasurementValidationResult(
        valid: false,
        message: 'Invalid height measurement. Please retake the photo.',
      );
    }
    if (heightCm < minAdultHeightCm || heightCm > maxAdultHeightCm) {
      return const MeasurementValidationResult(
        valid: false,
        message: 'Invalid height measurement. Please retake the photo.',
      );
    }
    return const MeasurementValidationResult(valid: true, message: 'Valid');
  }

  static MeasurementValidationResult validateWeight({
    required double? weightKg,
    required WeightSource? source,
  }) {
    if (source == null) {
      return const MeasurementValidationResult(
        valid: false,
        message: 'A connected scale is required to measure weight.',
      );
    }
    if (weightKg == null || !weightKg.isFinite || weightKg <= 0) {
      return const MeasurementValidationResult(
        valid: false,
        message: 'Invalid weight measurement.',
      );
    }
    if (weightKg < minWeightKg || weightKg > maxWeightKg) {
      return const MeasurementValidationResult(
        valid: false,
        message: 'Invalid weight measurement.',
      );
    }
    return const MeasurementValidationResult(valid: true, message: 'Valid');
  }

  static BodyValidationResult _invalid(
    BodyValidationCode code,
    String message,
  ) {
    return BodyValidationResult(
      valid: false,
      captureAllowed: false,
      code: code,
      message: message,
    );
  }
}
