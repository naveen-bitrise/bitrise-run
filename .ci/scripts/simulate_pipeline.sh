#!/bin/bash
# Simulates the entire Bitrise pipeline locally
set -e

THRESHOLD=${1:-4}

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Flutter Sharding Pipeline Simulation                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Stage 1: Analyze and Calculate Shards
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STAGE 1: Analyzing Changed Packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Bootstrap packages first
echo "📦 Bootstrapping packages..."
if ! command -v melos &> /dev/null; then
  echo "Installing melos..."
  flutter pub global activate melos
fi
melos bootstrap

# Run shard calculator
echo ""
echo "🔍 Calculating shards..."
SHARD_OUTPUT=$(dart .ci/scripts/shard_calculator.dart auto $THRESHOLD)

echo "$SHARD_OUTPUT"
echo ""

# Parse output
RUN_MODE=$(echo "$SHARD_OUTPUT" | grep "^RUN_MODE=" | cut -d= -f2)
SHARD_COUNT=$(echo "$SHARD_OUTPUT" | grep "^SHARD_COUNT=" | cut -d= -f2 || echo "0")
ALL_PACKAGES=$(echo "$SHARD_OUTPUT" | grep "^ALL_PACKAGES=" | cut -d= -f2 || echo "")
MODIFIED_PACKAGES=$(echo "$SHARD_OUTPUT" | grep "^MODIFIED_PACKAGES=" | cut -d= -f2 || echo "")

# Extract shard assignments
declare -A SHARD_PACKAGES
if [ "$RUN_MODE" = "sharded" ]; then
  for i in $(seq 0 $((SHARD_COUNT-1))); do
    pkg_list=$(echo "$SHARD_OUTPUT" | grep "^SHARD_${i}_PACKAGES=" | cut -d= -f2)
    SHARD_PACKAGES[$i]=$pkg_list
  done
fi

echo "📊 Analysis Results:"
echo "  Run Mode: $RUN_MODE"
echo "  Modified Packages: $MODIFIED_PACKAGES"

if [ "$RUN_MODE" = "skip" ]; then
  echo ""
  echo "✅ No packages to test. Exiting."
  exit 0
fi

# Stage 2: Run Tests
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$RUN_MODE" = "shardless" ]; then
  echo "STAGE 2: Running Tests (Shardless Mode)"
else
  echo "STAGE 2: Running Tests (Sharded Mode - $SHARD_COUNT shards)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

START_TIME=$(date +%s)

if [ "$RUN_MODE" = "shardless" ]; then
  echo "📝 Testing all packages sequentially..."
  echo "  Packages: $ALL_PACKAGES"
  echo ""

  bash .ci/scripts/test_local.sh shardless "$ALL_PACKAGES"

elif [ "$RUN_MODE" = "sharded" ]; then
  echo "📝 Testing packages in parallel shards..."
  echo ""

  # Show shard distribution
  for i in $(seq 0 $((SHARD_COUNT-1))); do
    echo "  Shard $i: ${SHARD_PACKAGES[$i]}"
  done
  echo ""

  # Run shards in parallel (background jobs)
  PIDS=()
  for i in $(seq 0 $((SHARD_COUNT-1))); do
    packages="${SHARD_PACKAGES[$i]}"
    if [ -n "$packages" ]; then
      echo "🚀 Starting Shard $i..."
      bash .ci/scripts/test_local.sh "shard$i" "$packages" &
      PIDS+=($!)
    fi
  done

  # Wait for all shards to complete
  FAILED=0
  for i in "${!PIDS[@]}"; do
    pid=${PIDS[$i]}
    if wait $pid; then
      echo "✅ Shard $i completed successfully"
    else
      echo "❌ Shard $i failed"
      FAILED=1
    fi
  done

  if [ $FAILED -eq 1 ]; then
    echo ""
    echo "❌ Some shards failed!"
    exit 1
  fi
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PIPELINE SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All tests passed!"
echo "⏱️  Duration: ${DURATION}s"
echo "📊 Mode: $RUN_MODE"
if [ "$RUN_MODE" = "sharded" ]; then
  echo "🔢 Shards: $SHARD_COUNT"
  echo "📈 Potential speedup: ~${SHARD_COUNT}x"
fi
echo "📦 Packages tested: $(echo "$ALL_PACKAGES" | tr ',' ' ' | wc -w | xargs)"
echo ""
echo "Test results saved to: test-results/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
