class FeatureF {
  String reverse(String text) {
    return text.split('').reversed.join('');
  }

  int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
  }
}
