import 'package:flutter_test/flutter_test.dart';
import 'package:feature_e/feature_e.dart';

void main() {
  group('FeatureE', () {
    test('wrap returns wrapped formatted text', () {
      final featureE = FeatureE();
      expect(featureE.wrap('hello'), '[ Formatted: hello ]');
    });

    test('filterEven returns only even numbers', () {
      final featureE = FeatureE();
      expect(featureE.filterEven([1, 2, 3, 4, 5, 6]), [2, 4, 6]);
    });
  });
}
