#!/usr/bin/env bash
# Runs the integration tour on a simulator or device and saves a screenshot
# of every step.
#
#   scripts/tour_screenshots.sh <device-id> <output-dir>
set -euo pipefail
device="$1"
export TOUR_OUT="$2"
mkdir -p "$TOUR_OUT"
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/tour_test.dart \
  -d "$device" --flavor development > "$TOUR_OUT/tour.log" 2>&1 \
  && echo "TOUR PASSED" || echo "TOUR FAILED (see $TOUR_OUT/tour.log)"
