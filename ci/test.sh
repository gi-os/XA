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
  # SKIP_TESTS: tests this runner can't run, space-separated (Target/Class/test).
  SKIP=()
  for t in ${SKIP_TESTS:-}; do SKIP+=("-skip-testing:$t"); echo "Skipping $t"; done
  SECONDS=0
  : > /tmp/xctest.log
  rm -f /tmp/xctest.status
  ( xcodebuild test-without-building -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -destination "id=$DEV" \
      CODE_SIGNING_ALLOWED=NO -test-timeouts-enabled YES -default-test-execution-time-allowance 120 \
      ${SKIP[@]+"${SKIP[@]}"} > /tmp/xctest.log 2>&1
    echo $? > /tmp/xctest.status ) &
  XPID=$!
  tail -n +1 -f /tmp/xctest.log | grep --line-buffered -E "$LIVE" &
  # On the Xcode 27 image xcodebuild has sat for minutes after the last test finished. Once the
  # tests are done it gets two minutes to exit; then the log says how they went.
  finished=0
  killed=0
  while kill -0 "$XPID" 2>/dev/null; do
    sleep 5
    if [ "$finished" -eq 0 ] && grep -qE "Test Suite '(All|Selected) tests' (passed|failed)" /tmp/xctest.log; then finished=$SECONDS; fi
    if [ "$finished" -gt 0 ] && [ $((SECONDS - finished)) -gt 120 ]; then
      echo "xcodebuild still running two minutes after the tests finished: stopping it"
      pkill -f "xcodebuild test-without-building" || true
      killed=1
      sleep 3
      break
    fi
  done
  wait "$XPID" 2>/dev/null
  sleep 1
  pkill -f "tail -n +1 -f /tmp/xctest.log" || true
  if [ "$killed" -eq 0 ] && [ -s /tmp/xctest.status ]; then
    status=$(cat /tmp/xctest.status)
  elif grep -qE "Test Suite '(All|Selected) tests' passed" /tmp/xctest.log && ! grep -qE ": error: |Test Suite '[^']*' failed" /tmp/xctest.log; then
    status=0
  else
    status=1
  fi
  echo "Tested in ${SECONDS}s (status $status)"
fi
set -e
cat /tmp/xcbuild.log /tmp/xctest.log 2>/dev/null \
  | grep -E "CUBE got|DEVELOP |error:|: warning: .*XCT|Test Case .*(failed|passed)|Executed [0-9]+ test|\*\* TEST" \
  | grep -v "^$" | tail -250 || true
exit $status
