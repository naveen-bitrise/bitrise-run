#!/usr/bin/env groovy
@Library('libraries@master') _

final String dartAgent = 'flutter-test'
final String baseAgent = 'base'
final int shardlessThreshold = 24
final String featureDependentsFileName = 'feature_dependents.json'
Set<String> packagesToRunInShard = []
Set<String> modifiedPackagesName = []

String s3SourcePath(String flutterHash = env.FLUTTER_HASH) {
    return "s3://nu-mobile-ci-cache/jenkins/pipeline/flutter/source/${flutterHash}.tar.gz"
}

boolean shouldRunInShardlessMode(Iterable<String> features, int threshold) {
    return !features.isEmpty() && features.size() <= threshold
}

def getTestStages(Iterable<String> packages, Iterable<String> modifiedPackagesName, String dartAgent) {
    def stages = [failFast: true]
    int shardIndex = 0;
    List<String> packagesToTestList = new ArrayList<String>(packages)
    Collections.shuffle(packagesToTestList)
    final ArrayList<String> shardedTests = shardTests { testsSuite = packagesToTestList }

    stages << shardedTests.collectEntries {
        shardIndex++;
        return ["Shard ${shardIndex.toString().padLeft(2,'0')}": shardStep(it, modifiedPackagesName, dartAgent, shardIndex)]
    }

    return stages
}

List<String> getFlutterPackagePath(def packages) {
    return packages.collect { it.path }
}

List<String> getFlutterPackageName(def packages) {
    return packages.collect { it.name }
}

def shardStep(Iterable<String> packages, Iterable<String> modifiedPackagesName, String dartAgent, int shardIndex) {
    return {
        def flutterNode = k8sAgent {
            name = dartAgent
            idleMinutes = 30
        }

        podTemplate(flutterNode) {
            node(flutterNode.label) {
                container(flutterNode.defaultContainer) {
                    deleteDir()
                    cpS3 {
                        source = s3SourcePath()
                        destination = '.'
                        tar = true
                    }
                    runAnalysesShardedMode(packages, modifiedPackagesName, shardIndex)
                }
            }
        }
    }
}

def runAnalysesShardedMode(Iterable<String> packages, Iterable<String> modifiedPackagesName, int shardIndex) {
    final String packagesCommaSeparated = packages.join(',')
    echo "Running batch shard index: $shardIndex with packages: $packagesCommaSeparated"

    final String modifiedPackagesCommaSeparated = modifiedPackagesName.join(',')
    echo "Modified packages: $modifiedPackagesCommaSeparated"
    withEnv(["SHARD_INDEX=$shardIndex", "PACKAGES=$packagesCommaSeparated", "MODIFIED_PACKAGES=$modifiedPackagesCommaSeparated"]) {
        try {
            namedSh(script: 'rm -rf .junit-test-reports', description: 'cleaning previous test result.')
            monocliBatch {
                job = 'flutterMergePosChecksJob'
            }
        } finally {
            junit testResults: '.junit-test-reports/*.xml', allowEmptyResults: true
        }
    }
}

void sendGitHubStatus(String status, String message) {
    githubStatus(state: status, contextPrefix: "Flutter Merge Checks - ", context: 'Summary status', description: message)
}

pipeline {
    options {
        ansiColor('xterm')
        timestamps()
        skipDefaultCheckout()
        durabilityHint('PERFORMANCE_OPTIMIZED')
        timeout(time: 75, unit: 'MINUTES')
        buildDiscarder(logRotator(daysToKeepStr: '7'))
    }
    environment {
        REPOSITORY = 'nubank/mini-meta-repo'
        PLATFORM = 'Flutter'
    }
    parameters {
        string(name: 'GIT_COMMIT', defaultValue: '', description: 'Commit hash to build')
    }
    agent {
        kubernetes k8sAgent { name = baseAgent }
    }
    stages {
        stage('Running Merge Checks') {
            agent {
                kubernetes k8sAgent { name = dartAgent }
            }
            steps {
                deleteDir()
                script {
                    env.GIT_COMMIT = params.GIT_COMMIT
                    env.DISPLAY_NAME = params.DISPLAY_NAME
                    env.DESCRIPTION = params.DESCRIPTION
                    env.IS_STAGING_BRANCH = params.IS_STAGING_BRANCH
                    currentBuild.displayName = "#${BUILD_ID}: ${params.DISPLAY_NAME}"
                    currentBuild.description = params.DESCRIPTION

                    sendGitHubStatus('pending', 'In progress.')
                    final boolean isStagingBranch = (getEnv { var = 'IS_STAGING_BRANCH' }).toBoolean()
                    gitClone {
                        owner = 'nubank'
                        repo = 'mini-meta-repo'
                        ref = getEnv { var = 'GIT_COMMIT' }
                        changelog = true
                        autoMerge = !isStagingBranch
                        depth = isStagingBranch ? 2 : 30
                    }

                    final String flutterFiles = '.ci/flutter ./lib ./test ./packages ./assets ./requirements.json ./pubspec.yaml ./pubspec.lock ./build.yaml ./nu_options.yaml ./analysis_options.yaml ./l10n'
                    env.FLUTTER_HASH = md5deep { file = flutterFiles }

                    monocliBatch {
                        job = 'flutterMergePreChecksJob'
                    }

                    final json = readJSON(file: featureDependentsFileName)
                    final modifiedFeatures = json['modifiedFeatures']
                    final dependentsFeatures = json['dependentsFeatures'].findAll { dependent ->
                            modifiedFeatures.every { modified -> modified.name != dependent.name }
                        }
                    echo "Modified packages: $modifiedFeatures"
                    echo "Dependents packages: $dependentsFeatures"

                    final allPackages = getFlutterPackagePath(dependentsFeatures + modifiedFeatures);
                    modifiedPackagesName.addAll(getFlutterPackageName(modifiedFeatures))

                    if (shouldRunInShardlessMode(allPackages, shardlessThreshold)) {
                        runAnalysesShardedMode(allPackages, modifiedPackagesName, 0)
                    } else {
                        packagesToRunInShard.addAll(allPackages)
                    }
                    if (!hasS3Object(s3SourcePath())) {
                        cpS3 {
                            source = "$flutterFiles ./monocli"
                            destination = s3SourcePath()
                            exclude = ['packages/**/example']
                            expire = date { addDays = 3 }
                            tar = true
                        }
                    }
                }
            }
        }

        stage('Running Merge Checks in Sharded Mode') {
            agent {
                kubernetes k8sAgent {
                    name = baseAgent
                }
            }
            when {
                expression { !packagesToRunInShard.isEmpty() }
            }
            steps {
                script {
                    parallel getTestStages(packagesToRunInShard, modifiedPackagesName, dartAgent)
                }
            }
        }
    }
    post {
        success {
            script {
                sendGitHubStatus('success', 'Ready.')
            }
        }
        failure {
            script {
                sendGitHubStatus('failure', 'Not ready.')
            }
        }
        unstable {
            script {
                sendGitHubStatus('failure', 'Not ready.')
            }
            error('One or more test cases (tested classes or class methods) within a test execution did not pass.')
        }
        aborted {
            script {
                sendGitHubStatus('failure', 'Aborted.')
            }
        }
    }
}