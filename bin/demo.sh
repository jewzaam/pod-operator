#!/bin/bash

set -e

# colors
BLACK='\033[0;30m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
BROWN='\033[0;33m'
LIGHT_GRAY='\033[0;37m'
DARK_GRAY='\033[1;30m'
LIGHT_BLUE='\033[1;34m'
LIGHT_GREEN='\033[1;32m'
LIGHT_CYAN='\033[1;36m'
LIGHT_RED='\033[1;31m'
LIGHT_PURPLE='\033[1;35m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NO_COLOR='\033[0m'

PS1_COLOR=$BLUE
HEADING_COLOR=$BLUE
COMMAND_COLOR=$GREEN

# export some things we'll need to reuse
export GO111MODULE=on
export QUAY_USERNAME=nmalik
export GITHUB_USERNAME=jewzaam
export OP_VERSION=0.0.1
export OP_NAME=pod-operator
export OP_API_GROUP=pod.jewzaam.org
export OP_API_VERSION=v1alpha1
export OP_KIND=PodRequest

export PUSH_TIMEOUT="15s"

export STEP_NUMBER=1

cat << EOF > /tmp/podrequest.yaml
apiVersion: pod.jewzaam.org/v1alpha1
kind: PodRequest
metadata:
  name: busybox
  namespace: pod-operator
spec:
  name: busybox
  image: busybox
  command: [ "/bin/sh", "-ec", "while :; do echo 'Hello DevConf.CZ 2020!'; sleep 5; done" ]
EOF

pause() {
  echo ""
  echo -e "${HEADING_COLOR}# ${STEP_NUMBER} ${1}${NO_COLOR}"
  echo ""
  STEP_NUMBER=$((STEP_NUMBER+1))
  if [ "$2" != "" ];
  then
    ps1
    echo -ne "${COMMAND_COLOR}${2}${NO_COLOR}"
  fi
  read
  if [ "$3" != "" ];
  then
    eval "${3}"
  elif [ "$2" != "" ];
  then
    eval "${2}"
  fi
}

ps1() {
  echo -ne "${PS1_COLOR}\$ ${NO_COLOR}"
}

echocmd() {
  echo $(ps1)$@
}

docmd() {
  echocmd $@
  $@
}

# ensure clean initial state
rm -rf $GOPATH/src/github.com/$GITHUB_USERNAME/pod-operator 2>&1 >/dev/null
kubectl delete project pod-operator 2>&1 >/dev/null
kubectl delete crds podrequests.pod.jewzaam.org 2>&1 >/dev/null
mkdir -p $GOPATH/src/github.com/$GITHUB_USERNAME 2>&1 >/dev/null
cd $GOPATH/src/github.com/$GITHUB_USERNAME 2>&1 >/dev/null
clear

# step 1
CMD="operator-sdk new $OP_NAME"
pause "create Operator" "$CMD"
docmd cd $OP_NAME

# step 2
pause "create Custom Resource Definition" "operator-sdk add api --kind=$OP_KIND" "operator-sdk add api --api-version=$OP_API_GROUP/$OP_API_VERSION --kind=$OP_KIND"

# step 3
pause "create Controller" "operator-sdk add controller --kind=$OP_KIND" "operator-sdk add controller --api-version=$OP_API_GROUP/$OP_API_VERSION --kind=$OP_KIND"

# step 4
pause "review Controller and edit CRD & Controller" "edit code" "code $(pwd) $(find -name '*_controller.go') $(find -name '*_types.go')"

# skipping because it takes time and isn't necessary for the demo
#CMD="operator-sdk generate openapi"
#pause "generate updated CRDs" "$CMD"

# step 5
CMD="operator-sdk build quay.io/$QUAY_USERNAME/$OP_NAME:latest"
pause "build Operator" "$CMD" "$CMD --image-builder podman"

# step 6
# we will fail early on this one and assume correct image is deployed to quay.io already.  this way push won't hold up the demo (nobody wants to watch it for even 90s)
CMD="podman push quay.io/$QUAY_USERNAME/$OP_NAME:latest"
pause "push Image" "$CMD" "timeout $PUSH_TIMEOUT $CMD || true"

echo "TIMEOUT: using quay.io/$QUAY_USERNAME/$OP_NAME:demo"

# quietly replace the placeholder
# small cheat, using a pre-pushed tag "demo" that isn't what we pushed live in this demo.. expect the podman push to fail / timeout, so want something concrete to use!
sed -i "s|REPLACE_IMAGE|quay.io/$QUAY_USERNAME/$OP_NAME:demo|g" deploy/operator.yaml 2>&1 >/dev/null

# quietly create namespace, it isn't important for the demo to show
kubectl create namespace pod-operator 2>&1 >/dev/null

# quietly delete generated CR
rm deploy/crds/*cr.yaml 2>&1 >/dev/null

# step 7
pause "deploy Operator" "kubectl create -f deploy/ -f deploy/crds/" "kubectl create -f deploy/ -f deploy/crds/ -n pod-operator"

# TESTING
sleep 10
echo ""
cat /tmp/podrequest.yaml
read
pause "create PodRequest" "kubectl create -f podrequest.yaml" "kubectl -n pod-operator create -f /tmp/podrequest.yaml"

pause "review busybox logs" "kubectl logs busybox" "kubectl -n pod-operator logs busybox"

pause "delete Pod (it's recreated)" "kubectl delete pod busybox" "kubectl -n pod-operator delete pod busybox"

pause "delete PodRequest" "kubectl delete podrequest busybox" "kubectl -n pod-operator delete podrequest busybox"

pause "done!"
kubectl delete namespace pod-operator 2>&1 >/dev/null
kubectl delete crds podrequests.pod.jewzaam.org 2>&1 >/dev/null

