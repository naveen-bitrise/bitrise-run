# Flutter Test Sharding for Bitrise CI

This repository demonstrates dynamic test sharding for Flutter monorepo projects using Bitrise CI/CD, inspired by Jenkins Groovy-based sharding implementations.

## 🌟 Features

- **Dynamic Shard Calculation**: Automatically calculates optimal number of shards based on changed packages
- **Intelligent Package Detection**: Detects modified packages and their dependents
- **Configurable Sharding**: Set packages-per-shard ratio via environment variable
- **API-Based Triggering**: Coordinator workflow triggers test pipeline via Bitrise Build Trigger API
- **Parallel Test Execution**: Tests run in parallel across multiple shards
- **JUnit XML Reports**: Automatic test result aggregation in Bitrise Test Reports

## 📋 Branches

### `main` - Fixed Sharding
Fixed number of shards (3) that always run in parallel. Simpler approach, good for consistent workloads.

### `dynamic-shards` - Dynamic Sharding (Recommended)
Dynamically calculates shard count based on package changes. Matches Jenkins Groovy behavior.

## 🚀 Quick Start (Dynamic Sharding)

### Prerequisites

1. Flutter monorepo with packages in `packages/` directory
2. Bitrise account with your app configured
3. Bitrise Personal Access Token (for API triggering)

### Setup

1. **Configure Bitrise Secret**:
   - Go to Bitrise Workflow Editor
   - Navigate to Secrets tab
   - Add secret: `BITRISE_API_TOKEN` = Your Personal Access Token

2. **Configure Environment Variables** (optional):
   ```yaml
   app:
     envs:
     - PACKAGES_PER_SHARD: "2"  # Adjust packages per shard (default: 2)
   ```

3. **Run the Pipeline**:
   - Trigger `shard_calculator` workflow in Bitrise
   - It will analyze changes and trigger `test_pipeline` with calculated shard count

## 🏗️ Architecture

### Dynamic Sharding Flow

```
┌─────────────────────────────────────────────────────────┐
│                  shard_calculator                        │
│  (Standalone Workflow)                                   │
│                                                          │
│  1. Analyze changed files                               │
│  2. Detect modified packages + dependents               │
│  3. Calculate SHARD_COUNT                               │
│     = ceil(package_count / PACKAGES_PER_SHARD)          │
│  4. Create SHARD_ARRAY with package assignments         │
│  5. Trigger test_pipeline via Bitrise API              │
│                                                          │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ (API Call with SHARD_COUNT,
                  │  SHARD_ARRAY, MODIFIED_PACKAGES)
                  ▼
┌─────────────────────────────────────────────────────────┐
│                  test_pipeline                           │
│  (Graph Pipeline)                                        │
│                                                          │
│  ┌──────────────────────────────────────────────┐      │
│  │          test_shard (parallel: $SHARD_COUNT) │      │
│  │                                               │      │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐      │      │
│  │  │ Shard 0 │  │ Shard 1 │  │ Shard N │      │      │
│  │  │ INDEX=0 │  │ INDEX=1 │  │ INDEX=N │      │      │
│  │  └─────────┘  └─────────┘  └─────────┘      │      │
│  │                                               │      │
│  │  Each extracts packages from SHARD_ARRAY     │      │
│  │  using $BITRISE_IO_PARALLEL_INDEX             │      │
│  └──────────────────────────────────────────────┘      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## 📊 Shard Calculation Examples

With `PACKAGES_PER_SHARD: "2"`:

| Packages Modified | Shard Count | Distribution |
|-------------------|-------------|--------------|
| 1 package         | 1 shard     | All in shard 0 |
| 3 packages        | 2 shards    | 2 + 1 |
| 6 packages        | 3 shards    | 2 + 2 + 2 |
| 10 packages       | 5 shards    | 2 + 2 + 2 + 2 + 2 |

Formula: `SHARD_COUNT = ceil(package_count / PACKAGES_PER_SHARD)`

## 🛠️ Key Files

```
.
├── bitrise.yml                      # Bitrise configuration
│   ├── shard_calculator workflow    # Analyzes & triggers
│   ├── test_shard workflow          # Runs tests
│   └── test_pipeline                # Graph pipeline
│
├── .ci/scripts/
│   └── shard_calculator.dart        # Shard calculation logic
│
├── packages/                        # Flutter packages
│   ├── feature_a/
│   ├── feature_b/
│   └── ...
│
└── melos.yaml                       # Monorepo management
```

## 📝 Dart Shard Calculator

The `shard_calculator.dart` script provides three commands:

### 1. Analyze Changed Files
```bash
dart .ci/scripts/shard_calculator.dart analyze '["packages/feature_a/lib/main.dart"]'
```
Output:
```json
{
  "modified": ["feature_a"],
  "dependents": ["feature_b", "feature_c"],
  "all": ["feature_a", "feature_b", "feature_c"]
}
```

### 2. Create Shards
```bash
dart .ci/scripts/shard_calculator.dart shard "feature_a,feature_b,feature_c" 2
```
Output:
```
SHARD_0_PACKAGES=feature_a,feature_b
SHARD_1_PACKAGES=feature_c
SHARD_COUNT=2
```

### 3. Auto Mode (Legacy)
```bash
dart .ci/scripts/shard_calculator.dart auto 4
```

## 🔧 Configuration

### Adjust Packages Per Shard

In `bitrise.yml`:
```yaml
app:
  envs:
  - PACKAGES_PER_SHARD: "3"  # Increase for fewer, larger shards
```

### Customize Test Execution

Edit the `test_shard` workflow in `bitrise.yml` to:
- Add coverage reporting
- Modify test commands
- Add additional validation steps

## 📊 Test Results

Bitrise automatically aggregates JUnit XML reports from all shards in the **Pipeline Test Reports** tab.

Each shard generates:
```
$BITRISE_TEST_RESULT_DIR/
├── shard0_feature_a/
│   ├── junit.xml
│   └── test-info.json
├── shard0_feature_b/
│   ├── junit.xml
│   └── test-info.json
└── ...
```

## 🔍 Troubleshooting

### Issue: BITRISE_API_TOKEN not found
**Solution**: Add as Secret in Bitrise Workflow Editor → Secrets tab

### Issue: SHARD_COUNT is always 1
**Solution**:
- Check that `PACKAGES_PER_SHARD` is set correctly
- Verify packages are detected in analysis step
- Check git diff shows changed files

### Issue: Pipeline not triggered
**Solution**:
- Verify API token has correct permissions
- Check API response in shard_calculator logs
- Ensure `test_pipeline` exists in bitrise.yml

## 🆚 Comparison: Fixed vs Dynamic Sharding

| Feature | Fixed (main) | Dynamic (dynamic-shards) |
|---------|-------------|--------------------------|
| Shard Count | Always 3 | Calculated per build |
| Resource Usage | May waste resources | Optimal |
| Configuration | Simple | Requires API token |
| Best For | Stable workloads | Variable changes |

## 🔗 Related Documentation

- [Stage-Based Sharding](README-SHARDING.md) - Legacy approach
- [Graph Pipeline Guide](GRAPH-PIPELINE-GUIDE.md) - Deep dive into graph pipelines
- [Comparison Guide](COMPARISON.md) - Stage vs Graph pipelines

## 🤝 Contributing

This is a demo repository showcasing dynamic sharding patterns for Bitrise CI.

## 📄 License

MIT License - feel free to use and adapt for your projects.

---

**Built with** [Claude Code](https://claude.com/claude-code)
