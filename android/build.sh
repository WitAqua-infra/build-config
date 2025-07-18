#!/bin/bash
set -eo pipefail
echo "--- Setup"
rm /tmp/android-*.log || true
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR=/ssd02/ccache
ccache -M 200G
export WITAQUA_BUILD_TYPE=OFFICIAL
export PYTHONDONTWRITEBYTECODE=true
export BUILD_ENFORCE_SELINUX=1
export BUILD_NO=
unset BUILD_NUMBER

#TODO(zif): convert this to a runtime check, grep "sse4_2.*popcnt" /proc/cpuinfo
# export CPU_SSE42=false
# Following env is set from build
# VERSION
# DEVICE
# TYPE
# RELEASE_TYPE
# EXP_PICK_CHANGES

export BUILD_DATE=$(date +%Y%m%d)
if [ -z "$GERRIT_DL_USER" ]; then
  export GERRIT_DL_USER="download"
fi

if [ -z "$SF_USER" ]; then
  export SF_USER="s1204"
fi

if [ -z "$BUILD_USER" ]; then
  if [ "$BUILDKITE_BUILD_CREATOR" == "" ]; then
    export BUILD_USER="Automatically"
  else
    export BUILD_USER="$BUILDKITE_BUILD_CREATOR"
  fi
fi

if [ -z "$BUILD_UUID" ]; then
  #export BUILD_UUID="$(uuidgen)"
  export BUILD_UUID="$BUILDKITE_BUILD_ID"
fi

if [ -z "$REPO_VERSION" ]; then
  export REPO_VERSION=v2.49.3
fi

if [ -z "$TYPE" ]; then
  export TYPE=userdebug
fi

if [ -z "$RELEASE_TYPE" ]; then
  echo "RELEASE_TYPE environment variable required"
  exit 1
fi

OFFSET="10000000"
export BUILD_NUMBER=$(($OFFSET + $BUILDKITE_BUILD_NUMBER))

echo "--- Syncing"

mkdir -p /ssd02/WitAqua/${VERSION}/.repo/local_manifests
cd /ssd02/WitAqua/${VERSION}
rm -rf .repo/local_manifests/*
rm -rf vendor || true
if [ -f /ssd02/WitAqua/setup/setup.sh ]; then
    cd /ssd02/WitAqua/setup/
    git pull
    cd /ssd02/WitAqua/${VERSION}
    source /ssd02/WitAqua/setup/setup.sh
    source /ssd02/WitAqua/setup/discord.sh
fi

# WebHook CI Notify
curl \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"## Starting build\n- User: **$BUILD_USER**\n- Time: $(date +%Y/%m/%d\ %H:%M:%S)\n- VERSION: **$VERSION**\n- DEVICE: **$DEVICE**\n- UUID: \`$BUILD_UUID\`\n- REPO_VERSION: **$REPO_VERSION**\n- TYPE: **$TYPE**\n- RELEASE_TYPE: **$RELEASE_TYPE**\n\nCheck: [**Buildkite**]($BUILDKITE_BUILD_URL)\"}" \
  "$WEBHOOK_URL"

cd /ssd02/WitAqua/${VERSION}
# catch SIGPIPE from yes
yes | repo init -u https://github.com/WitAqua/manifest.git -b ${VERSION} -g default,-darwin,-muppets,muppets_${DEVICE} --repo-rev=${REPO_VERSION} --git-lfs || if [[ $? -eq 141 ]]; then true; else false; fi
repo version

echo "Syncing"
for i in {1..3}; do
  repo sync --detach --current-branch --no-tags --force-remove-dirty --force-sync -j12 \
    > "/tmp/android-sync-$BUILD_UUID.log" 2>&1 && break
done

repo forall -c "git lfs pull"
. build/envsetup.sh


echo "--- Cleanup"
rm -rf out

echo "--- Run breakfast"
breakfast ${DEVICE} ${TYPE}

if [[ "$TARGET_PRODUCT" != lineage_* ]]; then
    echo "breakfast failed, aborting..."
    exit 1
fi

echo "--- Building"
mka bacon | tee "/tmp/android-build-$BUILD_UUID.log"

echo "--- Uploading"
# ssh jenkins@blob.lineageos.org rm -rf /home/jenkins/incoming/${DEVICE}/${BUILD_UUID}/
# ssh jenkins@blob.lineageos.org mkdir -p /home/jenkins/incoming/${DEVICE}/${BUILD_UUID}/
# scp out/dist/*target_files*.zip jenkins@blob.lineageos.org:/home/jenkins/incoming/${DEVICE}/${BUILD_UUID}/
# scp out/target/product/${DEVICE}/otatools.zip jenkins@blob.lineageos.org:/home/jenkins/incoming/${DEVICE}/${BUILD_UUID}/
# s3cmd --no-check-md5 put out/dist/*target_files*.zip s3://lineageos-blob/${DEVICE}/${BUILD_UUID}/ || true
# s3cmd --no-check-md5 put out/target/product/${DEVICE}/otatools.zip s3://lineageos-blob/${DEVICE}/${BUILD_UUID}/ || true
# scp out/target/product/${DEVICE}/*.zip ${SF_USER}@frs.sourceforge.net:/home/frs/project/witaqua/${VERSION}/${DEVICE}/
rsync -avP --mkpath -e ssh out/target/product/${DEVICE}/WitAqua-*-OFFICIAL.zip ${GERRIT_DL_USER}@download.witaqua.org://mnt/NS100/witaqua_build/${VERSION}/${DEVICE}/${BUILD_DATE}/
ssh "${GERRIT_DL_USER}@download.witaqua.org" "python /mnt/NS100/download/updater/gen_mirror_json.py /mnt/NS100/witaqua_build > /mnt/NS100/witaqua_build/builds.json"
mkdir -p /ssd02/output/witaqua/${VERSION}/${DEVICE}/
cp out/target/product/${DEVICE}/WitAqua-*-OFFICIAL.zip /ssd02/output/witaqua/${VERSION}/${DEVICE}/
cd WitAquaOTA
git add .
if git remote get-url gerrit >/dev/null 2>&1; then
  git remote set-url gerrit ssh://roX2x9quub@gerrit.witaqua.org:29418/WitAquaOTA
  echo "リモート gerrit はすでに設定されています。"
else
  git remote add gerrit ssh://roX2x9quub@gerrit.witaqua.org:29418/WitAquaOTA
  echo "リモート gerrit を追加しました"
fi
gitdir=$(git rev-parse --git-dir); scp -O -p -P 29418 roX2x9quub@gerrit.witaqua.org:hooks/commit-msg ${gitdir}/hooks/
git commit -m "${DEVICE}: $(date +"%Y%m%d") Update"
git push gerrit HEAD:refs/for/${VERSION}
cd ..
echo "--- Cleanup"
curl \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"content\":\"# Build Successfully!\n- UUID: \`$BUILD_UUID\`\nPlease check [**Buildkite**]($BUILDKITE_BUILD_URL)\"}" \
  "$WEBHOOK_URL"
rm -rf out
