#!/bin/bash

# Mimeograph
#
# Noun: A duplicating machine which produces copies from a stencil.
#
# Script to copy container images from a source to a
# target container registry, using oc-mirror.
#
# Builds on oc-mirror by uploading the resulting tar files
# to an S3 style object bucket.
#

set -x

# Main Config file is in YAML
MIMEOGRAPH_CONFIG="/mimeograph/mimeograph-config.yaml"
if [ ! -f ${MIMEOGRAPH_CONFIG} ]; then
  MIMEOGRAPH_CONFIG="./mimeograph-config.yaml"
fi

echo "Linking auth secret to registry..."
# $HOME is set to /root in our container, so create /root/.docker
#mkdir -p /root/.docker

REGISTRY_AUTH="/root/.docker/config.json"
#REGISTRY_AUTH="~/.docker/config.json"

if [ ! -f ${REGISTRY_AUTH} ]; then
  echo "Required Registry Authentication file not found at ${REGISTRY_AUTH}"
  echo "Please check external file is mounted correctly"
  exit 1
fi

# Extract Operational Mode (bundle or populate)
MODE=$(yq .operation ${MIMEOGRAPH_CONFIG})
echo "Operational Mode: ${MODE}"
# Extract the bucket name
BUCKET_NAME=$(yq .s3.bucket.name ${MIMEOGRAPH_CONFIG})
echo "BUCKET_NAME: ${BUCKET_NAME}"
# Extract the bucket subDir
BUCKET_SUBDIR=$(yq .s3.bucket.subDir ${MIMEOGRAPH_CONFIG})
echo "BUCKET_SUBDIR: ${BUCKET_SUBDIR}"
# Extract Bucket Endpoint
BUCKET_ENDPOINT=$(yq .s3.bucket.endpoint ${MIMEOGRAPH_CONFIG})
echo "BUCKET_ENDPOINT: ${BUCKET_ENDPOINT}"
# Extract the bundle dir
BUNDLE_DIR=$(yq .artefacts.bundleDir ${MIMEOGRAPH_CONFIG})
echo "BUNDLE_DIR: ${BUNDLE_DIR}"
# Extract metadata dir
METADATA_DIR=$(yq .artefacts.metadataDir ${MIMEOGRAPH_CONFIG})
echo "METADATA_DIR: ${METADATA_DIR}"
# extract imageset config
MIRROR_CONFIG=$(yq .mirror.imagesetConfig ${MIMEOGRAPH_CONFIG})
echo "MIRROR_CONFIG: ${MIRROR_CONFIG}"
# extract Target Registry
TARGET_REGISTRY_URI=$(yq .mirror.targetRegistryURI ${MIMEOGRAPH_CONFIG})
echo "TARGET_REGISTRY_URI: ${TARGET_REGISTRY_IRI}"

# Create AWS_ARGS
AWS_ARGS="--endpoint ${BUCKET_ENDPOINT}"

# Verify S3 Object Credentials
verifyS3Creds() {
    echo "Verifying S3 ENV VARS are set..."
    if [[ -z ${AWS_ACCESS_KEY_ID} ]]; then
        echo "Required Environment Variable AWS_ACCESS_KEY is not set"
        echo "Please check ENV VAR is set correctly"
        echo "Mimeograph Cannot Continue, exiting..."
        exit 1
    fi
    if [[ -z ${AWS_SECRET_ACCESS_KEY} ]]; then
        echo "Required Environment Variable AWS_SECRET_ACCESS_KEY is not set"
        echo "Please check ENV VAR is set correctly"
        echo "Mimeograph Cannot Continue, exiting..."
        exit 1
    fi
    S3_CONFIG=true
}

bundle() {
    echo "Entering Bundle function"
    echo "Checking for Configuration files..."
    if [ ! -f ${MIRROR_CONFIG} ]; then
      echo "ERROR: mirror config ${MIRROR_CONFIG} not found"
      echo "Please check mirror config is mounted to the container correctly"
      exit 1
    else
      echo "Success"
    fi

    echo "Attempting mirror and bundle..."
    # oc-mirror --config imageset-config-minimal.yaml file:///home/ec2-user/mimeograph/archives
    oc-mirror --config ${MIRROR_CONFIG} file://${BUNDLE_DIR}
}

populate() {
    echo "Entering Populate function"
    echo "Checking for Relevant Configuration..."
    if [ ! -f ${MIRROR_CONFIG} ]; then
      echo "ERROR: mirror config ${MIRROR_CONFIG} not found"
      echo "Please check mirror config is mounted to the container correctly"
      exit 1
    else
      echo "Success"
    fi

    echo "Attempting Unbundle and Populate..."
    # oc-mirror --from /mimeograph/bundle docker://disconnected-registry.example.com
    oc-mirror --from ${BUNDLE_DIR} --dir ${BUNDLE_DIR}/oc-mirror-workspace docker://${TARGET_REGISTRY_URI}

}

s3sync() {
    source=$1
    dest=$2
    subdir=$3
    echo "Checking S3..."
    if [[ ${S3_CONFIG} == false ]]; then
        echo "Error: S3 Config (S3_CONFIG) is not set"
        echo "Mimeograph Cannot Sync to S3, exiting..."
        exit 1
    fi
    echo "Syncing Artefacts to S3..."
    aws ${AWS_ARGS} s3 sync --exclude "*" --include "*.tar" $source $dest

}

# Script Starts Here in Anger

echo "Welcome to Mimeograph"

echo "Configuration File Path: ${MIRROR_CONFIG}"
echo "Verifying Configuration..."
# Verify S3 creds are available to sync to S3
verifyS3Creds

echo "Mimeograph Operational Mode: ${MODE}"

if [[ "${MODE}" == "bundle" ]]; then
  echo "Copying and Bundling defined artefacts..."
  # Run bundle...
  bundle "${MIRROR_CONFIG}"

  # Sync bundle artefacts to S3 bucket
  s3sync ${BUNDLE_DIR} "s3://${BUCKET_NAME}/${BUCKET_SUBDIR}"

elif [[ "${MODE}" == "populate" ]]; then
  echo "Extracting bundle and populating target Registry with bundled artefacts..."
  # Sync bundle artefacts from S3 bucket
  s3sync "s3://${BUCKET_NAME}/${BUCKET_SUBDIR}" ${BUNDLE_DIR}

  # Run populate...
  populate

fi

#exec "$@"
# EOF