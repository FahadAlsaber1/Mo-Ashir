import 'package:flutter_test/flutter_test.dart';
import 'package:moashir/services/thermal_camera.dart';

void main() {
  test('thermal camera requests a two-second reading', () {
    expect(ThermalCamera.readingSeconds, 2);
  });
}
