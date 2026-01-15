import 'package:flutter_test/flutter_test.dart';
import 'package:feature_c/feature_c.dart';

void main() {
  group('FeatureC', () {
    test('transform returns uppercase text', () {
      final featureC = FeatureC();
      expect(featureC.transform('hello'), 'HELLO');
    });

    test('calculate returns doubled sum', () {
      final featureC = FeatureC();
      expect(featureC.calculate(5, 3), 16); // (5+3)*2
    });
  });
}
