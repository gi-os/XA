#!/bin/bash
# The Xcode to build with: Xcode_$XCODE_VERSION.app when the workflow names one, otherwise the
# newest release on the runner. Links are followed before betas are ruled out: the Xcode 27
# image links Xcode_27.2.app to a beta, and App Store Connect refuses a beta's builds.
set -euo pipefail
X=""
if [ -n "${XCODE_VERSION:-}" ] && [ -d "/Applications/Xcode_${XCODE_VERSION}.app" ]; then
  X="/Applications/Xcode_${XCODE_VERSION}.app"
else
  for a in $(ls -d /Applications/Xcode_*.app 2>/dev/null | sort -V); do
    real=$(cd "$a" && pwd -P)
    case "$real" in *[Bb]eta*) continue ;; esac
    X="$a"
  done
fi
[ -n "$X" ] || { echo "No Xcode found"; exit 1; }
sudo xcode-select -s "$X/Contents/Developer"
xcodebuild -version
