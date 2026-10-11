#!/usr/bin/env bash
set -euo pipefail

# The managed SDK in this environment is mounted read-only. Calling `flutter`
# directly tries to update /opt/flutter/bin/cache before it reaches analysis.
# Use the bundled Dart analyzer and keep its transient server state outside the
# repository. On a normal writable Flutter installation, `flutter analyze`
# remains equivalent.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dart_bin="${FLUTTER_DART_BIN:-/opt/flutter/bin/cache/dart-sdk/bin/dart}"
state_dir="${TMPDIR:-/tmp}/bliss-dart-state"

mkdir -p "$state_dir"
cd "$project_root"
HOME="$state_dir" "$dart_bin" analyze
