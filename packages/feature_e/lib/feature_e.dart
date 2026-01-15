import 'package:feature_d/feature_d.dart';

class FeatureE {
  final FeatureD _featureD = FeatureD();

  String wrap(String text) {
    return '[ ${_featureD.format(text)} ]';
  }

  List<int> filterEven(List<int> numbers) {
    return numbers.where(_featureD.isEven).toList();
  }
}
