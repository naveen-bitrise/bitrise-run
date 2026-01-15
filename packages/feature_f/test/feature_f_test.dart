import 'package:flutter_test/flutter_test.dart';
import 'package:feature_f/feature_f.dart';

void main() {
  group('FeatureF', () {
    test('reverse returns reversed string', () {
      final featureF = FeatureF();
      expect(featureF.reverse('hello'), 'olleh');
    });

    test('factorial returns correct factorial', () {
      final featureF = FeatureF();
      expect(featureF.factorial(5), 120);
      expect(featureF.factorial(0), 1);
    });
  });
}
