# Stage-Based vs Graph-Based Pipeline Comparison

This document compares the two implementations of test sharding in Bitrise.

## 📁 Files

| File | Type | Description |
|------|------|-------------|
| `bitrise-sharding.yml` | Stage-based | Original implementation using stages |
| `bitrise-graph-pipeline.yml` | Graph-based | New implementation using graph pipelines |

## 🔄 Key Differences

### Pipeline Definition

**Stage-Based:**
```yaml
pipelines:
  flutter_test_pipeline:
    stages:
    - stage_analyze: {}
    - stage_test_shardless: {}
    - stage_test_sharded: {}

stages:
  stage_test_sharded:
    run_if: '{{ enveq "RUN_MODE" "sharded" }}'
    workflows:
    - test_shard_0: {}
    - test_shard_1: {}
    - test_shard_2: {}
    parallelism: 3
```

**Graph-Based:**
```yaml
pipelines:
  flutter_test_pipeline:
    workflows:
      shard_coordinator:
        depends_on: []

      test_shard_0:
        depends_on: [shard_coordinator]
        run_if: |-
          {{
            and
            (enveq "RUN_MODE" "sharded")
            (getenv "SHARD_0_PACKAGES" | ne "")
          }}

      test_shard_1:
        depends_on: [shard_coordinator]
        run_if: |-
          {{
            and
            (enveq "RUN_MODE" "sharded")
            (getenv "SHARD_1_PACKAGES" | ne "")
          }}
```

### Workflow Execution

**Stage-Based:**
- All workflows in a stage start
- Workflows check for packages in their steps
- Empty workflows exit early (but still consume resources)

**Graph-Based:**
- Only workflows with satisfied `run_if` conditions start
- Empty workflows never start at all
- More efficient resource usage

### Shard Worker Pattern

**Stage-Based (Duplicated Code):**
```yaml
workflows:
  test_shard_0:
    steps:
    - script@1:
        inputs:
        - content: |-
            SHARD_INDEX=0
            PACKAGES="$SHARD_0_PACKAGES"
            # ... test logic ...

  test_shard_1:
    steps:
    - script@1:
        inputs:
        - content: |-
            SHARD_INDEX=1
            PACKAGES="$SHARD_1_PACKAGES"
            # ... same test logic ...
```

**Graph-Based (Reusable Worker):**
```yaml
workflows:
  test_shard_worker:
    steps:
    - script@1:
        inputs:
        - content: |-
            PACKAGES_VAR="SHARD_${SHARD_INDEX}_PACKAGES"
            PACKAGES="${!PACKAGES_VAR}"
            # ... test logic (once) ...

  test_shard_0:
    envs:
    - SHARD_INDEX: "0"
    after_run:
    - test_shard_worker

  test_shard_1:
    envs:
    - SHARD_INDEX: "1"
    after_run:
    - test_shard_worker
```

### Environment Variable Sharing

**Stage-Based:**
- Environment variables flow automatically within stages
- Limited to same stage execution

**Graph-Based:**
- Uses Bitrise cache to transfer variables
- Works across independent workflow executions
- More explicit but more flexible

## 📊 Performance Comparison

### Scenario 1: Small Change (3 packages, shardless)

**Stage-Based:**
```
Stage 1: shard_coordinator          (30s)
Stage 2: test_shardless             (90s)
Stage 3: (run_if fails but evaluated)
  - Workflows start but don't run   (0s in practice)

Total: 120s
```

**Graph-Based:**
```
shard_coordinator                   (30s)
test_shardless                      (90s)
[Shard workflows skipped - run_if false]

Total: 120s
```

**Winner: Tie** (but graph is cleaner)

### Scenario 2: Medium Change (6 packages, 3 shards)

**Stage-Based:**
```
Stage 1: shard_coordinator          (30s)
Stage 2: [skipped]
Stage 3: (parallelism: 3)
  - test_shard_0                    (40s) ┐
  - test_shard_1                    (45s) ├ Parallel
  - test_shard_2                    (35s) ┘

Total: 30s + max(40s, 45s, 35s) = 75s
```

**Graph-Based:**
```
shard_coordinator                   (30s)
[test_shardless skipped - run_if false]
Parallel (automatic):
  - test_shard_0                    (40s) ┐
  - test_shard_1                    (45s) ├ Parallel
  - test_shard_2                    (35s) ┘
[test_shard_3, 4 skipped - run_if false]

Total: 30s + max(40s, 45s, 35s) = 75s
```

**Winner: Tie** (same performance)

### Scenario 3: Large Change (15 packages, but only need 7 shards with MAX_SHARDS=10)

**Stage-Based:**
```
Stage 3: All 10 shard workflows start
  - 7 shards run tests              (various times)
  - 3 shards check packages → exit  (5s each wasted)

Overhead: 15s wasted on empty checks
```

**Graph-Based:**
```
Parallel:
  - 7 shards run tests              (various times)
  - 3 shards never start            (0s - skipped by run_if)

Overhead: 0s
```

**Winner: Graph-Based** (saves ~15s)

## 🎯 Feature Comparison

| Feature | Stage-Based | Graph-Based | Winner |
|---------|-------------|-------------|--------|
| **Setup Complexity** | Simpler | Moderate | Stage-Based |
| **Code Duplication** | High (duplicated workflows) | Low (shared worker) | Graph-Based |
| **Resource Efficiency** | Good | Excellent | Graph-Based |
| **Explicit Dependencies** | Implicit | Explicit (depends_on) | Graph-Based |
| **Bitrise UI Visualization** | Good | Excellent (graph view) | Graph-Based |
| **Debugging** | Moderate | Easier (clear dependencies) | Graph-Based |
| **Flexibility** | Moderate | High | Graph-Based |
| **Empty Workflow Handling** | Start → Exit | Never start | Graph-Based |
| **Parallelism Control** | Explicit (parallelism: N) | Automatic | Graph-Based |
| **Env Var Sharing** | Automatic (within stage) | Manual (cache) | Stage-Based |

**Overall Winner: Graph-Based** (8 vs 2)

## 🔀 Migration Path

### Low Risk Projects
Start with stage-based, migrate when comfortable:
1. Use `bitrise-sharding.yml` (stage-based)
2. Get familiar with sharding concept
3. When ready, switch to `bitrise-graph-pipeline.yml`

### High Performance Projects
Go directly to graph-based:
1. Use `bitrise-graph-pipeline.yml` from the start
2. Better long-term scalability
3. More efficient resource usage

## 💰 Cost Comparison

Assuming:
- Bitrise charges by build minutes
- Empty workflow start/exit: ~5s each
- Typical scenario: 5 shards defined, 2-3 actually needed

### Monthly Cost Difference

**Stage-Based:**
```
100 builds/month
Each build: 2 unused shards × 5s = 10s wasted
Total waste: 100 × 10s = 1000s = 16.7 minutes/month
```

**Graph-Based:**
```
100 builds/month
Unused shards never start = 0s wasted
Savings: 16.7 minutes/month
```

**At $0.02/minute**: $0.33/month saved

Not huge, but scales with:
- More builds
- More defined shards
- Longer empty workflow overhead

## 🎓 Recommendations

### Use Stage-Based If:
- ✅ You're new to Bitrise pipelines
- ✅ You want simpler initial setup
- ✅ You have ≤3 total shards defined
- ✅ Your team prefers implicit dependencies

### Use Graph-Based If:
- ✅ You want best performance
- ✅ You define many shards (5+)
- ✅ You value explicit dependency declaration
- ✅ You want better Bitrise UI visualization
- ✅ You care about resource efficiency
- ✅ You plan to scale the monorepo

## 🚀 Quick Decision Matrix

| Project Characteristic | Recommendation |
|------------------------|----------------|
| Small monorepo (<10 packages) | Stage-Based |
| Large monorepo (10+ packages) | Graph-Based |
| New to Bitrise | Stage-Based |
| Experienced with Bitrise | Graph-Based |
| Cost-sensitive | Graph-Based |
| Quick prototype | Stage-Based |
| Production-ready | Graph-Based |
| Team prefers simplicity | Stage-Based |
| Team values performance | Graph-Based |

## 📝 Example Use Cases

### Case 1: Startup with 6 Flutter Packages
**Recommendation: Stage-Based**
- Quick to set up
- 3 shards maximum
- Minimal overhead difference
- Team learning Bitrise

### Case 2: Enterprise with 50+ Flutter Packages
**Recommendation: Graph-Based**
- 10+ shards needed
- Significant resource savings
- Better at scale
- Clear dependency visualization crucial

### Case 3: Mid-size SaaS (20 packages)
**Recommendation: Graph-Based**
- Sweet spot for benefits
- 5-8 shards typical
- Enough overhead to matter
- Worth the extra setup

## 🔍 Side-by-Side Example

### Execution Log Comparison

**Stage-Based Build Log:**
```
✅ Stage 1: stage_analyze
  └─ ✅ shard_coordinator (30s)
      └─ Calculated: RUN_MODE=sharded, SHARD_COUNT=2

⏭️ Stage 2: stage_test_shardless (skipped - run_if failed)

✅ Stage 3: stage_test_sharded (parallelism: 3)
  ├─ ✅ test_shard_0 (40s)
  ├─ ✅ test_shard_1 (35s)
  └─ ⚠️ test_shard_2 (5s - no packages, exited)

Total: 75s
```

**Graph-Based Build Log:**
```
✅ shard_coordinator (30s)
  └─ Calculated: RUN_MODE=sharded, SHARD_COUNT=2

⏭️ test_shardless (skipped - run_if: RUN_MODE != shardless)

✅ test_shard_0 (40s - parallel)
✅ test_shard_1 (35s - parallel)
⏭️ test_shard_2 (skipped - run_if: SHARD_2_PACKAGES is empty)

Total: 70s (5s saved)
```

**Difference:** Graph-based never starts test_shard_2

---

## 📚 Further Reading

- [Stage-Based Documentation](README-SHARDING.md)
- [Graph-Based Documentation](GRAPH-PIPELINE-GUIDE.md)
- [Quick Start Guide](QUICKSTART.md)
- [Bitrise Official Docs](https://docs.bitrise.io/en/bitrise-ci/workflows-and-pipelines/build-pipelines.html)

**Conclusion:** Both approaches work well. Graph-based is recommended for most production use cases due to better efficiency and scalability.
