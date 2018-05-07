#!/bin/sh
set -e -o pipefail

args=$(getopt EAH $*)
set -- $args
for i; do
  case "$i"
  in
    -E)
        ECR=true;
        shift;;
    -A)
        AUTH=true;
        shift;;
    -H)
        HUB=true;
        shift;;
    --)
        shift;
        break;;
  esac
done

COMMIT_HASH=$(git rev-parse --short HEAD)

# Tag is composed with schema registry version and last commit.
BUILD_TAG=${BUILD_TAG:-"3.3.1-$COMMIT_HASH"}

BUILD_DIR=$(dirname $0)

# Build the latest & specific tag version image.
docker build -t pixability/confluent-schema-registry:latest \
             -t pixability/confluent-schema-registry:$BUILD_TAG \
             $BUILD_DIR

# Tag and push to ECR
# Tag and push to ECR
if [[ "$ECR" == "true" ]]; then
  docker tag pixability/confluent-schema-registry:$BUILD_TAG 974422546278.dkr.ecr.us-east-1.amazonaws.com/pixability/confluent-schema-registry:$BUILD_TAG

  if [[ "$AUTH" == "true" ]]; then
    eval $(aws ecr get-login --no-include-email)
  fi

  docker push 974422546278.dkr.ecr.us-east-1.amazonaws.com/pixability/confluent-schema-registry:$BUILD_TAG
fi

# Push to docker hub
if [[ "$HUB" == "true" ]]; then
  docker push pixability/confluent-schema-registry:$BUILD_TAG
fi

