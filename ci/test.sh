#!/bin/bash
set -euo pipefail
source ci/app.env
DEV=$(bash ci/sim.sh)
echo "Testing on simulator $DEV"
# Not -quiet: a failing test has to say which one it was. Only the lines that matter are kept.
set +e
xcodebuild test -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -destination "id=$DEV" \
  CODE_SIGNING_ALLOWED=NO > /tmp/xctest.log 2>&1
status=$?
set -e
grep -E "error:|: warning: .*XCT|Test Case .*(failed|passed)|Executed [0-9]+ test|\*\* TEST" /tmp/xctest.log | grep -v "^$" | tail -250 || true
exit $status
