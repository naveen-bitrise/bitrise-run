import 'package:feature_a/feature_a.dart';

class FeatureB {
  final FeatureA _featureA = FeatureA();

  String process(String name) {
    return 'Feature B processing: ${_featureA.greet(name)}';
  }

  int multiply(int a, int b) {
    return a * b;
  }
}
