#!/bin/bash

set -eu
echo "--- Uploading logs on error"
#echo "failures/${DEVICE}/${BUILD_UUID}/"

if [ -f "/tmp/android-build-$BUILD_UUID.log" ]; then
  curl \
    -F content="## Build failed
- UUID: $BUILD_UUID
Please check **attached build log** and [**Buildkite**]($BUILDKITE_BUILD_URL)." \
    -F "file1=@/tmp/android-build-$BUILD_UUID.log" \
    -F "file2=@/tmp/android-sync-$BUILD_UUID.log" \
    "$WEBHOOK_URL"
elif [ -f "/tmp/android-sync-$BUILD_UUID.log" ]; then
  curl \
    -F content="## Sync failed
- UUID: $BUILD_UUID
Please check **attached sync log** and [**Buildkite**]($BUILDKITE_BUILD_URL)." \
    -F "file=@/tmp/android-sync-$BUILD_UUID.log" \
    "$WEBHOOK_URL"
else
  curl \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"## Build failed\n- UUID: $BUILD_UUID\nLog not found.\nPlease check [**Buildkite**]($BUILDKITE_BUILD_URL)\"}" \
    "$WEBHOOK_URL"
fi
# ssh jenkins@blob.lineageos.org mkdir -p ~/incoming/failures/${DEVICE}/${BUILD_UUID}/
# scp /tmp/android-sync.log jenkins@blob.lineageos.org:incoming/failures/${DEVICE}/${BUILD_UUID}/
# scp /tmp/android-build.log jenkins@blob.lineageos.org:incoming/failures/${DEVICE}/${BUILD_UUID}/
