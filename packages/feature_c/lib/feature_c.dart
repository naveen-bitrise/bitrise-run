import 'package:feature_a/feature_a.dart';

class FeatureC {
  final FeatureA _featureA = FeatureA();

  String transform(String text) {
    return text.toUpperCase();
  }

  int calculate(int x, int y) {
    return _featureA.add(x, y) * 2;
  }
}
