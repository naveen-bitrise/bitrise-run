#!/usr/bin/env dart
import 'dart:io';
import 'dart:convert';
import 'dart:math';

/// Calculates test shards for Flutter monorepo packages
///
/// Usage:
///   dart shard_calculator.dart analyze <changed_files_json>
///   dart shard_calculator.dart shard <packages_csv> <shard_count>
///   dart shard_calculator.dart auto <changed_files_json> <threshold>

const int DEFAULT_THRESHOLD = 4;  // Run sharded mode if more than 4 packages
const int DEFAULT_PACKAGES_PER_SHARD = 2;

class Package {
  final String name;
  final String path;
  final List<String> dependencies;

  Package(this.name, this.path, this.dependencies);

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      json['name'] as String,
      json['path'] as String,
      (json['dependencies'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'dependencies': dependencies,
  };
}

class ShardCalculator {
  /// Determines if sharding should be used based on package count
  static bool shouldRunInShardlessMode(List<String> packages, int threshold) {
    return packages.isNotEmpty && packages.length <= threshold;
  }

  /// Creates balanced shards from a list of packages
  static List<List<String>> createShards(List<String> packages, int shardCount) {
    if (packages.isEmpty) return [];
    if (shardCount <= 0) return [packages];

    // Shuffle for load balancing
    final shuffled = List<String>.from(packages)..shuffle(Random());

    // Create shards
    final shards = List.generate(shardCount, (_) => <String>[]);

    for (var i = 0; i < shuffled.length; i++) {
      shards[i % shardCount].add(shuffled[i]);
    }

    return shards.where((shard) => shard.isNotEmpty).toList();
  }

  /// Get all available packages in the packages/ directory
  static List<String> getAllPackages() {
    final packagesDir = Directory('packages');
    if (!packagesDir.existsSync()) return [];

    return packagesDir
        .listSync()
        .whereType<Directory>()
        .map((dir) => dir.path.split('/').last)
        .toList();
  }

  /// Analyzes changed files and determines affected packages
  static Map<String, dynamic> analyzePackages(List<String> changedFiles) {
    final modifiedPackages = <String>{};
    final dependentPackages = <String>{};

    // Simple detection: if packages/feature_x/* changed, feature_x is modified
    for (var file in changedFiles) {
      final match = RegExp(r'^packages/([^/]+)/').firstMatch(file);
      if (match != null) {
        modifiedPackages.add(match.group(1)!);
      }
    }

    // If no changes detected, test all packages (test-all mode)
    if (modifiedPackages.isEmpty) {
      final allPackages = getAllPackages();
      return {
        'modified': [],
        'dependents': [],
        'all': allPackages,
      };
    }

    // Load dependencies from pubspec files
    final packageDeps = _loadPackageDependencies();

    // Find packages that depend on modified packages
    for (var pkg in packageDeps.keys) {
      if (modifiedPackages.contains(pkg)) continue;

      final deps = packageDeps[pkg] ?? [];
      if (deps.any((dep) => modifiedPackages.contains(dep))) {
        dependentPackages.add(pkg);
      }
    }

    return {
      'modified': modifiedPackages.toList(),
      'dependents': dependentPackages.toList(),
      'all': [...modifiedPackages, ...dependentPackages],
    };
  }

  /// Load package dependencies from pubspec.yaml files
  static Map<String, List<String>> _loadPackageDependencies() {
    final dependencies = <String, List<String>>{};
    final packagesDir = Directory('packages');

    if (!packagesDir.existsSync()) return dependencies;

    for (var dir in packagesDir.listSync().whereType<Directory>()) {
      final packageName = dir.path.split('/').last;
      final pubspecFile = File('${dir.path}/pubspec.yaml');

      if (!pubspecFile.existsSync()) continue;

      final content = pubspecFile.readAsStringSync();
      final deps = <String>[];

      // Simple YAML parsing for dependencies
      var inDepsSection = false;
      for (var line in content.split('\n')) {
        if (line.trim() == 'dependencies:') {
          inDepsSection = true;
          continue;
        }
        if (inDepsSection && line.trim().isEmpty) {
          inDepsSection = false;
        }
        if (inDepsSection && line.contains('feature_')) {
          final match = RegExp(r'(feature_\w+):').firstMatch(line);
          if (match != null) {
            deps.add(match.group(1)!);
          }
        }
        if (line.trim().startsWith('dev_dependencies:')) {
          inDepsSection = false;
        }
      }

      dependencies[packageName] = deps;
    }

    return dependencies;
  }

  /// Calculate optimal shard count based on package count
  static int calculateOptimalShardCount(int packageCount, int packagesPerShard) {
    if (packageCount <= 0) return 0;
    return (packageCount / packagesPerShard).ceil();
  }
}

void printUsage() {
  print('''
Flutter Test Sharding Calculator

Usage:
  dart shard_calculator.dart analyze <changed_files_json>
    Analyzes changed files and outputs affected packages

  dart shard_calculator.dart shard <packages_csv> <shard_count>
    Creates shards from comma-separated package list

  dart shard_calculator.dart auto <threshold> [changed_files_json]
    Automatically determines shard configuration
    If changed_files_json is omitted, analyzes git diff

Examples:
  dart shard_calculator.dart analyze '["packages/feature_a/lib/main.dart"]'
  dart shard_calculator.dart shard "feature_a,feature_b,feature_c" 2
  dart shard_calculator.dart auto 4
''');
}

void main(List<String> args) {
  if (args.isEmpty) {
    printUsage();
    exit(1);
  }

  final command = args[0];

  try {
    switch (command) {
      case 'analyze':
        if (args.length < 2) {
          stderr.writeln('Error: analyze requires changed_files_json argument');
          exit(1);
        }
        final changedFiles = (jsonDecode(args[1]) as List).cast<String>();
        final result = ShardCalculator.analyzePackages(changedFiles);
        print(jsonEncode(result));
        break;

      case 'shard':
        if (args.length < 3) {
          stderr.writeln('Error: shard requires packages_csv and shard_count arguments');
          exit(1);
        }
        final packages = args[1].split(',').where((p) => p.isNotEmpty).toList();
        final shardCount = int.parse(args[2]);
        final shards = ShardCalculator.createShards(packages, shardCount);

        for (var i = 0; i < shards.length; i++) {
          print('SHARD_${i}_PACKAGES=${shards[i].join(',')}');
        }
        print('SHARD_COUNT=${shards.length}');
        break;

      case 'auto':
        final threshold = args.length > 1 ? int.parse(args[1]) : DEFAULT_THRESHOLD;

        // Get changed files from git or JSON
        List<String> changedFiles;
        if (args.length > 2) {
          changedFiles = (jsonDecode(args[2]) as List).cast<String>();
        } else {
          // Get changed files from git diff
          final result = Process.runSync('git', ['diff', '--name-only', 'HEAD']);
          changedFiles = (result.stdout as String)
              .split('\n')
              .where((line) => line.isNotEmpty)
              .toList();
        }

        final analysis = ShardCalculator.analyzePackages(changedFiles);
        final allPackages = (analysis['all'] as List).cast<String>();

        // Only fail if packages directory doesn't exist or is empty
        if (allPackages.isEmpty) {
          stderr.writeln('Error: No packages found in packages/ directory');
          print('SHARD_COUNT=0');
          print('MODIFIED_PACKAGES=');
          exit(1);
        }

        // Always use the same format: create shards (even if just 1)
        final List<List<String>> shards;
        if (ShardCalculator.shouldRunInShardlessMode(allPackages, threshold)) {
          // Single shard with all packages
          shards = [allPackages];
        } else {
          // Multiple shards
          final shardCount = ShardCalculator.calculateOptimalShardCount(
            allPackages.length,
            DEFAULT_PACKAGES_PER_SHARD,
          );
          shards = ShardCalculator.createShards(allPackages, shardCount);
        }

        // Output in consistent format
        for (var i = 0; i < shards.length; i++) {
          print('SHARD_${i}_PACKAGES=${shards[i].join(',')}');
        }
        print('SHARD_COUNT=${shards.length}');
        print('MODIFIED_PACKAGES=${(analysis['modified'] as List).join(',')}');
        break;

      default:
        stderr.writeln('Unknown command: $command');
        printUsage();
        exit(1);
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
