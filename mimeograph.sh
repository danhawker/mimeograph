#!/bin/bash

# Mimeograph
#
# Noun: A duplicating machine which produces copies from a stencil.
#
# Script to copy container images from a source to a 
# target container registry, using Skopeo.
# Builds on Skopeo in that it provides a list of namespaces/images
# that need to be copied. It also copies all found tags for each image. 
# 
# Probably should have done this in Python. Hey ho.

#set -x

# Main Config file is in JSON.

CONFIG="/config.json"
if [ ! -f ${CONFIG} ]; then
  CONFIG="./config.json" 
fi

# Upstream/Source Repo Vars
SRCREPO=$(jq -r .UpstreamRepository.uri ${CONFIG})
SRCPORT=$(jq -r .UpstreamRepository.port ${CONFIG})
SRCTLS=$(jq -r .UpstreamRepository.tlsverify ${CONFIG})
SRCUNAME=$(jq -r .UpstreamRepository.username ${CONFIG})
SRCTOKEN=$(jq -r .UpstreamRepository.token ${CONFIG})

# Target Repo Vars
TARGETREPO=$(jq -r .TargetRepository.uri ${CONFIG})
TARGETPORT=$(jq -r .TargetRepository.port ${CONFIG})
TARGETTYPE=$(jq -r .TargetRepository.type ${CONFIG})
TARGETTLS=$(jq -r .TargetRepository.tlsverify ${CONFIG})
TARGETUNAME=$(jq -r .TargetRepository.username ${CONFIG})
TARGETTOKEN=$(jq -r .TargetRepository.token ${CONFIG})
# OpenShift API
TARGETAPI=$(jq -r .TargetRepository.api ${CONFIG})


# Login to target Registry Cluster to check Namespaces/Projects
# Currently very Atomic/OCP targetted.
registrylogin() {
  
  LOGGEDIN=$(oc login --insecure-skip-tls-verify=true ${TARGETAPI} --token ${TARGETTOKEN})
  if [ $? -ne 0 ]
  then
    echo "Could not login to Registry - exiting"
    exit 1
  fi
}

# Get list of projects
PROJECT_LIST=$(jq -r .Projects[].name ${CONFIG})

# Verify Projects Exist
# When pushing to OCP/Atomic registry, Skopeo needs the target repo to have
# the correct namespaces/projects available.
verify_project() {

  project=$1
  PROJECT_EXIST=$(oc project ${project})
  if [ $? -eq 0 ]
  then
    echo "Project ${project} already exists"
  else
    echo "Creating Project ${project}"
    oc new-project ${project}
  fi

}

# Get list of images within a project
get_images() {
  project=$1

  # creating an argument/variable in JQ so that I can use $PROJECT sanely
  images=$(jq -r --arg p $project '.Projects[] | select(.name == $p) | .images | .[]' config.json) 
  echo $images
}


# Get list of available tags from upstream repo
get_tags() {
  image_name=$1
  project=$2
  repo=$3

  tags=$(skopeo inspect --tls-verify=${SRCTLS} docker://${repo}/${project}/${image_name} | jq .RepoTags | jq -r '.[]')
  echo $tags
}

# Copy each image/tag to target
copy_image() {
  sourceimage=$1
  targetimage=$2

  # Generate ARGS
  SRCARGS=""
  if [ -z "$SRCTLS" ]
  then
    SRCARGS="--src-tls-verify=${SRCTLS} ${SRCSARGS}"
  fi
  if [ -z "${SRCUNAME}" ]
  then
    SRCARGS="--src-creds=${SRCUNAME}:${SRCTOKEN} ${SRCARGS}"
  fi
  TARGETARGS=""
  if [ -z "$TARGETTLS" ]
  then
    TARGETARGS="--dest-tls-verify=${TARGETTLS} ${TARGETARGS}"
  fi
  if [ -z "${TARGETUNAME}" ]
  then
    TARGETARGS="--dest-creds=${TARGETUNAME}:${TARGETTOKEN} ${TARGETARGS}"
  fi

echo "SourceArgs: ${SRCARGS}"
echo "TargetArgs: ${TARGETARGS}"

  echo "Copying ${sourceimage} to ${targetimage}..."
  skopeo copy ${SRCARGS} ${TARGETARGS} ${sourceimage} ${targetimage}

}

# Script Starts Here in Anger

# If Target needs login to create namespaces/project
# eg Atomic or OCP Registry - Login to target registry (OCP based)
if [ ${TARGETTYPE} == "atomic" ]
then
  registrylogin
fi

echo "Discovering Projects..."
echo $PROJECT_LIST

echo "Getting Image Lists..."
for project in $PROJECT_LIST; do
  echo "Verifying Project Name: ${project}..."
  verify_project ${project}
  IMAGES=$(get_images ${project})
  for img in $IMAGES; do
    echo $img
    TAGS=$(get_tags $img $project ${SRCREPO}:${SRCPORT})
    for tag in ${TAGS}; do
      echo "Creating source container image path: docker://${SRCREPO}:${SRCPORT}/${project}/${img}:${tag}"
      echo "Target path: docker://${TARGETREPO}:${TARGETPORT}/${project}/${img}:${tag}"
      #copy_image docker://${SRCREPO}:${TARGETPORT}/${project}/${img}:${tag} docker://${TARGETREPO}:${TARGETPORT}/${project}/${img}:${tag}
    done
  done
  echo
done

# EOF
