import 'package:flutter_test/flutter_test.dart';
import 'package:feature_d/feature_d.dart';

void main() {
  group('FeatureD', () {
    test('format returns formatted text', () {
      final featureD = FeatureD();
      expect(featureD.format('test'), 'Formatted: test');
    });

    test('isEven returns true for even numbers', () {
      final featureD = FeatureD();
      expect(featureD.isEven(4), true);
      expect(featureD.isEven(5), false);
    });
  });
}
