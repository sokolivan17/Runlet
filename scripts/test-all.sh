#!/usr/bin/env bash
# Runs the test suite of every package, in dependency order.
set -euo pipefail
cd "$(dirname "$0")/.."

for package in RunnerCore RunnerEngine RunnerPersistence RunnerFeatures RunnerUI; do
    echo "==> $package"
    swift test --package-path "Packages/$package"
done
