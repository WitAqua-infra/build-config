#!/bin/bash

set -eu

echo "--- Uploading logs on error"
echo "failures/${DEVICE}/${BUILDKITE_BUILD_ID}/"

if [ -f "/ssd02/WitAqua/setup/discord.sh" ]; then
  source /ssd02/WitAqua/setup/discord.sh
fi

if [ -f "/tmp/android-build-${BUILDKITE_BUILD_ID}.log" ]; then
  curl \
    -F content="## Build failed
- UUID: \`${BUILDKITE_BUILD_ID}\`
Please check **attached build log** and [**Buildkite**]($BUILDKITE_BUILD_URL)." \
    -F "file1=@/tmp/android-build-${BUILDKITE_BUILD_ID}.log" \
    -F "file2=@/tmp/android-sync-${BUILDKITE_BUILD_ID}.log" \
    "$WEBHOOK_URL"
elif [ -f "/tmp/android-sync-${BUILDKITE_BUILD_ID}.log" ]; then
  curl \
    -F content="## Sync failed
- UUID: \`${BUILDKITE_BUILD_ID}\`
Please check **attached sync log** and [**Buildkite**]($BUILDKITE_BUILD_URL)." \
    -F "file=@/tmp/android-sync-${BUILDKITE_BUILD_ID}.log" \
    "$WEBHOOK_URL"
else
  curl \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"## Build failed\n- UUID: \`${BUILDKITE_BUILD_ID}\`\nLog not found.\nPlease check [**Buildkite**]($BUILDKITE_BUILD_URL)\"}" \
    "$WEBHOOK_URL"
fi
# ssh jenkins@blob.lineageos.org mkdir -p ~/incoming/failures/${DEVICE}/${BUILDKITE_BUILD_ID}/
# scp /tmp/android-sync.log jenkins@blob.lineageos.org:incoming/failures/${DEVICE}/${BUILDKITE_BUILD_ID}/
# scp /tmp/android-build.log jenkins@blob.lineageos.org:incoming/failures/${DEVICE}/${BUILDKITE_BUILD_ID}/
