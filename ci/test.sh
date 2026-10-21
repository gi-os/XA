#!/bin/bash
# Builds the tests, then runs them on a simulator. The whole xcodebuild logs are kept in /tmp;
# errors, the two phases, slow-to-compile code and the results print as they happen, so a slow
# or stuck run shows where it is.
set -euo pipefail
source ci/app.env
DEV=$(bash ci/sim.sh)
echo "Testing on simulator $DEV"
LIVE='error:|type-check|\*\* (BUILD|TEST|TEST BUILD) (SUCCEEDED|FAILED)|Test Suite .* (started|passed|failed)|Executed [0-9]+ test|Testing started'
SLOW='$(inherited) -Xfrontend -warn-long-expression-type-checking=400 -Xfrontend -warn-long-function-bodies=1500'
set +e
SECONDS=0
xcodebuild build-for-testing -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -destination "id=$DEV" \
  CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS="$SLOW" 2>&1 | tee /tmp/xcbuild.log | grep --line-buffered -E "$LIVE"
status=${PIPESTATUS[0]}
echo "Built for testing in ${SECONDS}s (status $status)"
if [ "$status" -eq 0 ]; then
  SECONDS=0
  xcrun simctl boot "$DEV" > /dev/null 2>&1
  xcrun simctl bootstatus "$DEV" -b > /dev/null 2>&1
  echo "Simulator up in ${SECONDS}s"
  xcodebuild test-without-building -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -destination "id=$DEV" \
    CODE_SIGNING_ALLOWED=NO -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
    2>&1 | tee /tmp/xctest.log | grep --line-buffered -E "$LIVE"
  status=${PIPESTATUS[0]}
  echo "Tested in ${SECONDS}s (status $status)"
fi
set -e
cat /tmp/xcbuild.log /tmp/xctest.log 2>/dev/null \
  | grep -E "CUBE got|DEVELOP |error:|: warning: .*XCT|Test Case .*(failed|passed)|Executed [0-9]+ test|\*\* TEST" \
  | grep -v "^$" | tail -250 || true
exit $status
