#!/usr/bin/env bash
# Run Robolectric/JUnit tests for the Android plugin module.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/packages/flutter_pdfview/android"

if [[ -z "${JAVA_HOME:-}" ]]; then
  if [[ -d /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home ]]; then
    export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
  elif [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  fi
fi
if [[ -n "${JAVA_HOME:-}" ]]; then
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if ! command -v java >/dev/null || ! java -version >/dev/null 2>&1; then
  echo "No working JRE found. Install with: brew install openjdk@17" >&2
  echo "Then: export JAVA_HOME=\"/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home\"" >&2
  exit 1
fi

if [[ ! -f local.properties ]]; then
  FLUTTER_SDK="$(dirname "$(dirname "$(command -v flutter)")")"
  ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  {
    echo "sdk.dir=$ANDROID_SDK"
    echo "flutter.sdk=$FLUTTER_SDK"
  } > local.properties
  echo "Wrote packages/flutter_pdfview/android/local.properties"
fi

./gradlew testDebugUnitTest --console=plain "$@"
