#!/bin/bash
# Local testing script to simulate Bitrise CI behavior
set -e

MODE=$1
PACKAGES=$2

if [ -z "$MODE" ] || [ -z "$PACKAGES" ]; then
  echo "Usage: $0 <mode> <packages>"
  echo ""
  echo "Modes:"
  echo "  shardless  - Run all packages sequentially"
  echo "  shard0     - Run as shard 0"
  echo "  shard1     - Run as shard 1"
  echo "  shard2     - Run as shard 2"
  echo ""
  echo "Example:"
  echo "  $0 shardless 'feature_a,feature_b,feature_c'"
  echo "  $0 shard0 'feature_a,feature_b'"
  exit 1
fi

echo "========================================="
echo "Local Test Simulation"
echo "Mode: $MODE"
echo "Packages: $PACKAGES"
echo "========================================="

# Ensure melos is installed
if ! command -v melos &> /dev/null; then
  echo "Installing melos..."
  flutter pub global activate melos
fi

# Bootstrap
echo "Bootstrapping packages..."
melos bootstrap

# Convert comma-separated packages to array
IFS=',' read -ra PKG_ARRAY <<< "$PACKAGES"

# Run tests
mkdir -p test-results
FAILED=0

for package in "${PKG_ARRAY[@]}"; do
  echo ""
  echo "========================================="
  echo "Testing: $package"
  echo "========================================="

  cd "packages/$package"

  if flutter test --reporter=json > "../../test-results/${MODE}_${package}_results.json"; then
    echo "✅ $package tests passed"
  else
    echo "❌ $package tests failed"
    FAILED=1
  fi

  cd ../..
done

echo ""
echo "========================================="
echo "Test Results"
echo "========================================="

if [ $FAILED -eq 1 ]; then
  echo "❌ Some tests failed!"
  exit 1
else
  echo "✅ All tests passed!"
fi
