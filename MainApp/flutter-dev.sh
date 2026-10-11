#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export FLUTTER_ROOT="$script_dir/.tooling/flutter-sdk"
export PUB_CACHE="$script_dir/.pub-cache"
exec "$FLUTTER_ROOT/bin/flutter" "$@"
