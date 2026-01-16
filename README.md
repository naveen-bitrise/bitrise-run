# Flutter Test Sharding for Bitrise CI

This repository demonstrates dynamic test sharding for Flutter monorepo projects using Bitrise CI/CD Graph Pipelines.

## 🌟 Features

- **Dynamic Shard Calculation**: Automatically calculates optimal number of shards based on changed packages
- **Intelligent Package Detection**: Detects modified packages and their dependents
- **Threshold-Based Sharding**: Single shard mode for small changes, dynamic sharding for larger changes
- **Configurable Ratios**: Set threshold and packages-per-shard via environment variables
- **Graph Pipeline Architecture**: Uses Bitrise Graph Pipelines with share-pipeline-variable
- **Parallel Test Execution**: Tests run in parallel across multiple dynamically calculated shards
- **JUnit XML Reports**: Automatic test result aggregation in Bitrise Test Reports
- **Artifact Deployment**: Deploys test results to Bitrise for analysis

## 📋 Branches

### `main` - Fixed Sharding
Fixed number of shards (3) that always run in parallel. Simpler approach, good for consistent workloads.

### `dynamic-shards` - Dynamic Sharding with API Triggering
Dynamically calculates shard count and triggers test pipeline via Bitrise Build Trigger API.

### `dynamic-sharding-v2` - Dynamic Sharding with Graph Pipeline (Current - Recommended)
Dynamically calculates shard count using graph pipeline and share-pipeline-variable. No API token required.

## 🚀 Quick Start

### Prerequisites

1. Flutter monorepo with packages in `packages/` directory
2. Bitrise account with your app configured
3. Melos for monorepo management

### Setup

1. **Configure Environment Variables** (optional):
   ```yaml
   app:
     envs:
     - SHARD_THRESHOLD: "4"       # If packages <= 4, run in single shard
     - PACKAGES_PER_SHARD: "2"    # Number of packages per shard
   ```

2. **Run the Pipeline**:
   - Trigger `flutter_test_pipeline` in Bitrise
   - `shard_coordinator` will analyze changes and calculate shard count
   - `test_shard` runs in parallel with dynamically calculated shard count

## 🏗️ Architecture

### Dynamic Sharding Flow (v2)

```
┌─────────────────────────────────────────────────────────┐
│               flutter_test_pipeline                      │
│  (Graph Pipeline)                                        │
│                                                          │
│  Step 1: shard_coordinator                              │
│  ┌────────────────────────────────────────────┐        │
│  │  1. Analyze changed files (git diff)       │        │
│  │  2. Detect modified packages + dependents  │        │
│  │  3. Check threshold:                        │        │
│  │     - If packages <= 4: SHARD_COUNT = 1    │        │
│  │     - Else: SHARD_COUNT =                  │        │
│  │       ceil(packages / PACKAGES_PER_SHARD)  │        │
│  │  4. Create SHARD_ARRAY with assignments    │        │
│  │  5. Share via share-pipeline-variable      │        │
│  └────────────────────────────────────────────┘        │
│                     │                                    │
│                     │ (Pipeline Variables:               │
│                     │  SHARD_COUNT, SHARD_ARRAY)         │
│                     ▼                                    │
│  Step 2: test_shard (parallel: $SHARD_COUNT)           │
│  ┌──────────────────────────────────────────────┐      │
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

With `SHARD_THRESHOLD: "4"` and `PACKAGES_PER_SHARD: "2"`:

| Packages Modified | Shard Count | Distribution | Mode |
|-------------------|-------------|--------------|------|
| 1 package         | 1 shard     | All in shard 0 | Shardless (≤ threshold) |
| 3 packages        | 1 shard     | All in shard 0 | Shardless (≤ threshold) |
| 4 packages        | 1 shard     | All in shard 0 | Shardless (≤ threshold) |
| 5 packages        | 3 shards    | 2 + 2 + 1 | Dynamic sharding |
| 6 packages        | 3 shards    | 2 + 2 + 2 | Dynamic sharding |
| 10 packages       | 5 shards    | 2 + 2 + 2 + 2 + 2 | Dynamic sharding |

**Formula:**
- If `packages <= SHARD_THRESHOLD`: `SHARD_COUNT = 1`
- Else: `SHARD_COUNT = ceil(packages / PACKAGES_PER_SHARD)`

## 🛠️ Key Files

```
.
├── bitrise.yml                      # Bitrise configuration
│   ├── shard_coordinator workflow  # Analyzes & calculates
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

### 2. Create Shards (Manual)
```bash
dart .ci/scripts/shard_calculator.dart shard "feature_a,feature_b,feature_c" 2
```
Output:
```
SHARD_0_PACKAGES=feature_a,feature_b
SHARD_1_PACKAGES=feature_c
SHARD_COUNT=2
```

### 3. Auto Mode (Used in Pipeline)
```bash
dart .ci/scripts/shard_calculator.dart auto 4 2
```
Parameters:
- `4` = threshold (if packages ≤ 4, single shard)
- `2` = packages per shard

Output:
```
SHARD_0_PACKAGES=feature_a,feature_b
SHARD_1_PACKAGES=feature_c,feature_d
SHARD_COUNT=2
MODIFIED_PACKAGES=feature_a,feature_c
```

## 🔧 Configuration

### Adjust Sharding Behavior

In `bitrise.yml`:
```yaml
app:
  envs:
  - SHARD_THRESHOLD: "6"       # Increase for more single-shard runs
  - PACKAGES_PER_SHARD: "3"    # Increase for fewer, larger shards
```

**Configuration Guidelines:**
- **SHARD_THRESHOLD**: Set based on your typical PR size
  - Lower (2-3): More aggressive sharding, better for large PRs
  - Higher (5-8): More single-shard runs, better for small PRs
- **PACKAGES_PER_SHARD**: Set based on test duration per package
  - Lower (1-2): More shards, better for slow tests
  - Higher (3-5): Fewer shards, better for fast tests

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

### Issue: SHARD_COUNT is always 1
**Solution**:
- Check that changed packages exceed `SHARD_THRESHOLD`
- Verify `PACKAGES_PER_SHARD` is set correctly
- Check git diff shows changed files
- Review `shard_coordinator` logs for package detection

### Issue: Tests not found
**Solution**:
- Verify packages exist in `packages/` directory
- Check Melos bootstrap completed successfully
- Ensure package names match directory names

### Issue: Empty shards
**Solution**: This shouldn't happen with dynamic sharding. Check that:
- SHARD_ARRAY is correctly populated in shard_coordinator
- share-pipeline-variable is working correctly

## 🆚 Comparison: Branch Approaches

| Feature | main | dynamic-shards | dynamic-sharding-v2 |
|---------|------|----------------|---------------------|
| Shard Count | Fixed (3) | Dynamic | Dynamic with threshold |
| Architecture | Graph pipeline | API triggering | Graph pipeline |
| API Token | Not required | Required | Not required |
| Threshold Mode | No | No | Yes (single shard ≤ threshold) |
| Complexity | Low | Medium | Low |
| Resource Usage | May waste | Optimal | Optimal |
| Best For | Stable workloads | Variable changes | Variable changes |

## 💡 Why v2 Over API-Based Approach?

**dynamic-sharding-v2 advantages:**
- ✅ No API token management required
- ✅ Simpler configuration (native graph pipeline features)
- ✅ Better error handling (pipeline dependency management)
- ✅ Threshold mode for small changes
- ✅ Single pipeline view (not split across workflows)

**When to use API-based (dynamic-shards):**
- You need to trigger pipelines from external systems
- You want complete separation between coordinator and test execution
- You need to pass complex parameters not supported by share-pipeline-variable

## 🤝 Contributing

This is a demo repository showcasing dynamic sharding patterns for Bitrise CI.

## 📄 License

MIT License - feel free to use and adapt for your projects.

---

**Built with** [Claude Code](https://claude.com/claude-code)
