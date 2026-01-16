# Flutter Test Sharding for Bitrise CI

This repository demonstrates test sharding for Flutter monorepo projects using Bitrise CI/CD with Graph Pipelines.

## 🌟 Features

- **Fixed Shard Configuration**: Run tests across a fixed number of parallel shards
- **Intelligent Package Detection**: Detects modified packages and their dependents
- **Automatic Package Distribution**: Evenly distributes packages across shards
- **Graph Pipeline Architecture**: Uses Bitrise Graph Pipelines for dependency management
- **Parallel Test Execution**: Tests run in parallel across multiple shards
- **JUnit XML Reports**: Automatic test result aggregation in Bitrise Test Reports
- **Artifact Deployment**: Deploys test results to Bitrise for analysis

## 📋 Branches

### `main` - Fixed Sharding (Current)
Fixed number of shards that always run in parallel. Simpler approach, good for consistent workloads. Packages are distributed evenly across all shards.

### `dynamic-shards` - Dynamic Sharding (Recommended)
Dynamically calculates shard count based on package changes. Uses API-based triggering for optimal resource usage.

## 🚀 Quick Start

### Prerequisites

1. Flutter monorepo with packages in `packages/` directory
2. Bitrise account with your app configured
3. Melos for monorepo management

### Setup

1. **Configure Environment Variables**:
   ```yaml
   app:
     envs:
     - FLUTTER_VERSION: "3.24.0"
     - SHARD_COUNT: "3"  # Number of parallel shards
   ```

2. **Run the Pipeline**:
   - Trigger `flutter_test_pipeline` in Bitrise
   - `shard_coordinator` will analyze changes and distribute packages
   - `test_shard` workflow runs in parallel across shards

## 🏗️ Architecture

### Fixed Sharding Flow

```
┌─────────────────────────────────────────────────────────┐
│                  flutter_test_pipeline                   │
│  (Graph Pipeline)                                        │
│                                                          │
│  Step 1: shard_coordinator                              │
│  ┌────────────────────────────────────────────┐        │
│  │  1. Analyze changed files                  │        │
│  │  2. Detect modified packages + dependents  │        │
│  │  3. Create SHARD_ARRAY with assignments    │        │
│  │  4. Share via Pipeline Variables           │        │
│  └────────────────────────────────────────────┘        │
│                     │                                    │
│                     │ (Pipeline Variables)               │
│                     ▼                                    │
│  Step 2: test_shard (parallel: $SHARD_COUNT)           │
│  ┌──────────────────────────────────────────────┐      │
│  │                                               │      │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐      │      │
│  │  │ Shard 0 │  │ Shard 1 │  │ Shard 2 │      │      │
│  │  │ INDEX=0 │  │ INDEX=1 │  │ INDEX=2 │      │      │
│  │  └─────────┘  └─────────┘  └─────────┘      │      │
│  │                                               │      │
│  │  Each extracts packages from SHARD_ARRAY     │      │
│  │  using $BITRISE_IO_PARALLEL_INDEX             │      │
│  │  Some shards may be empty if packages < 3    │      │
│  └──────────────────────────────────────────────┘      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## 📊 Package Distribution Examples

With `SHARD_COUNT: "3"`:

| Packages Modified | Distribution | Notes |
|-------------------|--------------|-------|
| 1 package         | Shard 0: 1, Shard 1: 0, Shard 2: 0 | Other shards empty |
| 3 packages        | Shard 0: 1, Shard 1: 1, Shard 2: 1 | Even distribution |
| 6 packages        | Shard 0: 2, Shard 1: 2, Shard 2: 2 | Even distribution |
| 7 packages        | Shard 0: 3, Shard 1: 2, Shard 2: 2 | Round-robin |

## 🛠️ Key Files

```
.
├── bitrise.yml                      # Bitrise configuration
│   ├── shard_coordinator workflow  # Analyzes & distributes
│   ├── test_shard workflow         # Runs tests in parallel
│   └── flutter_test_pipeline       # Graph pipeline
│
├── .ci/scripts/
│   └── shard_calculator.dart       # Shard calculation logic
│
├── packages/                       # Flutter packages
│   ├── feature_a/
│   ├── feature_b/
│   └── ...
│
└── melos.yaml                      # Monorepo management
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

### 2. Create Shards (Fixed Count)
```bash
dart .ci/scripts/shard_calculator.dart shard "feature_a,feature_b,feature_c" 2
```
Output:
```
SHARD_0_PACKAGES=feature_a,feature_b
SHARD_1_PACKAGES=feature_c
SHARD_COUNT=2
```

### 3. Auto Mode
```bash
dart .ci/scripts/shard_calculator.dart auto 4
```

## 🔧 Configuration

### Adjust Shard Count

In `bitrise.yml`:
```yaml
app:
  envs:
  - SHARD_COUNT: "5"  # Increase for more parallelism
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

Test results are also deployed to Bitrise artifacts via the `deploy-to-bitrise-io` step.

## 🔍 Troubleshooting

### Issue: Empty shards running
**Solution**: This is expected behavior with fixed sharding. If you have fewer packages than shards, some shards will be empty and complete quickly. Consider using the `dynamic-shards` branch for optimal resource usage.

### Issue: Uneven package distribution
**Solution**: The shard calculator uses round-robin distribution with shuffling. Slight imbalances are normal. Adjust `SHARD_COUNT` if needed.

### Issue: Tests not found
**Solution**:
- Verify packages exist in `packages/` directory
- Check Melos bootstrap completed successfully
- Ensure package names match directory names

## 🆚 Comparison: Fixed vs Dynamic Sharding

| Feature | Fixed (main) | Dynamic (dynamic-shards) |
|---------|-------------|--------------------------|
| Shard Count | Always fixed (e.g., 3) | Calculated per build |
| Resource Usage | May waste resources on empty shards | Optimal |
| Configuration | Simple, no API token needed | Requires API token |
| Best For | Stable workloads, consistent package count | Variable changes, cost optimization |
| Complexity | Lower | Higher (API triggering) |

## 🔗 Related Documentation

- [Dynamic Sharding Branch](../../tree/dynamic-shards) - API-based dynamic sharding
- [Stage-Based Sharding](README-SHARDING.md) - Legacy stage-based approach
- [Graph Pipeline Guide](GRAPH-PIPELINE-GUIDE.md) - Deep dive into graph pipelines
- [Comparison Guide](COMPARISON.md) - Stage vs Graph pipelines
- [Quick Start](QUICKSTART.md) - Quick setup guide

## 🤝 Contributing

This is a demo repository showcasing test sharding patterns for Bitrise CI.

## 📄 License

MIT License - feel free to use and adapt for your projects.

---

**Built with** [Claude Code](https://claude.com/claude-code)
