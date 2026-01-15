import 'package:flutter_test/flutter_test.dart';
import 'package:feature_b/feature_b.dart';

void main() {
  group('FeatureB', () {
    test('process returns correct message', () {
      final featureB = FeatureB();
      expect(featureB.process('User'), 'Feature B processing: Hello from Feature A, User!');
    });

    test('multiply returns product of two numbers', () {
      final featureB = FeatureB();
      expect(featureB.multiply(3, 4), 12);
    });
  });
}
