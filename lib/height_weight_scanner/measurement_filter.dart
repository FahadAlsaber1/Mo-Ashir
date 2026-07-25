import 'dart:math' as math;

class RobustResult {
  const RobustResult({
    required this.value,
    required this.relativeVariation,
    required this.count,
  });

  final double value;
  final double relativeVariation;
  final int count;
}

List<double> iqrFilter(Iterable<double> values) {
  final data = values.where((value) => value.isFinite).toList()..sort();
  if (data.length < 4) {
    return data;
  }

  final q1 = _percentile(data, 25);
  final q3 = _percentile(data, 75);
  final spread = q3 - q1;
  if (spread <= 1e-9) {
    return data;
  }

  final low = q1 - 1.5 * spread;
  final high = q3 + 1.5 * spread;
  return data.where((value) => value >= low && value <= high).toList();
}

RobustResult robustMedian(Iterable<double> values) {
  final clean = iqrFilter(values);
  if (clean.isEmpty) {
    throw StateError('No valid measurements are available.');
  }

  final median = _median(clean);
  final deviations = clean.map((value) => (value - median).abs()).toList();
  final mad = _median(deviations);
  return RobustResult(
    value: median,
    relativeVariation: mad / math.max(median.abs(), 1e-6),
    count: clean.length,
  );
}

double _median(List<double> values) {
  final sorted = List<double>.from(values)..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

double _percentile(List<double> sortedValues, double percentile) {
  if (sortedValues.length == 1) {
    return sortedValues.first;
  }
  final position = (percentile / 100) * (sortedValues.length - 1);
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) {
    return sortedValues[lower];
  }
  final weight = position - lower;
  return sortedValues[lower] * (1 - weight) + sortedValues[upper] * weight;
}
