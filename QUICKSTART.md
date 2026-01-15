# Quick Start Guide: Flutter Sharding in Bitrise

## 🚀 Getting Started in 5 Minutes

### 1. Prerequisites
```bash
# Install Flutter
flutter --version

# Install Dart
dart --version
```

### 2. Setup Project
```bash
# Navigate to project
cd /path/to/flutter-sharding-demo

# Get dependencies
flutter pub get

# Install melos
flutter pub global activate melos

# Bootstrap all packages
melos bootstrap
```

### 3. Run Local Tests

#### Test Everything
```bash
# Run all package tests
melos run test
```

#### Test Specific Package
```bash
cd packages/feature_a
flutter test
```

#### Simulate Bitrise Pipeline Locally
```bash
# Run the full pipeline simulation
bash .ci/scripts/simulate_pipeline.sh

# Or with custom threshold
bash .ci/scripts/simulate_pipeline.sh 2
```

### 4. Test Shard Calculator

#### Analyze Changes
```bash
# Auto-detect from git diff
dart .ci/scripts/shard_calculator.dart auto 4

# With specific files
dart .ci/scripts/shard_calculator.dart auto 4 '["packages/feature_a/lib/main.dart"]'
```

#### Create Manual Shards
```bash
# Create 2 shards from 4 packages
dart .ci/scripts/shard_calculator.dart shard "feature_a,feature_b,feature_c,feature_d" 2
```

## 📝 Make Some Changes to Test

### Modify a Package (triggers sharding)
```bash
# Make a change to trigger detection
echo "// Test change" >> packages/feature_a/lib/feature_a.dart

# Check what will be tested
dart .ci/scripts/shard_calculator.dart auto 4
```

### Expected Output
```
RUN_MODE=sharded
SHARD_0_PACKAGES=feature_b,feature_c
SHARD_1_PACKAGES=feature_a
SHARD_COUNT=2
MODIFIED_PACKAGES=feature_a
```

## 🎯 Understanding the Output

### Shardless Mode
```bash
RUN_MODE=shardless
ALL_PACKAGES=feature_a,feature_b
MODIFIED_PACKAGES=feature_a
```
**Meaning**: Only 2 packages affected, run sequentially

### Sharded Mode
```bash
RUN_MODE=sharded
SHARD_0_PACKAGES=feature_a,feature_c
SHARD_1_PACKAGES=feature_b,feature_d
SHARD_COUNT=2
MODIFIED_PACKAGES=feature_a,feature_d
```
**Meaning**: 4+ packages affected, split into 2 parallel shards

## 🔧 Configure Bitrise

### 1. Upload bitrise-sharding.yml
```bash
# Copy to your Bitrise project
cp bitrise-sharding.yml bitrise.yml
git add bitrise.yml
git commit -m "Add sharding configuration"
git push
```

### 2. Configure in Bitrise Dashboard
1. Go to your app on bitrise.io
2. Click "Workflows" → "Pipelines"
3. The pipeline `flutter_test_pipeline` should appear
4. Set it as default for PRs

### 3. Test in Bitrise
1. Create a PR with changes to a package
2. Watch the pipeline run
3. Check if sharding was triggered in logs

## 📊 Verify Sharding Works

### Small Change (Shardless)
```bash
# Modify one file
echo "// change" >> packages/feature_a/lib/feature_a.dart

# Push to trigger CI
git add . && git commit -m "Small change" && git push

# Expected: Runs in shardless mode
```

### Large Change (Sharded)
```bash
# Modify multiple packages
echo "// change" >> packages/feature_a/lib/feature_a.dart
echo "// change" >> packages/feature_d/lib/feature_d.dart
echo "// change" >> packages/feature_f/lib/feature_f.dart

# Push to trigger CI
git add . && git commit -m "Large change" && git push

# Expected: Runs in sharded mode with parallel execution
```

## 🐛 Common Issues

### Issue: "melos not found"
```bash
# Solution
flutter pub global activate melos
export PATH="$PATH:$HOME/.pub-cache/bin"
```

### Issue: "No packages detected"
```bash
# Solution: Check git status
git status

# Make sure you have uncommitted changes
git add packages/feature_a/lib/feature_a.dart
```

### Issue: Tests fail locally but not in CI
```bash
# Solution: Clean and rebuild
flutter clean
melos clean
melos bootstrap
flutter test
```

## 📈 Performance Tips

### 1. Adjust Threshold
For more aggressive sharding:
```yaml
# In bitrise-sharding.yml
app:
  envs:
  - SHARD_THRESHOLD: "2"  # Shard if >2 packages
```

### 2. More Parallelism
```yaml
stages:
  stage_test_sharded:
    parallelism: 5  # Run 5 shards in parallel
```

### 3. Cache Flutter SDK
```yaml
# Add to workflows
- cache-pull@2: {}
# ... your steps ...
- cache-push@2:
    inputs:
    - cache_paths: |-
        ~/.pub-cache
        .dart_tool
```

## 🎓 Next Steps

1. **Read Full Documentation**: See [README-SHARDING.md](README-SHARDING.md)
2. **Customize Thresholds**: Tune for your project size
3. **Add More Packages**: Scale to real monorepo
4. **Integration Tests**: Adapt for widget/integration tests
5. **Performance Metrics**: Track build times

## 💡 Pro Tips

✅ **DO**:
- Keep packages small and focused
- Use melos for monorepo management
- Monitor shard balance in CI logs
- Cache dependencies aggressively

❌ **DON'T**:
- Create too many shards (overhead!)
- Put slow tests with fast tests in same shard
- Forget to update threshold as repo grows
- Skip local testing before pushing

## 🤝 Need Help?

- Check logs: Look for "Shard Configuration" section
- Test locally: Use `simulate_pipeline.sh`
- Read docs: See README-SHARDING.md
- Check package dependencies: Review pubspec.yaml files

Happy sharding! 🎉
